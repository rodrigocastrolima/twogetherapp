/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { removeRememberMeField } from './removeRememberMeField';
// import * as jwt from 'jsonwebtoken'; // Unused import
// import axios from 'axios'; // Unused import
import { onDocumentWritten } from "firebase-functions/v2/firestore";
// import * as jsforce from 'jsforce'; // Unused import
// import * as functions from "firebase-functions"; // Unused import
import { cleanupExpiredMessages } from './messageCleanup';
import { sendMessageNotification } from './notifications';
import { getResellerOpportunities } from './getResellerOpportunities';
import { getOpportunityProposals } from './getOpportunityProposals';
import { resetAndVerifyConversations } from './migrations';
import * as sfOppManagement from './salesforceOpportunityManagement';

// Import the specific function we want to export explicitly
import { createSalesforceOpportunity as createOppFunc } from './createSalesforceOpportunity';
// Import the new commission function
import { getTotalResellerCommission } from './commissionFunctions';
// Import the NEW detail function
import { getSalesforceOpportunityDetails } from './getSalesforceOpportunityDetails';
// Import the NEW cycle function
// import { getActivationCycles } from './getActivationCycles'; // No longer needed here
// Import the NEW proposal creation function
// import { createSalesforceProposal } from './createSalesforceProposal'; // No longer needed here

// Export functions from separate files
export * from './set-role-claim';
export * from './exchangeSalesforceCode';
export * from './refreshSalesforceToken';
export * from './updateSalesforceOpportunity';
export * from './salesforceFileManagement';
export * from './downloadSalesforceFile';

// Export the removeRememberMeField function
export { removeRememberMeField };

// Export the other functions
export {
    getResellerOpportunities,
    getOpportunityProposals,
    resetAndVerifyConversations,
    sendMessageNotification,
    cleanupExpiredMessages,
    sfOppManagement,
    getTotalResellerCommission,
    getSalesforceOpportunityDetails,
    // Add other callable functions here as you create them
};

// Export the specific function
export const createSalesforceOpportunity = createOppFunc;

// Export the cycle function
// export const getActivationCycles = getActivationCycles; // REMOVE THIS
export { getActivationCycles } from './getActivationCycles'; // <-- ADD THIS

// Export the proposal creation function
// export const createSalesforceProposal = createSalesforceProposal; // REMOVE THIS
export { createSalesforceProposal } from './createSalesforceProposal'; // <-- ADD THIS

// --- NEW Export for Reseller Proposal Fetching ---
export { getResellerOpportunityProposals } from './getResellerOpportunityProposals';
// -----------------------------------------------

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

/**
 * Firebase Cloud Functions for User Management
 * 
 * These functions allow administrators to manage users without disrupting their sessions:
 * - Create new users
 * - Enable/disable users
 * - Reset user passwords
 * - Update user roles
 */

// Initialize the Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

// Create a collection to track usage and prevent exceeding free tier
const USAGE_COLLECTION = "usage_limits";
const MONTHLY_FUNCTION_INVOCATION_LIMIT = 125000; // 125K free invocations per month
const DAILY_FUNCTION_QUOTA = MONTHLY_FUNCTION_INVOCATION_LIMIT / 30; // Approximate daily quota

/**
 * Check if we're within safe usage limits to prevent unexpected charges
 * This is a simple implementation - in production you might want more sophisticated tracking
 * 
 * @param {string} functionName - The name of the function being called
 * @return {Promise<boolean>} True if it's safe to proceed, false if limits are reached
 */
async function checkUsageLimits(functionName: string): Promise<boolean> {
  try {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1; // JavaScript months are 0-indexed
    const day = now.getDate();
    
    // Create tracking IDs for this month and day
    const monthId = `${year}-${month}`;
    const dayId = `${monthId}-${day}`;
    
    // Get the usage tracking document for this function
    const functionRef = admin.firestore()
      .collection(USAGE_COLLECTION)
      .doc(functionName);
    
    // Use a transaction to safely update the counters
    return await admin.firestore().runTransaction(async (transaction) => {
      const functionDoc = await transaction.get(functionRef);
      const data = functionDoc.exists ? functionDoc.data() : {
        monthlyInvocations: {},
        dailyInvocations: {},
      };
      
      // Default to empty objects if data is undefined
      const monthlyInvocations = data?.monthlyInvocations || {};
      const dailyInvocations = data?.dailyInvocations || {};
      
      // Get current counts or initialize if not present
      const monthlyCount = (monthlyInvocations[monthId] || 0) + 1;
      const dailyCount = (dailyInvocations[dayId] || 0) + 1;
      
      // Check if we're approaching limits
      if (monthlyCount > MONTHLY_FUNCTION_INVOCATION_LIMIT * 0.95) {
        logger.warn(
          `⚠️ Monthly function invocations (${monthlyCount}) for ${functionName} near free tier limit!`
        );
        return false; // Stop execution to prevent charges
      }
      
      if (dailyCount > DAILY_FUNCTION_QUOTA * 0.95) {
        logger.warn(
          `⚠️ Daily function invocations (${dailyCount}) approaching daily quota!`
        );
        // Allow execution but log warning
      }
      
      // Update the tracking document
      const updatedData = {
        monthlyInvocations: {
          ...monthlyInvocations,
          [monthId]: monthlyCount,
        },
        dailyInvocations: {
          ...dailyInvocations,
          [dayId]: dailyCount,
        },
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      transaction.set(functionRef, updatedData, {merge: true});
      return true; // Safe to execute
    });
  } catch (error) {
    // If there's an error checking the limit, log it but allow execution
    // Better to allow some functions than break the entire app
    logger.error(`Error checking usage limits: ${error}`);
    return true;
  }
}

// Define the type for the user creation data
interface CreateUserData {
  email: string;
  password: string;
  displayName?: string;
  role: string;
}

/**
 * Creates a new user with the specified email, password, and role.
 * Only authenticated admin users can call this function.
 * Using V2 API for consistency with other functions
 */
export const createUser = onCall({
  enforceAppCheck: false, // Set to true in production
}, async (request) => {
  try {
    // Check if we've reached usage limits
    const withinLimits = await checkUsageLimits("createUser");
    if (!withinLimits) {
      throw new HttpsError(
        "resource-exhausted",
        "Function invocation limit reached to prevent unexpected charges. Please try again tomorrow or contact the administrator."
      );
    }

    // Log request detail to help diagnose issues
    logger.info(`createUser function called with data: ${JSON.stringify(request.data)}`);
    logger.info(`Auth context available: ${Boolean(request.auth)}`);
    
    if (request.auth) {
      logger.info(`Caller UID: ${request.auth.uid}`);
    }

    // Verify authentication
    if (!request.auth) {
      logger.error("No auth context provided");
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to create users"
      );
    }

    // Get the calling user to check if they're an admin
    const callerUid = request.auth.uid;
    const callerDoc = await admin.firestore()
      .collection("users")
      .doc(callerUid)
      .get();
    
    if (!callerDoc.exists) {
      logger.error(`User document not found for UID: ${callerUid}`);
      throw new HttpsError(
        "permission-denied",
        "User data not found"
      );
    }
    
    const callerData = callerDoc.data();
    logger.info(`Caller data from Firestore: ${JSON.stringify(callerData)}`);
    
    if (!callerData || callerData.role?.toLowerCase() !== "admin") {
      logger.error(`User is not an admin. Role: ${callerData?.role}`);
      throw new HttpsError(
        "permission-denied",
        "Only administrators can create users"
      );
    }

    // Extract user data from request
    const data = request.data as CreateUserData;
    const {email, password, displayName, role} = data;
    
    // Validate required fields
    if (!email || !password || !role) {
      throw new HttpsError(
        "invalid-argument",
        "Email, password, and role are required"
      );
    }

    // Validate role
    const validRoles = ["admin", "reseller"];
    if (!validRoles.includes(role.toLowerCase())) {
      throw new HttpsError(
        "invalid-argument",
        "Role must be either 'admin' or 'reseller'"
      );
    }

    // Create the user in Firebase Auth
    logger.info(`Attempting to create user with email: ${email}`);
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: displayName || undefined,
      disabled: false,
    });

    logger.info(`User created in Auth: ${userRecord.uid}`);

    // Create user document in Firestore
    logger.info(`Creating Firestore document for user: ${userRecord.uid}`);
    await admin.firestore().collection("users").doc(userRecord.uid).set({
      uid: userRecord.uid,
      email: email,
      displayName: displayName || null,
      role: role.toLowerCase(),
      isFirstLogin: true,
      isEnabled: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: callerUid,
    });

    // If this is a reseller, create a default conversation with welcome message
    if (role.toLowerCase() === 'reseller') {
      logger.info(`Creating default conversation for reseller: ${userRecord.uid}`);
      
      try {
        // Create conversation document
        const conversationRef = await admin.firestore().collection('conversations').add({
          resellerId: userRecord.uid,
          resellerName: displayName || email,
          lastMessageContent: 'Welcome! How can we assist you today?',
          lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
          lastMessageIsFromAdmin: true,
          active: false, // Start as inactive - only becomes active when real messages are exchanged
          unreadByAdmin: false,
          unreadByReseller: false,
          unreadCount: 0,
          unreadCounts: {},
          participants: ['admin', userRecord.uid],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Add default welcome message
        await conversationRef.collection('messages').add({
          content: 'Welcome! How can we assist you today?',
          isDefault: true,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isAdmin: true,
          isRead: false,
          senderId: 'admin',
          senderName: 'Twogether Support',
          type: 'text',
        });

        logger.info(`Default conversation created for reseller: ${userRecord.uid}, conversation ID: ${conversationRef.id}`);
      } catch (error) {
        // Don't fail the user creation if conversation creation fails, just log the error
        logger.error(`Error creating default conversation: ${error}`);
      }
    }

    logger.info(`User created successfully: ${userRecord.uid}`, {
      uid: userRecord.uid,
      email: email,
      createdBy: callerUid,
    });

    // Return the created user (excluding sensitive info)
    return {
      uid: userRecord.uid,
      email: email,
      displayName: displayName || null,
      role: role.toLowerCase(),
    };
  } catch (error) {
    logger.error("Error creating user:", error);
    
    // More detailed error logging
    if (error instanceof Error) {
      logger.error(`Detailed error message: ${error.message}`);
      logger.error(`Error stack: ${error.stack}`);
    }
    
    // Handle Firebase Auth specific errors
    const errorWithCode = error as {code?: string};
    if (errorWithCode.code) {
      logger.error(`Error code: ${errorWithCode.code}`);
    }
    
    if (errorWithCode.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "Email already exists");
    } else if (errorWithCode.code === "auth/invalid-email") {
      throw new HttpsError("invalid-argument", "Invalid email format");
    } else if (errorWithCode.code === "auth/weak-password") {
      throw new HttpsError("invalid-argument", "Password is too weak");
    }
    
    // If it's already a HttpsError, rethrow it
    if (error instanceof HttpsError) {
      throw error;
    }
    
    // Otherwise throw a generic error
    throw new HttpsError(
      "internal",
      "An error occurred while creating the user"
    );
  }
});

/**
 * Updates a user's enabled status
 * Only authenticated admin users can call this function.
 */
export const setUserEnabled = onCall({
  enforceAppCheck: false, // Set to true in production
}, async (request) => {
  try {
    // Check if we've reached usage limits
    const withinLimits = await checkUsageLimits("setUserEnabled");
    if (!withinLimits) {
      throw new HttpsError(
        "resource-exhausted",
        "Function invocation limit reached to prevent unexpected charges. Please try again tomorrow or contact the administrator."
      );
    }

    // Verify authentication
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to update user status"
      );
    }

    // Get the calling user to check if they're an admin
    const callerUid = request.auth.uid;
    const callerDoc = await admin.firestore()
      .collection("users")
      .doc(callerUid)
      .get();
    
    if (!callerDoc.exists) {
      throw new HttpsError("permission-denied", "User data not found");
    }
    
    const callerData = callerDoc.data();
    if (!callerData || callerData.role?.toLowerCase() !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Only administrators can update user status"
      );
    }

    // Extract user data from request
    const data = request.data as { uid: string; isEnabled: boolean };
    const { uid, isEnabled } = data;
    
    // Validate required fields
    if (!uid || isEnabled === undefined) {
      throw new HttpsError(
        "invalid-argument",
        "User ID and enabled status are required"
      );
    }

    // Check if user exists
    try {
      await admin.auth().getUser(uid);
    } catch (error) {
      throw new HttpsError("not-found", "User not found");
    }

    // Update the user in Firebase Auth
    await admin.auth().updateUser(uid, {
      disabled: !isEnabled,
    });

    // Update user document in Firestore
    await admin.firestore().collection("users").doc(uid).update({
      isEnabled: isEnabled,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: callerUid,
    });

    logger.info(`User ${isEnabled ? "enabled" : "disabled"}: ${uid}`, {
      uid: uid,
      isEnabled: isEnabled,
      updatedBy: callerUid,
    });

    return {success: true};
  } catch (error) {
    logger.error("Error updating user status:", error);
    
    // Handle Firebase Auth specific errors
    const errorWithCode = error as {code?: string};
    if (errorWithCode.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "User not found");
    }
    
    // If it's already a HttpsError, rethrow it
    if (error instanceof HttpsError) {
      throw error;
    }
    
    // Otherwise throw a generic error
    throw new HttpsError(
      "internal",
      "An error occurred while updating the user status"
    );
  }
});

/**
 * Resets a user's password
 * Only authenticated admin users can call this function.
 */
export const resetUserPassword = onCall({
  enforceAppCheck: false, // Set to true in production
}, async (request) => {
  try {
    // Check if we've reached usage limits
    const withinLimits = await checkUsageLimits("resetUserPassword");
    if (!withinLimits) {
      throw new HttpsError(
        "resource-exhausted",
        "Function invocation limit reached to prevent unexpected charges. Please try again tomorrow or contact the administrator."
      );
    }

    // Verify authentication
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to reset passwords"
      );
    }

    // Get the calling user to check if they're an admin
    const callerUid = request.auth.uid;
    const callerDoc = await admin.firestore()
      .collection("users")
      .doc(callerUid)
      .get();
    
    if (!callerDoc.exists) {
      throw new HttpsError("permission-denied", "User data not found");
    }
    
    const callerData = callerDoc.data();
    if (!callerData || callerData.role?.toLowerCase() !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Only administrators can reset passwords"
      );
    }

    // Extract data from request
    const data = request.data as { email: string };
    const { email } = data;
    
    // Validate required fields
    if (!email) {
      throw new HttpsError("invalid-argument", "Email is required");
    }

    // Generate a password reset link
    const link = await admin.auth().generatePasswordResetLink(email);

    logger.info(`Password reset link generated for: ${email}`, {
      email: email,
      requestedBy: callerUid,
    });

    return {
      success: true,
      link: link, // Note: In production, send via email instead
    };
  } catch (error) {
    logger.error("Error resetting password:", error);
    
    // Handle Firebase Auth specific errors
    const errorWithCode = error as {code?: string};
    if (errorWithCode.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "No user found with this email");
    } else if (errorWithCode.code === "auth/invalid-email") {
      throw new HttpsError("invalid-argument", "Invalid email format");
    }
    
    // If it's already a HttpsError, rethrow it
    if (error instanceof HttpsError) {
      throw error;
    }
    
    // Otherwise throw a generic error
    throw new HttpsError(
      "internal",
      "An error occurred while resetting the password"
    );
  }
});

// Simple ping function using V2 API for consistency
export const ping = onCall({
  enforceAppCheck: false,
}, async (request) => {
  logger.info("Ping function called (V2 API)");
  return {
    success: true,
    timestamp: new Date().toISOString()
  };
});

// Delete a user (both from Auth and Firestore)
export const deleteUser = onCall({
  enforceAppCheck: false,
}, async (request) => {
  // Check if the requester is authenticated
  if (!request.auth) {
    logger.error("Unauthenticated call to deleteUser");
    throw new HttpsError(
      "unauthenticated",
      "You must be logged in to delete users"
    );
  }

  // Get the data from the request
  const {uid} = request.data as {uid: string};

  if (!uid) {
    logger.error("No uid provided");
    throw new HttpsError(
      "invalid-argument",
      "The function must be called with 'uid' argument."
    );
  }

  // Get the caller's data to confirm they are an admin
  const callerRef = admin.firestore().collection("users").doc(request.auth.uid);
  const callerDoc = await callerRef.get();
  const callerData = callerDoc.data();
  
  if (!callerData || callerData.role?.toLowerCase() !== "admin") {
    logger.error(`User is not an admin. Role: ${callerData?.role}`);
    throw new HttpsError(
      "permission-denied",
      "Only administrators can delete users"
    );
  }

  // Make sure admins can't delete themselves
  if (uid === request.auth.uid) {
    logger.error("Admin attempting to delete their own account");
    throw new HttpsError(
      "failed-precondition",
      "Administrators cannot delete their own accounts"
    );
  }

  try {
    // Check if the user exists in Auth
    await admin.auth().getUser(uid);
    
    // Delete the user from Firestore first
    const userRef = admin.firestore().collection("users").doc(uid);
    const userDoc = await userRef.get();
    
    if (userDoc.exists) {
      await userRef.delete();
    } else {
      logger.warn(`User document not found in Firestore: ${uid}`);
    }

    // Then delete from Authentication
    await admin.auth().deleteUser(uid);

    logger.info(`User ${uid} successfully deleted from both Auth and Firestore`);
    return {
      success: true,
      message: "User successfully deleted",
    };
  } catch (error) {
    logger.error(`Error deleting user ${uid}:`, error);
    throw new HttpsError(
      "internal",
      "An error occurred while deleting the user"
    );
  }
});

/**
 * Resets a conversation to its default state by removing all messages except a default welcome message.
 * This makes the conversation invisible to admin users but preserves it for resellers.
 * Only authenticated admin users can call this function.
 */
export const deleteConversation = onCall({
  enforceAppCheck: false, // Set to true in production
}, async (request) => {
  try {
    // Check if we've reached usage limits
    const withinLimits = await checkUsageLimits("deleteConversation");
    if (!withinLimits) {
      throw new HttpsError(
        "resource-exhausted",
        "Function invocation limit reached to prevent unexpected charges. Please try again tomorrow or contact the administrator."
      );
    }

    // Log request detail to help diagnose issues
    logger.info(`deleteConversation function called with data: ${JSON.stringify(request.data)}`);
    
    // Ensure the caller is authenticated.
    if (!request.auth) {
      logger.error("No auth context provided");
      throw new HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }

    const uid = request.auth.uid;

    // Check if the user is an admin by retrieving their user document.
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists || (userDoc.data()?.role || '').toLowerCase() !== 'admin') {
      logger.error(`User is not an admin. User ID: ${uid}`);
      throw new HttpsError(
        "permission-denied",
        "Only admin users can reset conversations."
      );
    }

    // Validate the conversationId passed from the client.
    const conversationId = request.data.conversationId;
    if (!conversationId) {
      throw new HttpsError(
        "invalid-argument",
        "The function must be called with a conversationId."
      );
    }

    const conversationRef = admin.firestore().collection('conversations').doc(conversationId);
    const conversationDoc = await conversationRef.get();
    if (!conversationDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Conversation not found."
      );
    }

    // Get conversation data to extract reseller info
    const conversationData = conversationDoc.data();
    const resellerId = conversationData?.resellerId;
    
    if (!resellerId) {
      throw new HttpsError(
        "failed-precondition",
        "Conversation is missing reseller information."
      );
    }

    // Reference to the Storage bucket.
    const bucket = admin.storage().bucket();

    // Get all messages in the conversation subcollection.
    const messagesSnapshot = await conversationRef.collection('messages').get();
    
    // Create a batch for Firestore operations
    const batch = admin.firestore().batch();
    let messagesDeleted = 0;
    let imagesDeleted = 0;
    let defaultMessageExists = false;
    let defaultMessageId = null;
    
    // First check if there's already a default message
    for (const messageDoc of messagesSnapshot.docs) {
      const messageData = messageDoc.data();
      
      // Check if this is the default welcome message
      if (messageData.isDefault === true) {
        defaultMessageExists = true;
        defaultMessageId = messageDoc.id;
        logger.info(`Found existing default message: ${defaultMessageId}`);
        break;
      }
    }

    // Process each message
    for (const messageDoc of messagesSnapshot.docs) {
      const messageData = messageDoc.data();
      
      // Skip the default message if it exists
      if (defaultMessageExists && messageDoc.id === defaultMessageId) {
        logger.info(`Keeping default message: ${messageDoc.id}`);
        continue;
      }
      
      messagesDeleted++;

      // If the message is an image, attempt to delete the associated Storage file.
      if (messageData.type === 'image' && messageData.content) {
        let imageUrl: string = '';
        try {
          // The content may be a JSON string with url and base64 fields or just a URL.
          if (typeof messageData.content === 'string' && messageData.content.trim().startsWith('{')) {
            try {
              const jsonContent = JSON.parse(messageData.content);
              imageUrl = jsonContent.url;
            } catch (e) {
              imageUrl = messageData.content; // Use as is if parsing fails
            }
          } else {
            imageUrl = messageData.content;
          }

          // Extract the file path from the Firebase Storage URL.
          // Expected URL format: 
          // https://firebasestorage.googleapis.com/v0/b/{bucket}/o/chat_images%2F{fileName}?alt=media&token=...
          if (imageUrl && imageUrl.includes('firebasestorage.googleapis.com')) {
            const parts = imageUrl.split('/o/');
            if (parts.length > 1) {
              // The encoded file path is between '/o/' and '?'
              const filePart = parts[1].split('?')[0];
              // Decode the file path to get the actual Storage path.
              const filePath = decodeURIComponent(filePart);
              // Delete the file from Storage.
              try {
                await bucket.file(filePath).delete();
                imagesDeleted++;
                logger.info(`Deleted Storage file: ${filePath}`);
              } catch (storageError) {
                // Log but continue if image deletion fails
                logger.warn(`Error deleting image file: ${storageError}`);
              }
            }
          }
        } catch (error) {
          logger.error(`Error processing image for message ${messageDoc.id}:`, error);
          // Continue processing even if deletion of the image file fails.
        }
      }
      // Add this message to the batch for deletion
      batch.delete(messageDoc.ref);
    }

    // If we don't have a default message, create one
    const welcomeMessage = "Welcome! How can we assist you today?";
    if (!defaultMessageExists) {
      logger.info(`Creating new default welcome message for conversation: ${conversationId}`);
      
      // Get user document for the reseller to get their name
      let resellerName = conversationData?.resellerName || "User";
      
      if (!resellerName && resellerId) {
        try {
          const resellerDoc = await admin.firestore().collection('users').doc(resellerId).get();
          if (resellerDoc.exists) {
            const resellerData = resellerDoc.data();
            resellerName = resellerData?.displayName || resellerData?.email || "User";
          }
        } catch (error) {
          logger.warn(`Error fetching reseller info: ${error}`);
          // Continue with default name
        }
      }
      
      // Create the default welcome message
      const newDefaultMessageRef = conversationRef.collection('messages').doc();
      batch.set(newDefaultMessageRef, {
        content: welcomeMessage,
        isDefault: true,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isAdmin: true,
        isRead: false,
        senderId: 'admin',
        senderName: 'Twogether Support',
        type: 'text'
      });
    }

    // Update the conversation document to mark it as inactive and update last message
    batch.update(conversationRef, {
      lastMessageContent: welcomeMessage,
      lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageIsFromAdmin: true,
      active: false,
      // Clear unread flags but preserve the structure
      unreadByAdmin: false,
      unreadByReseller: false,
      unreadCount: 0,
      unreadCounts: {},
    });

    // Commit all the batch operations
    await batch.commit();

    logger.info(`Conversation ${conversationId} reset to default state. Deleted ${messagesDeleted} messages and ${imagesDeleted} images`);

    return {
      success: true,
      messagesDeleted,
      imagesDeleted,
      message: 'Conversation has been reset to default state.'
    };
  } catch (error) {
    logger.error("Error resetting conversation:", error);
    throw new HttpsError(
      "internal",
      `Error resetting conversation: ${error instanceof Error ? error.message : String(error)}`
    );
  }
});

/**
 * Firebase function that triggers when a message is created, updated, or deleted.
 * It checks if there are any non-default messages in the conversation and updates
 * the conversation's 'active' field accordingly.
 */
export const updateConversationActivity = onDocumentWritten({
  document: 'conversations/{conversationId}/messages/{messageId}',
}, async (event) => {
  const conversationId = event.params.conversationId;
  const conversationRef = admin.firestore().collection('conversations').doc(conversationId);

  try {
    logger.info(`Checking activity status for conversation: ${conversationId}`);
    
    // First get the conversation document to check current state
    const conversationDoc = await conversationRef.get();
    if (!conversationDoc.exists) {
      logger.error(`Conversation ${conversationId} not found`);
      return { success: false, error: 'Conversation not found' };
    }
    
    // Get all messages for this conversation
    const messagesSnapshot = await conversationRef.collection('messages').get();
    logger.info(`Found ${messagesSnapshot.size} messages in conversation ${conversationId}`);
    
    let isActive = false;
    // Define type for lastRealMessage
    interface MessageData {
      content: string;
      timestamp: admin.firestore.Timestamp;
      isAdmin: boolean;
      isDefault?: boolean;
      [key: string]: any; // Allow other fields
    }
    let lastRealMessage: MessageData | null = null;
    
    // Check each message, looking for non-default ones
    messagesSnapshot.forEach(doc => {
      const data = doc.data() as MessageData;
      // Log the message info for debugging
      logger.debug(`Message ${doc.id}: isDefault=${data.isDefault}, content="${data.content?.substring(0, 20) || ''}..."`);
      
      // If there is any message that is not default, mark the conversation as active
      if (data && data.isDefault !== true) {
        isActive = true;
        
        // Keep track of the last real message for updating lastMessageContent
        if (!lastRealMessage || 
            (data.timestamp && 
             lastRealMessage.timestamp && 
             data.timestamp.toDate() > lastRealMessage.timestamp.toDate())) {
          lastRealMessage = data;
        }
      }
    });

    // Create update data object
    const updateData: Record<string, any> = { active: isActive };
    
    // Only update lastMessageContent if we have a real message and it's different
    if (isActive && lastRealMessage) {
      // Use non-null assertion since we've already checked lastRealMessage is not null
      const contentPreview = (lastRealMessage as MessageData).content?.substring(0, 20) || '';
      logger.info(`Updating conversation with last real message: "${contentPreview}..."`);
      
      // Include last message data only if it's a real message
      updateData.lastMessageContent = (lastRealMessage as MessageData).content;
      updateData.lastMessageTime = (lastRealMessage as MessageData).timestamp;
      updateData.lastMessageIsFromAdmin = (lastRealMessage as MessageData).isAdmin;
    } else if (!isActive) {
      // If there are no real messages, clear the last message fields
      logger.info(`No real messages found, clearing lastMessageContent for conversation ${conversationId}`);
      updateData.lastMessageContent = null;
      updateData.lastMessageTime = null;
      updateData.lastMessageIsFromAdmin = null;
    }

    // Update the conversation document accordingly
    await conversationRef.update(updateData);
    logger.info(`Conversation ${conversationId} updated to active: ${isActive}`);
    
    return { success: true };
  } catch (error) {
    logger.error(`Error updating conversation activity for ${conversationId}:`, error);
    return { success: false, error: error };
  }
});

/**
 * Callable function that allows an admin to "reset" a conversation by clearing
 * all messages while keeping the conversation document intact.
 * It deletes all messages in the subcollection and updates the conversation
 * document (clearing lastMessageContent/lastMessageTime and marking it inactive).
 */
export const resetConversation = onCall({
  enforceAppCheck: false, // Set to true in production
}, async (request) => {
  // Ensure the caller is authenticated
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated', 
      'Authentication required.'
    );
  }
  
  const uid = request.auth.uid;
  
  try {
    // Verify admin status
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists || (userDoc.data()?.role || '').toLowerCase() !== 'admin') {
      throw new HttpsError(
        'permission-denied', 
        'Only admin users can reset conversations.'
      );
    }
    
    const conversationId = request.data.conversationId;
    if (!conversationId) {
      throw new HttpsError(
        'invalid-argument', 
        'A conversationId must be provided.'
      );
    }
    
    const conversationRef = admin.firestore().collection('conversations').doc(conversationId);
    const conversationSnap = await conversationRef.get();
    
    if (!conversationSnap.exists) {
      throw new HttpsError('not-found', 'Conversation not found.');
    }
    
    // Get the messages to delete
    const messagesSnapshot = await conversationRef.collection('messages').get();
    
    if (messagesSnapshot.empty) {
      logger.info(`No messages to delete in conversation ${conversationId}`);
    } else {
      logger.info(`Deleting ${messagesSnapshot.size} messages from conversation ${conversationId}`);
      
      // Delete all messages using a batch
      const batch = admin.firestore().batch();
      messagesSnapshot.forEach(doc => {
        batch.delete(doc.ref);
      });
      
      // Update the conversation document
      batch.update(conversationRef, {
        lastMessageContent: null,
        lastMessageTime: null,
        active: false,
        unreadCounts: {},
        unreadByAdmin: false,
        unreadByReseller: false,
        unreadCount: 0
      });
      
      await batch.commit();
      
      logger.info(`Successfully reset conversation ${conversationId}`);
    }
    
    return {
      success: true,
      message: 'Conversation reset: messages cleared and conversation marked inactive.'
    };
  } catch (error) {
    logger.error('Error resetting conversation:', error);
    throw new HttpsError(
      'internal',
      `Error resetting conversation: ${error instanceof Error ? error.message : String(error)}`
    );
  }
});

/**
 * Callable function that returns a list of conversation documents that are inactive
 * (i.e., they contain no real messages, only default UI messages).
 * This allows admins to easily see which conversations have only the default UI state.
 */
export const getInactiveConversations = onCall({
  enforceAppCheck: false, // Set to true in production
}, async (request) => {
  // Verify that the caller is authenticated
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  
  const uid = request.auth.uid;
  
  try {
    // Verify admin status
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists || (userDoc.data()?.role || '').toLowerCase() !== 'admin') {
      throw new HttpsError(
        'permission-denied', 
        'Only admin users can retrieve inactive conversations.'
      );
    }
    
    const snapshot = await admin.firestore()
      .collection('conversations')
      .where('active', '==', false)
      .get();
    
    const inactiveConversations: any[] = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      inactiveConversations.push({
        conversationId: doc.id,
        resellerId: data.resellerId,
        resellerName: data.resellerName,
        lastMessageTime: data.lastMessageTime || null,
        createdAt: data.createdAt || null
      });
    });
    
    logger.info(`Retrieved ${inactiveConversations.length} inactive conversations`);
    
    return { inactiveConversations };
  } catch (error) {
    logger.error('Error retrieving inactive conversations:', error);
    throw new HttpsError(
      'unknown', 
      `Failed to get inactive conversations: ${error instanceof Error ? error.message : String(error)}`
    );
  }
});

/**
 * Callable function that creates conversation documents for resellers who don't have one yet.
 * This is essentially a migration that can be run on demand.
 * Only authenticated admin users can call this function.
 */
export const runMigration = onCall({
  enforceAppCheck: false, // Set to true in production
}, async (request) => {
  // Ensure the caller is authenticated
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated', 
      'Authentication required.'
    );
  }
  
  const uid = request.auth.uid;
  
  try {
    // Verify admin status
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists || (userDoc.data()?.role || '').toLowerCase() !== 'admin') {
      throw new HttpsError(
        'permission-denied', 
        'Only admin users can run migrations.'
      );
    }
    
    logger.info('Starting migration: Creating missing conversations for resellers...');
    
    // Query all reseller users
    const usersSnapshot = await admin.firestore().collection('users')
      .where('role', '==', 'reseller')
      .get();
    
    logger.info(`Found ${usersSnapshot.size} reseller users`);
    
    let createdCount = 0;
    let existingCount = 0;
    
    for (const userDoc of usersSnapshot.docs) {
      const resellerId = userDoc.id;
      
      // Check if a conversation exists for this reseller
      const convSnapshot = await admin.firestore().collection('conversations')
        .where('resellerId', '==', resellerId)
        .limit(1)
        .get();
      
      if (convSnapshot.empty) {
        const userData = userDoc.data();
        const conversationData = {
          resellerId,
          resellerName: userData.displayName || userData.email || 'Unknown User',
          lastMessageContent: null,  // No stored messages
          lastMessageTime: null,
          active: false,             // Initially inactive
          unreadCounts: {},
          unreadByAdmin: false,
          unreadByReseller: false,
          unreadCount: 0,
          participants: ['admin', resellerId],
          activeUsers: [],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        
        await admin.firestore().collection('conversations').add(conversationData);
        logger.info(`Created conversation for reseller: ${resellerId} (${userData.email || 'unknown email'})`);
        createdCount++;
      } else {
        logger.info(`Conversation already exists for reseller: ${resellerId}`);
        existingCount++;
      }
    }
    
    logger.info('Migration complete:');
    logger.info(`- Created ${createdCount} new conversations`);
    logger.info(`- Found ${existingCount} existing conversations`);
    logger.info(`- Total resellers processed: ${usersSnapshot.size}`);
    
    return {
      success: true,
      created: createdCount,
      existing: existingCount,
      total: usersSnapshot.size,
      message: `Migration completed successfully. Created ${createdCount} new conversations.`
    };
  } catch (error) {
    logger.error('Error during migration:', error);
    throw new HttpsError(
      'internal',
      `Error during migration: ${error instanceof Error ? error.message : String(error)}`
    );
  }
});
