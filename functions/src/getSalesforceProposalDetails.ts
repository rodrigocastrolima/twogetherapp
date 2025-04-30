import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as jsforce from "jsforce";

// Interface for expected input data
interface GetProposalDetailsParams {
  proposalId: string;
  accessToken: string;
  instanceUrl: string;
}

// --- Cloud Function Definition ---

export const getSalesforceProposalDetails = onCall(
  {
    timeoutSeconds: 60,
    memory: "512MiB",
    region: "us-central1", // Specify region consistently
    // enforceAppCheck: true, // Recommended for production
  },
  async (
    request: CallableRequest<GetProposalDetailsParams>
  ): Promise<any> => { // Return type 'any' for now, matches raw SF record
    logger.info("getSalesforceProposalDetails function triggered");

    // 1. Authentication Check (Check if user is logged into Firebase)
    if (!request.auth) {
      logger.error("Authentication failed: User is not authenticated.");
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = request.auth.uid;
    logger.info("Authenticated user:", { uid });

    // 2. Input Validation
    const data = request.data;
    if (!data.proposalId || !data.accessToken || !data.instanceUrl) {
      logger.error("Validation failed: Missing required fields", {
        receivedKeys: Object.keys(data),
      });
      throw new HttpsError(
        "invalid-argument",
        "Missing proposalId, accessToken, or instanceUrl."
      );
    }
    logger.info("Input validation passed for proposalId:", data.proposalId);

    // 3. Salesforce Connection
    let conn: jsforce.Connection;
    try {
      conn = new jsforce.Connection({
        instanceUrl: data.instanceUrl,
        accessToken: data.accessToken,
        version: '58.0', // Optional: Specify API version
      });
      logger.info("Salesforce connection initialized.");
    } catch (connError: any) {
      logger.error("Failed to initialize Salesforce connection:", connError);
      throw new HttpsError(
        "internal",
        "Failed to establish Salesforce connection."
      );
    }

    // 4. Construct SOQL Query (Same as before)
    // IMPORTANT: Verify relationship names 'CPE_Propostas__r' and 'ContentDocumentLinks'
    const soqlQuery = `
      SELECT
        Id, Name,
        Entidade__c, Entidade__r.Name, NIF__c,
        Oportunidade__c, Oportunidade__r.Name,
        Agente_Retail__c, Agente_Retail__r.Name,
        Respons_vel_de_Neg_cio_Retail__c, Respons_vel_de_Neg_cio_Exclusivo__c,
        Status__c, Solu_o__c, Consumo_para_o_per_odo_do_contrato_KWh__c,
        Energia__c, Solar__c, Valor_de_Investimento_Solar__c,
        Data_de_Cria_o_da_Proposta__c, Data_de_In_cio_do_Contrato__c, Data_de_Validade__c, Data_de_fim_do_Contrato__c,
        Bundle__c, Contrato_inserido__c,
        (SELECT Id, CPE_Proposta__r.Id, CPE_Proposta__r.Name FROM CPE_Propostas__r),
        (SELECT ContentDocument.Id, ContentDocument.Title, ContentDocument.FileExtension, ContentDocument.FileType, ContentDocument.LatestPublishedVersionId FROM ContentDocumentLinks ORDER BY ContentDocument.CreatedDate DESC)
      FROM Proposta__c
      WHERE Id = '${data.proposalId}'
      LIMIT 1
    `;
    logger.debug("Executing SOQL:", { query: soqlQuery });

    // 5. Execute Query
    try {
      const result = await conn.query(soqlQuery);

      if (result.totalSize === 0 || !result.records || result.records.length === 0) {
        logger.warn("No proposal found for ID:", { proposalId: data.proposalId });
        throw new HttpsError("not-found", `Proposal not found for ID: ${data.proposalId}`);
      }

      // 6. Return the first record's raw JSON
      // Remove noisy 'attributes' field from nested records if present
      const record = result.records[0];
      if (record.CPE_Propostas__r && record.CPE_Propostas__r.records) {
        record.CPE_Propostas__r.records = record.CPE_Propostas__r.records.map((r: any) => { delete r.attributes; return r; });
      }
      if (record.ContentDocumentLinks && record.ContentDocumentLinks.records) {
        record.ContentDocumentLinks.records = record.ContentDocumentLinks.records.map((r: any) => { delete r.attributes; return r; });
      }
      delete record.attributes; // Remove from top-level record

      logger.info("Successfully fetched proposal details.");
      return record; // Return the raw record data

    } catch (error: any) {
        logger.error("Error executing Salesforce query:", error);
        // Check for specific Salesforce session invalidation errors
        if (error.name === 'invalid_grant' || error.errorCode === 'INVALID_SESSION_ID') {
            logger.warn('Detected invalid session ID or grant error.');
            throw new HttpsError('unauthenticated', 'Salesforce session expired or invalid.', { sessionExpired: true });
        }
        // Throw a generic internal error for other Salesforce issues
        const errorMessage = error.message || error.name || 'Unknown Salesforce API error';
        throw new HttpsError('internal', `Salesforce API call failed: ${errorMessage}`, { errorCode: error.errorCode });
    }
  }
); 