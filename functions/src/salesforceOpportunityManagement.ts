import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as jsforce from "jsforce";

// Ensure Firebase Admin SDK is initialized (consider moving to index.ts if not already done)
try {
  if (admin.apps.length === 0) {
    admin.initializeApp();
    logger.info("Firebase Admin SDK initialized in salesforceOpportunityManagement.");
  }
} catch (e) {
  logger.error("Error initializing Firebase Admin SDK:", e);
}

// --- Interfaces ---

interface SalesforceAuthParams {
  accessToken: string;
  instanceUrl: string;
}

interface GetOppParams extends SalesforceAuthParams {
  // Add any specific query parameters if needed in the future (e.g., filters)
}

interface DeleteOppParams extends SalesforceAuthParams {
  opportunityId: string;
}

// Represents the structure of data returned for each opportunity in the list
interface SalesforceOpportunitySummary {
  id: string;
  name: string;
  accountName: string | null; // Account.Name can be null
  resellerName: string | null; // Agente_Retail__r.Name can be null
}

interface DeleteOppResult {
  success: boolean;
  error?: string;
  sessionExpired?: boolean;
}


// --- Cloud Function: getSalesforceOpportunities ---

export const getSalesforceOpportunities = onCall(
  {
    timeoutSeconds: 60,
    memory: "256MiB",
    // enforceAppCheck: true, // Recommended for production
  },
  async (request: CallableRequest<GetOppParams>): Promise<SalesforceOpportunitySummary[]> => {
    logger.info("getSalesforceOpportunities function triggered");

    // 1. Authentication Check
    if (!request.auth) {
      logger.error("Authentication failed: User is not authenticated.");
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = request.auth.uid;
    logger.info("User authenticated.", { uid: uid });

    // 2. Authorization Check (Fetch Firestore User Doc)
    try {
      const userDoc = await admin.firestore().collection('users').doc(uid).get();
      if (!userDoc.exists) {
        logger.error("Authorization failed: User document not found.", { uid: uid });
        throw new HttpsError("permission-denied", "User data not found.");
      }
      const userData = userDoc.data();
      const userRole = userData?.role;

      if (userRole !== 'admin') {
        logger.error("Authorization failed: User role is not 'admin'.", { uid: uid, role: userRole });
        throw new HttpsError("permission-denied", "User does not have admin permission.");
      }
      logger.info("User authorized as Admin based on Firestore role.", { uid: uid });

    } catch (dbError: any) {
      logger.error("Error fetching user document for authorization:", { uid: uid, error: dbError });
      throw new HttpsError("internal", "Failed to verify user permissions.");
    }

    // 3. Input Validation
    const data = request.data;
    if (!data.accessToken) throw new HttpsError("invalid-argument", "Missing accessToken");
    if (!data.instanceUrl) throw new HttpsError("invalid-argument", "Missing instanceUrl");
    logger.info("Input validation passed.");
    // !!! SECURITY WARNING: Logging full access token for debug ONLY. REMOVE before production !!!
    logger.debug("[getSalesforceOpportunities] Received Access Token (DEBUG):", { accessToken: data.accessToken });
    // !!! END SECURITY WARNING !!!

    // 4. Salesforce API Call
    try {
      const conn = new jsforce.Connection({
        instanceUrl: data.instanceUrl,
        accessToken: data.accessToken,
      });
      logger.info("Salesforce connection initialized.");

      const soqlQuery = `
        SELECT Id, Name, Entidade__r.Name, Agente_Retail__r.Name 
        FROM Oportunidade__c
        WHERE RecordType.DeveloperName = 'Retail'
        ORDER BY CreatedDate DESC
      `;
      // Add LIMIT if needed, e.g., LIMIT 1000

      logger.info("Executing SOQL query for Retail Opportunities...");
      const result = await conn.query<any>(soqlQuery); // Use 'any' for flexibility with relationship queries
      logger.info(`Query successful. Found ${result.totalSize} records.`);

      // 5. Process and Map Results
      const opportunities: SalesforceOpportunitySummary[] = result.records.map((record) => {
        return {
          id: record.Id,
          name: record.Name,
          accountName: record.Entidade__r ? record.Entidade__r.Name : null, // Reverted to fetch Account Name via Entidade__r
          resellerName: record.Agente_Retail__r ? record.Agente_Retail__r.Name : null, // Reverted to fetch Reseller Name via Agente_Retail__r
        };
      });

      return opportunities;

    } catch (error: any) {
      // +++ Enhanced Error Logging +++
      logger.error("Caught error during Salesforce API call (getSalesforceOpportunities):", { 
         message: error.message,
         name: error.name,
         errorCode: error.errorCode,
         stack: error.stack,
         errorObjectString: JSON.stringify(error) // Attempt to stringify the whole error
      });
      // ++++++++++++++++++++++++++++++

      // Check for session expiry errors
      if (error.name === 'invalid_grant' || error.errorCode === 'INVALID_SESSION_ID') {
         logger.warn("[getSalesforceOpportunities] Detected Salesforce session expiry error. Throwing standard Error with custom message.");
         // Throw a standard Error instead of HttpsError
         throw new Error('SALESFORCE_SESSION_EXPIRED'); 
      }
      // Throw generic internal error for other issues
      logger.error("[getSalesforceOpportunities] Did not detect session expiry. Throwing HttpsError 'internal'.");
      // Keep HttpsError for other internal issues for now
      throw new HttpsError('internal', `Failed to fetch Salesforce Opportunities: ${error.message || error.name}`);
    }
  }
);


// --- Cloud Function: deleteSalesforceOpportunity ---

export const deleteSalesforceOpportunity = onCall(
  {
    timeoutSeconds: 60,
    memory: "256MiB",
    // enforceAppCheck: true, // Recommended for production
  },
  async (request: CallableRequest<DeleteOppParams>): Promise<DeleteOppResult> => {
    logger.info("deleteSalesforceOpportunity function triggered", { opportunityId: request.data.opportunityId });

    // 1. Authentication Check
    if (!request.auth) {
      logger.error("Authentication failed: User is not authenticated.");
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = request.auth.uid;
    logger.info("User authenticated.", { uid: uid });

    // 2. Authorization Check (Fetch Firestore User Doc)
    try {
      const userDoc = await admin.firestore().collection('users').doc(uid).get();
      if (!userDoc.exists) {
        logger.error("Authorization failed: User document not found.", { uid: uid });
        throw new HttpsError("permission-denied", "User data not found.");
      }
      const userData = userDoc.data();
      const userRole = userData?.role;

      if (userRole !== 'admin') {
        logger.error("Authorization failed: User role is not 'admin'.", { uid: uid, role: userRole });
        throw new HttpsError("permission-denied", "User does not have admin permission.");
      }
      logger.info("User authorized as Admin based on Firestore role.", { uid: uid });

    } catch (dbError: any) {
      logger.error("Error fetching user document for authorization:", { uid: uid, error: dbError });
      throw new HttpsError("internal", "Failed to verify user permissions.");
    }

    // 3. Input Validation
    const data = request.data;
    if (!data.accessToken) throw new HttpsError("invalid-argument", "Missing accessToken");
    if (!data.instanceUrl) throw new HttpsError("invalid-argument", "Missing instanceUrl");
    if (!data.opportunityId) throw new HttpsError("invalid-argument", "Missing opportunityId");
    logger.info("Input validation passed.");
    // !!! SECURITY WARNING: Logging full access token for debug ONLY. REMOVE before production !!!
    logger.debug("[deleteSalesforceOpportunity] Received Access Token (DEBUG):", { accessToken: data.accessToken });
    // !!! END SECURITY WARNING !!!

    // 4. Salesforce API Call
    try {
      const conn = new jsforce.Connection({
        instanceUrl: data.instanceUrl,
        accessToken: data.accessToken,
      });
      logger.info("Salesforce connection initialized.");

      logger.info(`Attempting to delete Opportunity ID: ${data.opportunityId}...`);
      // The result of destroy is an array of success/error objects
      const result: any = await conn.sobject('Oportunidade__c').destroy(data.opportunityId);
      logger.debug("Salesforce destroy result:", { result });

      // Check if the result indicates success (jsforce might return single object or array)
      const resultsArray = Array.isArray(result) ? result : [result];
      const firstResult = resultsArray[0]; // Check the first (and likely only) result

      if (firstResult && firstResult.success) {
        logger.info(`Successfully deleted Opportunity ID: ${data.opportunityId}`);
        return { success: true };
      } else {
        // Extract error message if available
        const errorMessage = firstResult?.errors?.map((e: any) => `${e.statusCode}: ${e.message}`).join(', ') || 'Unknown delete error';
        logger.error(`Failed to delete Opportunity ID: ${data.opportunityId}. Error: ${errorMessage}`, { errors: firstResult?.errors });
        throw new HttpsError("internal", `Failed to delete Opportunity in Salesforce: ${errorMessage}`);
      }

    } catch (error: any) {
      // +++ Enhanced Error Logging +++
      logger.error("Caught error during Salesforce API call (deleteSalesforceOpportunity):", { 
         message: error.message,
         name: error.name,
         errorCode: error.errorCode,
         stack: error.stack,
         errorObjectString: JSON.stringify(error) // Attempt to stringify the whole error
      });
      // ++++++++++++++++++++++++++++++

      // Check for session expiry errors
      if (error.name === 'invalid_grant' || error.errorCode === 'INVALID_SESSION_ID') {
        logger.warn("[deleteSalesforceOpportunity] Detected Salesforce session expiry error. Throwing standard Error with custom message.");
        // Throw a standard Error instead of HttpsError
        throw new Error('SALESFORCE_SESSION_EXPIRED'); 
      }
      // If it's already an HttpsError (e.g., from the failure check above), rethrow it
      if (error instanceof HttpsError) {
          logger.warn("[deleteSalesforceOpportunity] Rethrowing existing HttpsError.");
          throw error;
      }
      // Throw generic internal error for other issues
      logger.error("[deleteSalesforceOpportunity] Did not detect session expiry or HttpsError. Throwing HttpsError 'internal'.");
       // Keep HttpsError for other internal issues for now
      throw new HttpsError('internal', `Failed to delete Salesforce Opportunity: ${error.message || error.name}`);
    }
  }
); 