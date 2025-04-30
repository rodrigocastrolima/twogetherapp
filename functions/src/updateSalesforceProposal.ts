import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as jsforce from "jsforce";

// Interface for expected input data
interface UpdateProposalParams {
  proposalId: string;
  accessToken: string; // Still passing credentials for now
  instanceUrl: string;
  fieldsToUpdate: { [key: string]: any }; // Map of field API names to values
}

// --- Cloud Function Definition ---

export const updateSalesforceProposal = onCall(
  {
    timeoutSeconds: 60,
    memory: "512MiB",
    region: "us-central1",
    // enforceAppCheck: true,
  },
  async (
    request: CallableRequest<UpdateProposalParams>
  ): Promise<{ success: boolean }> => {
    logger.info("updateSalesforceProposal function triggered");

    // 1. Authentication Check
    if (!request.auth) {
      logger.error("Authentication failed: User is not authenticated.");
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = request.auth.uid;
    logger.info("Authenticated user:", { uid });
    // TODO: Add admin role check similar to createUser function if needed

    // 2. Input Validation
    const data = request.data;
    if (
      !data.proposalId ||
      !data.accessToken ||
      !data.instanceUrl ||
      !data.fieldsToUpdate ||
      Object.keys(data.fieldsToUpdate).length === 0
    ) {
      logger.error("Validation failed: Missing required fields or empty update map", {
        receivedKeys: Object.keys(data),
        fieldsToUpdate: data.fieldsToUpdate,
      });
      throw new HttpsError(
        "invalid-argument",
        "Missing proposalId, credentials, or fieldsToUpdate."
      );
    }
    logger.info("Input validation passed for proposalId:", data.proposalId, { fields: Object.keys(data.fieldsToUpdate) });

    // 3. Salesforce Connection
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

    // 4. Prepare Update Payload (Add Id for update operation)
    const payload = {
      Id: data.proposalId,
      ...data.fieldsToUpdate,
    };
    logger.debug("Update Payload:", { payload });

    // 5. Execute Update
    try {
      const result = await conn.sobject('Proposta__c').update(payload);

      // jsforce update returns an array of results or single object
      const resultsArray = Array.isArray(result) ? result : [result];

      // Check for errors in the result(s)
      const errors = resultsArray.filter((res) => !res.success);
      if (errors.length > 0) {
        logger.error("Salesforce update failed for some/all records:", { errors });
        // Aggregate error messages if desired, or just report the first one
        const firstError = errors[0].errors?.join(', ') || 'Unknown update error';
        throw new HttpsError("internal", `Salesforce update failed: ${firstError}`, { details: errors });
      }

      logger.info("Successfully updated Proposta__c:", { proposalId: data.proposalId });
      return { success: true };

    } catch (error: any) {
      logger.error("Error executing Salesforce update:", error);
       if (error instanceof HttpsError) { // Re-throw HttpsErrors from above check
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