import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as jsforce from "jsforce";

// Ensure Firebase Admin SDK is initialized (often done in index.ts)
try {
  if (admin.apps.length === 0) {
      admin.initializeApp();
      logger.info("Firebase Admin SDK initialized in updateSalesforceOpportunity.");
  }
} catch (e) {
  logger.info("Firebase Admin SDK already initialized.");
}

// --- Interfaces ---

interface UpdateOppParams {
  opportunityId: string;
  fieldsToUpdate: { [key: string]: any }; // Object with Field API Name -> New Value
  accessToken: string;
  instanceUrl: string;
}

interface UpdateOppResult {
  success: boolean;
  error?: string;
  validationErrors?: any; // To capture Salesforce validation errors
  sessionExpired?: boolean;
}

// --- Cloud Function Definition ---

export const updateSalesforceOpportunity = onCall(
  {
    timeoutSeconds: 60,
    memory: "256MiB",
    // enforceAppCheck: true, // Recommended for production
  },
  async (request: CallableRequest<UpdateOppParams>): Promise<UpdateOppResult> => {
    logger.info("updateSalesforceOpportunity function triggered", { params: { opportunityId: request.data.opportunityId, fields: Object.keys(request.data.fieldsToUpdate || {}) } });

    // 1. Authentication Check
    if (!request.auth) {
      logger.error("Authentication failed: User is not authenticated.");
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = request.auth.uid;
    logger.info("Authentication check passed.", { uid });

    // 2. Input Validation
    const { opportunityId, fieldsToUpdate, accessToken, instanceUrl } = request.data;
    if (!opportunityId) {
      logger.error("Validation failed: Missing opportunityId");
      throw new HttpsError("invalid-argument", "Missing opportunityId");
    }
    if (!fieldsToUpdate || Object.keys(fieldsToUpdate).length === 0) {
      logger.error("Validation failed: Missing or empty fieldsToUpdate");
      throw new HttpsError("invalid-argument", "Missing or empty fieldsToUpdate");
    }
    if (!accessToken) {
      logger.error("Validation failed: Missing accessToken");
      throw new HttpsError("invalid-argument", "Missing accessToken");
    }
    if (!instanceUrl) {
      logger.error("Validation failed: Missing instanceUrl");
      throw new HttpsError("invalid-argument", "Missing instanceUrl");
    }
    logger.info("Input validation passed.");

    try {
      // 3. Salesforce Connection
      const conn = new jsforce.Connection({
          instanceUrl: instanceUrl,
          accessToken: accessToken,
      });
      logger.info("Salesforce connection initialized.");

      // 4. Authorization Check (Example: Ensure user is Admin or authorized Reseller)
      //    You might need to fetch the opportunity first to check ownership
      //    or rely on Firestore roles. Reusing simplified Admin check for now.
      try {
        const userDoc = await admin.firestore().collection('users').doc(uid).get();
        if (!userDoc.exists) {
          logger.error("Authorization failed: User document not found.", { uid });
          throw new HttpsError("permission-denied", "User data not found.");
        }
        const userRole = userDoc.data()?.role;

        if (userRole !== 'admin') {
          // TODO: Implement more granular checks if needed (e.g., check if reseller owns the opp)
          logger.error("Authorization failed: User role is not 'admin'.", { uid, role: userRole });
          throw new HttpsError("permission-denied", "User does not have permission to update this opportunity.");
        }
        logger.info("User authorized as Admin based on Firestore role.", { uid });

      } catch (authError: any) {
        logger.error("Error during authorization check:", { uid, error: authError });
        throw new HttpsError("internal", "Failed to verify user permissions.");
      }

      // 5. Prepare Update Payload
      const updatePayload = {
        Id: opportunityId,
        ...fieldsToUpdate, // Spread the fields to update
      };
      logger.debug("Salesforce Update Payload:", { payload: updatePayload });

      // 6. Execute Salesforce Update
      logger.info("Attempting Salesforce opportunity update...", { opportunityId });
      const result: any = await conn.sobject('Oportunidade__c').update(updatePayload);
      logger.debug("Salesforce Update Result:", { result });

      // 7. Process Result
      if (result.success) {
        logger.info("Successfully updated Opportunity in Salesforce.", { opportunityId });
        return { success: true };
      } else {
        // Handle potential errors array from Salesforce
        const errors = result.errors || ["Unknown update error"];
        const errorMessage = errors.map((e: any) => (typeof e === 'string') ? e : `${e.statusCode}: ${e.message} [${e.fields?.join(', ') || 'N/A'}]`).join('; ');
        logger.error("Salesforce update failed.", { opportunityId, errors: result.errors });
        // Check if it's a validation rule error
        const isValidationError = errors.some((e: any) => e.statusCode?.includes('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
        throw new HttpsError("internal", `Salesforce update failed: ${errorMessage}`, { validationErrors: isValidationError ? result.errors : undefined } );
      }

    } catch (error: any) {
      logger.error("Error in updateSalesforceOpportunity main try block:", error);
      if (error instanceof HttpsError) {
        // Rethrow HttpsErrors (including potential validation errors handled above)
        throw error;
      }
      // Check for session expiry before throwing generic error
      if (error.name === 'invalid_grant' || error.errorCode === 'INVALID_SESSION_ID') {
        logger.warn('Detected invalid session ID or grant error.');
        throw new HttpsError('unauthenticated', 'Salesforce session expired or invalid.', { sessionExpired: true });
      }
      // Wrap other unexpected errors
      throw new HttpsError("internal", "An unexpected error occurred during the update.", error);
    }
  }
); 