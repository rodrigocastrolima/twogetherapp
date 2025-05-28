import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as jsforce from "jsforce";

// Ensure Firebase Admin SDK is initialized
try {
  if (admin.apps.length === 0) {
    admin.initializeApp();
    logger.info("Firebase Admin SDK initialized in updateCpePropostaDetails.");
  }
} catch (e) {
  logger.info("Firebase Admin SDK already initialized.");
}

// Interface for expected input data
interface UpdateCpePropostaParams {
  cpePropostaId: string;
  accessToken: string;
  instanceUrl: string;
  cpeFieldsToUpdate?: { [key: string]: any }; // CPE__c fields
  cpePropostaFieldsToUpdate?: { [key: string]: any }; // CPE_Proposta__c fields
}

// --- Cloud Function Definition ---
export const updateCpePropostaDetails = onCall(
  {
    timeoutSeconds: 60,
    memory: "512MiB",
    region: "us-central1",
    // enforceAppCheck: true,
  },
  async (
    request: CallableRequest<UpdateCpePropostaParams>
  ): Promise<{ success: boolean }> => {
    logger.info("updateCpePropostaDetails function triggered");

    // 1. Authentication Check
    if (!request.auth) {
      logger.error("Authentication failed: User is not authenticated.");
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = request.auth.uid;
    logger.info("Authenticated user:", { uid });

    // 2. Authorization Check (Admin or authorized reseller)
    try {
      const userDoc = await admin.firestore().collection('users').doc(uid).get();
      if (!userDoc.exists) {
        logger.error("Authorization failed: User document not found.", { uid });
        throw new HttpsError("permission-denied", "User data not found.");
      }
      const userData = userDoc.data();
      const userRole = userData?.role;
      if (userRole !== 'admin' && userRole !== 'reseller') {
        logger.error("Authorization failed: User is not admin or reseller.", { uid, userRole });
        throw new HttpsError("permission-denied", "User does not have permission.");
      }
      logger.info("User authorized.", { uid, userRole });
    } catch (authError: any) {
      logger.error("Error during authorization check:", authError);
      if (authError instanceof HttpsError) throw authError;
      throw new HttpsError("internal", "Failed to verify user permissions.");
    }

    // 3. Input Validation
    const data = request.data;
    if (
      !data.cpePropostaId ||
      !data.accessToken ||
      !data.instanceUrl ||
      (!data.cpeFieldsToUpdate && !data.cpePropostaFieldsToUpdate) ||
      (data.cpeFieldsToUpdate && Object.keys(data.cpeFieldsToUpdate).length === 0) &&
      (data.cpePropostaFieldsToUpdate && Object.keys(data.cpePropostaFieldsToUpdate).length === 0)
    ) {
      logger.error("Validation failed: Missing required fields or no fields to update", {
        receivedKeys: Object.keys(data),
        cpeFieldsCount: data.cpeFieldsToUpdate ? Object.keys(data.cpeFieldsToUpdate).length : 0,
        cpePropostaFieldsCount: data.cpePropostaFieldsToUpdate ? Object.keys(data.cpePropostaFieldsToUpdate).length : 0,
      });
      throw new HttpsError(
        "invalid-argument",
        "Missing cpePropostaId, credentials, or no fields to update."
      );
    }
    logger.info("Input validation passed for cpePropostaId:", data.cpePropostaId, {
      cpeFields: data.cpeFieldsToUpdate ? Object.keys(data.cpeFieldsToUpdate) : [],
      cpePropostaFields: data.cpePropostaFieldsToUpdate ? Object.keys(data.cpePropostaFieldsToUpdate) : [],
    });

    // 4. Salesforce Connection
    let conn: jsforce.Connection;
    try {
      conn = new jsforce.Connection({
        instanceUrl: data.instanceUrl,
        accessToken: data.accessToken,
        version: '58.0',
      });
      logger.info("Salesforce connection initialized.");
    } catch (connError: any) {
      logger.error("Failed to initialize Salesforce connection:", connError);
      throw new HttpsError(
        "internal",
        "Failed to establish Salesforce connection."
      );
    }

    try {
      // 5. First, get the CPE ID from the CPE_Proposta__c record
      let cpeId: string | null = null;
      if (data.cpeFieldsToUpdate && Object.keys(data.cpeFieldsToUpdate).length > 0) {
        logger.info("Fetching CPE ID from CPE_Proposta__c...");
        const cpePropostaResult = await conn.sobject('CPE_Proposta__c').findOne(
          { Id: data.cpePropostaId },
          ['CPE_Proposta__c']
        );
        
        if (!cpePropostaResult || !cpePropostaResult.CPE_Proposta__c) {
          logger.error("Failed to find CPE_Proposta__c or get CPE ID:", { cpePropostaId: data.cpePropostaId });
          throw new HttpsError("not-found", "CPE_Proposta__c record not found or missing CPE reference.");
        }
        
        cpeId = cpePropostaResult.CPE_Proposta__c as string;
        logger.info("Found CPE ID:", { cpeId });
      }

      // 6. Update CPE__c record if needed
      if (data.cpeFieldsToUpdate && Object.keys(data.cpeFieldsToUpdate).length > 0 && cpeId) {
        const cpePayload = {
          Id: cpeId,
          ...data.cpeFieldsToUpdate,
        };
        logger.debug("CPE Update Payload:", { payload: cpePayload });

        const cpeResult = await conn.sobject('CPE__c').update(cpePayload);
        const cpeResultsArray = Array.isArray(cpeResult) ? cpeResult : [cpeResult];
        const cpeErrors = cpeResultsArray.filter((res) => !res.success);
        
        if (cpeErrors.length > 0) {
          logger.error("CPE update failed:", { errors: cpeErrors });
          const firstError = cpeErrors[0].errors?.join(', ') || 'Unknown CPE update error';
          throw new HttpsError("internal", `CPE update failed: ${firstError}`, { details: cpeErrors });
        }
        
        logger.info("Successfully updated CPE__c:", { cpeId });
      }

      // 7. Update CPE_Proposta__c record if needed
      if (data.cpePropostaFieldsToUpdate && Object.keys(data.cpePropostaFieldsToUpdate).length > 0) {
        const cpePropostaPayload = {
          Id: data.cpePropostaId,
          ...data.cpePropostaFieldsToUpdate,
        };
        logger.debug("CPE_Proposta Update Payload:", { payload: cpePropostaPayload });

        const cpePropostaResult = await conn.sobject('CPE_Proposta__c').update(cpePropostaPayload);
        const cpePropostaResultsArray = Array.isArray(cpePropostaResult) ? cpePropostaResult : [cpePropostaResult];
        const cpePropostaErrors = cpePropostaResultsArray.filter((res) => !res.success);
        
        if (cpePropostaErrors.length > 0) {
          logger.error("CPE_Proposta update failed:", { errors: cpePropostaErrors });
          const firstError = cpePropostaErrors[0].errors?.join(', ') || 'Unknown CPE_Proposta update error';
          throw new HttpsError("internal", `CPE_Proposta update failed: ${firstError}`, { details: cpePropostaErrors });
        }
        
        logger.info("Successfully updated CPE_Proposta__c:", { cpePropostaId: data.cpePropostaId });
      }

      logger.info("Successfully updated CPE-Proposta details");
      return { success: true };

    } catch (error: any) {
      logger.error("Error executing Salesforce updates:", error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      // Check for specific Salesforce session invalidation errors
      if (error.name === 'invalid_grant' || error.errorCode === 'INVALID_SESSION_ID') {
        logger.warn('Detected invalid session ID or grant error.');
        throw new HttpsError('unauthenticated', 'Salesforce session expired or invalid.', { sessionExpired: true });
      }
      
      // Throw a generic internal error for other Salesforce issues
      const errorMessage = error.message || error.name || 'Unknown Salesforce API error';
      throw new HttpsError('internal', `Salesforce API update call failed: ${errorMessage}`, { errorCode: error.errorCode });
    }
  }
); 