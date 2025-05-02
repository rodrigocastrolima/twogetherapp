import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as jsforce from "jsforce";

// Initialize Firebase Admin SDK (if not already done)
try {
  if (admin.apps.length === 0) {
    admin.initializeApp();
    logger.info("Firebase Admin SDK initialized in checkNifExistsInSalesforce.");
  }
} catch (e) {
  logger.info("Firebase Admin SDK already initialized.");
}

// --- Interfaces ---

interface CheckNifParams {
  accessToken: string;
  instanceUrl: string;
  nif: string;
}

interface CheckNifResult {
  exists: boolean;
  accountId?: string | null; // Include account ID if found
  error?: string | null;
  sessionExpired?: boolean;
}

// --- Cloud Function Definition ---

export const checkNifExistsInSalesforce = onCall(
  {
    timeoutSeconds: 60,   // Standard timeout should be sufficient
    memory: "256MiB",   // Moderate memory
    region: "us-central1", // Match other functions
    // enforceAppCheck: true, // Recommended for production
  },
  async (request: CallableRequest<CheckNifParams>): Promise<CheckNifResult> => {
    logger.info("checkNifExistsInSalesforce function triggered");

    // 1. Authentication & Authorization (Admin Check)
    if (!request.auth) {
      logger.error("Authentication failed: User is not authenticated.");
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const adminUid = request.auth.uid;
    logger.info("Authenticated user (Admin):", { uid: adminUid });

    try {
      const userDoc = await admin.firestore().collection('users').doc(adminUid).get();
      if (!userDoc.exists || userDoc.data()?.role !== 'admin') {
        logger.error("Authorization failed: User is not an admin.", { uid: adminUid });
        throw new HttpsError("permission-denied", "User does not have permission.");
      }
      logger.info("User authorized as Admin.", { uid: adminUid });
    } catch (dbError: any) {
      logger.error("Error fetching admin user document:", { uid: adminUid, error: dbError });
      throw new HttpsError("internal", "Failed to verify user permissions.");
    }

    // 2. Input Validation
    const data = request.data;
    if (!data.accessToken || !data.instanceUrl || !data.nif) {
      logger.error("Validation failed: Missing required fields (accessToken, instanceUrl, nif)", { receivedKeys: Object.keys(data) });
      throw new HttpsError("invalid-argument", "Missing required NIF check data.");
    }
    const nifToCheck = data.nif.trim();
    if (!nifToCheck) {
        logger.error("Validation failed: NIF cannot be empty.");
        throw new HttpsError("invalid-argument", "NIF cannot be empty.");
    }
    logger.info("Input validation passed.", { nif: nifToCheck });

    // 3. Salesforce Connection
    let conn: jsforce.Connection;
    try {
      conn = new jsforce.Connection({
        instanceUrl: data.instanceUrl,
        accessToken: data.accessToken,
        version: '58.0' // Specify API version explicitly if needed
      });
      logger.info("Salesforce connection initialized.");
    } catch (connError: any) {
      logger.error("Failed to initialize Salesforce connection:", connError);
      throw new HttpsError("internal", "Failed to establish Salesforce connection.");
    }

    // 4. Query Salesforce Account by NIF
    try {
      logger.info(`Querying Salesforce Account with NIF__c = ${nifToCheck}...`);

      // Use findOne for efficiency - only need to know if one exists and get its ID
      // Ensure NIF__c is the correct API name for the NIF field on Account
      const result = await callSalesforceApi<{ Id: string } | null>(async () => {
        return await conn.sobject("Account").findOne(
          { NIF__c: nifToCheck }, // Filter condition
          { Id: 1 }               // Fields to retrieve (just ID is enough)
        );
      });

      if (result) {
        // Account found
        logger.info(`Account found for NIF ${nifToCheck}. Account ID: ${result.Id}`);
        return { exists: true, accountId: result.Id, error: null, sessionExpired: false };
      } else {
        // No account found
        logger.info(`No Account found for NIF ${nifToCheck}.`);
        return { exists: false, accountId: null, error: null, sessionExpired: false };
      }

    } catch (error) {
      logger.error("Error during Salesforce query:", error);

      if (error instanceof HttpsError) {
        // If it's already an HttpsError (e.g., session expired), check details
        const details = error.details as { sessionExpired?: boolean } | undefined;
        return {
          exists: false, // Assume not found on error
          error: error.message,
          sessionExpired: details?.sessionExpired ?? false,
        };
      } else if (error instanceof Error) {
        return { exists: false, error: error.message, sessionExpired: false };
      } else {
        return { exists: false, error: "An unexpected error occurred during Salesforce query.", sessionExpired: false };
      }
    }
  }
);


// --- Salesforce API Call Helper Function (Copied from createSalesforceProposal) ---
// Consider moving this to a shared utility file in the future.
async function callSalesforceApi<T>(
    apiCall: () => Promise<T>,
    checkSessionExpiry = true
): Promise<T> {
    logger.info("Executing Salesforce API call...");
    try {
        const result = await apiCall();
        logger.info("Salesforce API call successful.");
        return result;
    } catch (error: any) {
        logger.error('Salesforce API Error caught in helper:', {
            name: error.name,
            code: error.errorCode,
            message: error.message,
        });

        if (checkSessionExpiry &&
            (error.name === 'invalid_grant' ||
             error.errorCode === 'INVALID_SESSION_ID' ||
             (error.errorCode && typeof error.errorCode === 'string' && error.errorCode.includes('INVALID_SESSION_ID'))))
        {
            logger.warn('Detected invalid session ID or grant error.');
            throw new HttpsError('unauthenticated', 'Salesforce session expired or invalid.', { sessionExpired: true });
        } else {
            const errorMessage = error.message || error.name || 'Unknown Salesforce API error';
            const details = {
                 errorCode: error.errorCode,
                 fields: error.fields
             };
            throw new HttpsError('internal', `Salesforce API call failed: ${errorMessage}`, details);
        }
    }
} 