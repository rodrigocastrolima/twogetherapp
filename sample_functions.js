/**
 * Sample Firebase Cloud Functions Implementation for User Creation & Salesforce Integration
 * 
 * This file provides sample implementations of the required Cloud Functions for the user
 * creation process. It can be used as a reference or starting point for troubleshooting.
 * 
 * To use this sample:
 * 1. Copy relevant functions to your functions/index.js or functions/src/ directory
 * 2. Adjust as needed to match your specific implementation requirements
 * 3. Deploy with: firebase deploy --only functions
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

// Configuration variables
const REGION = 'us-central1';
const SALESFORCE_API_BASE_URL = 'https://your-salesforce-instance.salesforce.com/services/data/v53.0';

/**
 * Simple ping function to test if Cloud Functions are accessible
 * 
 * @return {Object} Response with timestamp and message
 */
exports.ping = functions.region(REGION).https.onCall(async (data, context) => {
  console.log('Ping function called');
  
  return {
    timestamp: new Date().toISOString(),
    message: 'Firebase Cloud Functions are operational'
  };
});

/**
 * Creates a new user in Firebase Auth and Firestore
 * 
 * @param {Object} data Request data
 * @param {string} data.email User's email address
 * @param {string} data.password User's password
 * @param {string} data.displayName User's display name
 * @param {string} data.salesforceId User's Salesforce ID (optional)
 * @param {Object} context Function call context
 * @return {Object} Created user data
 */
exports.createUser = functions.region(REGION).https.onCall(async (data, context) => {
  // Log function call (remove sensitive data in production)
  console.log('createUser function called with data:', JSON.stringify({
    email: data.email,
    displayName: data.displayName,
    salesforceId: data.salesforceId
  }));

  // Check if caller is authenticated and has admin privileges
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  try {
    // Check if caller has admin role
    const callerUid = context.auth.uid;
    const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
    
    if (!callerDoc.exists || callerDoc.data().role !== 'admin') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admin users can create new users.'
      );
    }

    // Validate input data
    if (!data.email || !data.password) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Email and password are required.'
      );
    }

    // Create user in Firebase Auth
    console.log(`Creating user with email: ${data.email}`);
    const userRecord = await admin.auth().createUser({
      email: data.email,
      password: data.password,
      displayName: data.displayName || '',
      disabled: false
    });

    console.log(`User created with UID: ${userRecord.uid}`);

    // Create user document in Firestore
    const userData = {
      email: data.email,
      displayName: data.displayName || '',
      role: 'user',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: callerUid,
      salesforceId: data.salesforceId || null,
      isSyncedWithSalesforce: false
    };

    await admin.firestore().collection('users').doc(userRecord.uid).set(userData);
    console.log(`User document created in Firestore for UID: ${userRecord.uid}`);

    // If Salesforce ID is provided, sync with Salesforce
    if (data.salesforceId) {
      try {
        await syncUserWithSalesforceInternal(userRecord.uid, data.salesforceId);
      } catch (sfError) {
        console.error(`Error syncing user with Salesforce: ${sfError.message}`);
        // Don't throw here - we still created the user successfully
      }
    }

    // Return the created user data (excluding sensitive information)
    return {
      uid: userRecord.uid,
      email: userRecord.email,
      displayName: userRecord.displayName,
      salesforceId: data.salesforceId || null,
      isSyncedWithSalesforce: userData.isSyncedWithSalesforce
    };
  } catch (error) {
    console.error('Error creating user:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Error creating user: ${error.message}`
    );
  }
});

/**
 * Enables or disables a user account
 * 
 * @param {Object} data Request data
 * @param {string} data.uid User's UID
 * @param {boolean} data.enabled Whether to enable or disable the account
 * @param {Object} context Function call context
 * @return {Object} Result of the operation
 */
exports.setUserEnabled = functions.region(REGION).https.onCall(async (data, context) => {
  console.log(`setUserEnabled function called for UID: ${data.uid}, enabled: ${data.enabled}`);

  // Check if caller is authenticated and has admin privileges
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  try {
    // Check if caller has admin role
    const callerUid = context.auth.uid;
    const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
    
    if (!callerDoc.exists || callerDoc.data().role !== 'admin') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admin users can enable or disable users.'
      );
    }

    // Validate input data
    if (!data.uid) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'User UID is required.'
      );
    }

    // Update user in Firebase Auth
    await admin.auth().updateUser(data.uid, {
      disabled: !data.enabled
    });

    // Update user document in Firestore
    await admin.firestore().collection('users').doc(data.uid).update({
      disabled: !data.enabled,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: callerUid
    });

    return { success: true };
  } catch (error) {
    console.error('Error updating user enabled status:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Error updating user enabled status: ${error.message}`
    );
  }
});

/**
 * Synchronizes a user with Salesforce
 * 
 * @param {Object} data Request data
 * @param {string} data.uid User's UID
 * @param {string} data.salesforceId User's Salesforce ID
 * @param {Object} context Function call context
 * @return {Object} Result of the synchronization
 */
exports.syncUserWithSalesforce = functions.region(REGION).https.onCall(async (data, context) => {
  console.log(`syncUserWithSalesforce function called for UID: ${data.uid}, SF ID: ${data.salesforceId}`);

  // Check if caller is authenticated and has admin privileges
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  try {
    // Check if caller has admin role
    const callerUid = context.auth.uid;
    const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
    
    if (!callerDoc.exists || callerDoc.data().role !== 'admin') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admin users can sync users with Salesforce.'
      );
    }

    // Validate input data
    if (!data.uid || !data.salesforceId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'User UID and Salesforce ID are required.'
      );
    }

    // Call internal sync function
    await syncUserWithSalesforceInternal(data.uid, data.salesforceId);

    return { success: true };
  } catch (error) {
    console.error('Error syncing user with Salesforce:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Error syncing user with Salesforce: ${error.message}`
    );
  }
});

/**
 * Internal helper function to sync a user with Salesforce
 * 
 * @param {string} uid User's UID
 * @param {string} salesforceId User's Salesforce ID
 * @return {Promise<void>}
 */
async function syncUserWithSalesforceInternal(uid, salesforceId) {
  console.log(`Syncing user ${uid} with Salesforce ID: ${salesforceId}`);

  // Get user document from Firestore
  const userDoc = await admin.firestore().collection('users').doc(uid).get();
  
  if (!userDoc.exists) {
    throw new Error(`User with UID ${uid} not found in Firestore`);
  }

  const userData = userDoc.data();

  // Get Salesforce credentials from secure location (e.g., environment variables)
  // In a production environment, you'd use Firebase environment configuration
  const salesforceAuthData = await getSalesforceAuthData();

  try {
    // Begin a Firestore transaction to ensure data consistency
    await admin.firestore().runTransaction(async (transaction) => {
      // Update user document to mark sync in progress
      transaction.update(admin.firestore().collection('users').doc(uid), {
        syncInProgress: true,
        lastSyncAttempt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Here would be the actual Salesforce API call
      // For this sample, we'll just simulate it
      console.log(`Making API call to Salesforce for ID: ${salesforceId}`);
      
      // Simulated delay to mimic API call
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Successful sync - update user document
      transaction.update(admin.firestore().collection('users').doc(uid), {
        salesforceId: salesforceId,
        isSyncedWithSalesforce: true,
        syncInProgress: false,
        lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
        salesforceData: {
          // This would be populated with data from Salesforce
          recordId: salesforceId,
          lastSyncedAt: new Date().toISOString()
        }
      });
    });

    console.log(`Successfully synced user ${uid} with Salesforce`);
  } catch (error) {
    console.error(`Error during Salesforce sync for user ${uid}:`, error);
    
    // Update user document to mark sync failed
    await admin.firestore().collection('users').doc(uid).update({
      syncInProgress: false,
      lastSyncError: error.message,
      lastSyncAttempt: admin.firestore.FieldValue.serverTimestamp()
    });

    throw error;
  }
}

/**
 * Helper function to get Salesforce authentication data
 * In a real implementation, this would retrieve credentials from secure storage
 * 
 * @return {Promise<Object>} Salesforce auth data
 */
async function getSalesforceAuthData() {
  // In a real implementation, you would retrieve these from environment variables
  // or Firebase Config
  return {
    instanceUrl: SALESFORCE_API_BASE_URL,
    accessToken: 'simulated-access-token',
    // Other necessary auth info
  };
} 