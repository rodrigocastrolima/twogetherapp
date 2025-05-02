import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as jsforce from "jsforce";

// --- Interfaces ---

interface GetCyclesParams {
  accessToken: string;
  instanceUrl: string;
}

interface SalesforceCiclo {
  id: string;
  name: string;
}

interface GetCyclesResult {
  cycles: SalesforceCiclo[];
  sessionExpired?: boolean; // Optional: Indicate if SF session was the issue
}

// --- Cloud Function Definition ---

export const getActivationCycles = onCall(
  {
    timeoutSeconds: 60,
    memory: "256MiB", // Should be lightweight
    // enforceAppCheck: true, // Recommended for production
    region: "us-central1", // Specify region consistently
  },
  async (request: CallableRequest<GetCyclesParams>): Promise<GetCyclesResult> => {
    logger.info("getActivationCycles function triggered");

    // 1. Authentication Check (Optional but recommended)
    if (!request.auth) {
      logger.warn("getActivationCycles called by unauthenticated user.");
      // Decide if this is allowed or should throw an error
      // throw new HttpsError("unauthenticated", "User must be authenticated.");
    } else {
        logger.info("Function called by authenticated user:", { uid: request.auth.uid });
    }

    // 2. Input Validation
    const { accessToken, instanceUrl } = request.data;
    if (!accessToken) {
        logger.error("Validation failed: Missing accessToken");
        throw new HttpsError("invalid-argument", "Missing accessToken");
    }
    if (!instanceUrl) {
        logger.error("Validation failed: Missing instanceUrl");
        throw new HttpsError("invalid-argument", "Missing instanceUrl");
    }
    logger.info("Input validation passed.");

    // 3. Salesforce API Call
    try {
      const conn = new jsforce.Connection({
        instanceUrl: instanceUrl,
        accessToken: accessToken,
      });
      logger.info("Salesforce connection initialized.");

      // Query for Ciclo records
      const query = "SELECT Id, Name FROM Ciclo__c ORDER BY Name"; // Example ordering
      logger.info("Executing SOQL query:", { query });

      const result = await conn.query<{ Id: string; Name: string }>(query);
      logger.info(`SOQL query successful. Found ${result.totalSize} records.`);

      // Map results
      const cycles: SalesforceCiclo[] = (result.records || []).map((record) => ({
          id: record.Id,
          name: record.Name,
      }));

      return { cycles };

    } catch (error: any) {
      logger.error('Error during getActivationCycles execution:', {
          name: error.name,
          code: error.errorCode,
          message: error.message,
          // stack: error.stack // Optional: include stack trace if needed for debugging
      });

      // Check for specific Salesforce session invalidation errors
      if (error.name === 'invalid_grant' || error.errorCode === 'INVALID_SESSION_ID') {
        logger.warn('Detected invalid session ID or grant error.');
        // Throw specific error for client to handle potential re-authentication
        throw new HttpsError('unauthenticated', 'Salesforce session expired or invalid.', { sessionExpired: true });
      } else {
        // Throw a generic internal error for other Salesforce issues
        const errorMessage = error.message || error.name || 'Unknown Salesforce API error';
        throw new HttpsError('internal', `Salesforce API call failed: ${errorMessage}`, {
            errorCode: error.errorCode,
            // fields: error.fields // Include fields if available
        });
      }
      // Note: The above throw will prevent the line below from executing,
      // but TS needs a return path. Returning an empty list in the catch
      // block is an alternative if you don't want to throw HttpsError.
      // return { cycles: [], sessionExpired: error.name === 'invalid_grant' || error.errorCode === 'INVALID_SESSION_ID' };
    }
  }
); 