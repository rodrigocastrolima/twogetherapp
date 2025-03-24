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
admin.initializeApp();

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
