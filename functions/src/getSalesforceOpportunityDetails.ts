import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as jsforce from "jsforce";

// Ensure Firebase Admin SDK is initialized (often done in index.ts)
try {
  if (admin.apps.length === 0) {
      admin.initializeApp();
      logger.info("Firebase Admin SDK initialized in getSalesforceOpportunityDetails.");
  }
} catch (e) {
  logger.info("Firebase Admin SDK already initialized.");
}

// --- Interfaces ---

interface GetOppDetailsParams {
  opportunityId: string;
  accessToken: string;
  instanceUrl: string;
}

// Define structure for the detailed opportunity data
interface DetailedOpportunityData {
  Id: string;
  Name: string;
  AccountName?: string; // From Entidade__r.Name
  AccountId?: string;   // <-- ADD: From Entidade__c
  ResellerName?: string; // From Agente_Retail__r.Name
  ResellerSalesforceId?: string; // <-- ADD: From Agente_Retail__c
  NIF__c?: string;
  Fase__c?: string;
  CreatedDate?: string;
  Tipo_de_Oportunidade__c?: string;
  Segmento_de_Cliente__c?: string;
  Solu_o__c?: string;
  Data_de_Previs_o_de_Fecho__c?: string;
  Data_de_Cria_o_da_Oportunidade__c?: string;
  // Add other fields fetched from Opportunity
}

// Define structure for the proposal data
interface ProposalData {
  Id: string;
  Name: string;
  Status__c?: string; // Assuming Status field API name
  Data_de_Cria_o_da_Proposta__c?: string; // Corrected field name
  // Add other relevant proposal fields
}

interface GetOppDetailsResult {
  success: boolean;
  data?: {
    opportunity: DetailedOpportunityData;
    proposals: ProposalData[];
  };
  error?: string;
  sessionExpired?: boolean;
  permissionDenied?: boolean; // Flag for authorization failure
}

// --- API Call Helper Function (Consider moving to a shared utils file) ---
// Duplicated from createSalesforceOpportunity for now, ideally refactor later
async function callSalesforceApi<T>(apiCall: () => Promise<T>): Promise<T> {
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
        if (error.name === 'invalid_grant' ||
            error.errorCode === 'INVALID_SESSION_ID' ||
            (error.errorCode && typeof error.errorCode === 'string' && error.errorCode.includes('INVALID_SESSION_ID')))
        {
            logger.warn('Detected invalid session ID or grant error.');
            throw new HttpsError('unauthenticated', 'Salesforce session expired or invalid.', { sessionExpired: true });
        } else if (error.errorCode === 'NOT_FOUND') {
             logger.warn('Salesforce API call resulted in Not Found.');
             throw new HttpsError('not-found', error.message || 'Salesforce record not found.');
        } else {
            const errorMessage = error.message || error.name || 'Unknown Salesforce API error';
            throw new HttpsError('internal', `Salesforce API call failed: ${errorMessage}`, {
                errorCode: error.errorCode,
                fields: error.fields
            });
        }
    }
}


// --- Cloud Function Definition ---

export const getSalesforceOpportunityDetails = onCall(
  {
    timeoutSeconds: 60,
    memory: "256MiB",
    // enforceAppCheck: true, // Recommended for production
  },
  async (request: CallableRequest<GetOppDetailsParams>): Promise<GetOppDetailsResult> => {
    logger.info("getSalesforceOpportunityDetails function triggered", { params: request.data });

    // 1. Authentication Check
    if (!request.auth) {
      logger.error("Authentication failed: User is not authenticated.");
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = request.auth.uid;
    logger.info("Authentication check passed.", { uid });

    // 2. Input Validation
    const { opportunityId, accessToken, instanceUrl } = request.data;
    if (!opportunityId) {
      logger.error("Validation failed: Missing opportunityId");
      throw new HttpsError("invalid-argument", "Missing opportunityId");
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

      // 4. Authorization Check
      let isAuthorized = false;
      let userRole: string | undefined;
      let userSalesforceId: string | undefined;

      try {
          const userDoc = await admin.firestore().collection('users').doc(uid).get();
          if (!userDoc.exists) {
              logger.error("Authorization failed: User document not found.", { uid });
              throw new HttpsError("permission-denied", "User data not found.");
          }
          const userData = userDoc.data();
          userRole = userData?.role;
          userSalesforceId = userData?.resellerSalesforceId; // Assumes this field exists

          if (userRole === 'admin') {
              isAuthorized = true;
              logger.info("User is admin, authorization granted.", { uid });
          } else if (userRole === 'reseller' && userSalesforceId) {
              logger.info("User is reseller, checking opportunity ownership...", { uid, userSalesforceId, opportunityId });
              // Fetch the specific opportunity to check ownership
              const oppOwnershipQuery = `SELECT Agente_Retail__c FROM Oportunidade__c WHERE Id = '${opportunityId}' LIMIT 1`;
              const ownershipResult = await callSalesforceApi<{ totalSize: number, records: { Agente_Retail__c: string }[] }>(async () =>
                  await conn.query(oppOwnershipQuery)
              );

              if (ownershipResult.totalSize > 0 && ownershipResult.records[0].Agente_Retail__c === userSalesforceId) {
                  isAuthorized = true;
                  logger.info("Reseller owns the opportunity, authorization granted.", { uid });
              } else {
                  logger.warn("Authorization DENIED: Reseller does not own opportunity or opportunity not found.", {
                      uid,
                      opportunityId,
                      ownerIdInSF: ownershipResult.records.length > 0 ? ownershipResult.records[0].Agente_Retail__c : 'N/A',
                  });
              }
          } else {
              logger.warn("Authorization DENIED: User is not admin and either not a reseller or missing resellerSalesforceId.", { uid, userRole });
          }
      } catch (authError) {
          logger.error("Error during authorization check:", { uid, error: authError });
          if (authError instanceof HttpsError) throw authError; // Rethrow HttpsErrors (e.g., from callSalesforceApi)
          throw new HttpsError("internal", "Failed to verify user permissions.");
      }

      if (!isAuthorized) {
          throw new HttpsError("permission-denied", "User does not have permission to view this opportunity.", { permissionDenied: true });
      }
      logger.info("Authorization check completed successfully.");

      // 5. Fetch Opportunity Details
      logger.info("Fetching opportunity details...", { opportunityId });
      // Construct the main SOQL query
      const opportunityFields = [
          'Id', 'Name', 'NIF__c', 'Fase__c', 'CreatedDate',
          'Tipo_de_Oportunidade__c', 'Segmento_de_Cliente__c', 'Solu_o__c',
          'Data_de_Previs_o_de_Fecho__c', 'Data_de_Cria_o_da_Oportunidade__c',
          'Entidade__c',             // <-- SELECT Account ID
          'Entidade__r.Name',        // Get Account Name via relationship
          'Agente_Retail__c',        // <-- SELECT Reseller SF ID
          'Agente_Retail__r.Name'     // Get Reseller Name via relationship
          // Add any other required fields from Oportunidade__c
      ].join(', ');

      const oppQuery = `SELECT ${opportunityFields} FROM Oportunidade__c WHERE Id = '${opportunityId}' LIMIT 1`;
      logger.debug("Opportunity Query:", { query: oppQuery });

      const oppResult = await callSalesforceApi<{ totalSize: number, records: any[] }>(async () => await conn.query(oppQuery));

      if (oppResult.totalSize === 0) {
          logger.error("Opportunity not found in Salesforce after authorization.", { opportunityId });
          throw new HttpsError("not-found", `Opportunity with ID ${opportunityId} not found.`);
      }

      const rawOpportunityData = oppResult.records[0];
      // Map raw data (including nested relationship fields) to our defined interface
      const opportunityData: DetailedOpportunityData = {
          Id: rawOpportunityData.Id,
          Name: rawOpportunityData.Name,
          AccountName: rawOpportunityData.Entidade__r?.Name, // Access nested field safely
          AccountId: rawOpportunityData.Entidade__c,        // <-- MAP Account ID
          ResellerName: rawOpportunityData.Agente_Retail__r?.Name, // Access nested field safely
          ResellerSalesforceId: rawOpportunityData.Agente_Retail__c, // <-- MAP Reseller SF ID
          NIF__c: rawOpportunityData.NIF__c,
          Fase__c: rawOpportunityData.Fase__c,
          CreatedDate: rawOpportunityData.CreatedDate,
          Tipo_de_Oportunidade__c: rawOpportunityData.Tipo_de_Oportunidade__c,
          Segmento_de_Cliente__c: rawOpportunityData.Segmento_de_Cliente__c,
          Solu_o__c: rawOpportunityData.Solu_o__c,
          Data_de_Previs_o_de_Fecho__c: rawOpportunityData.Data_de_Previs_o_de_Fecho__c,
          Data_de_Cria_o_da_Oportunidade__c: rawOpportunityData.Data_de_Cria_o_da_Oportunidade__c,
      };
      logger.info("Successfully fetched opportunity details.");
      logger.debug("Mapped Opportunity Data:", { data: opportunityData });

      // 6. Fetch Related Proposals
      logger.info("Fetching related proposals...", { opportunityId });
      const proposalFields = [
          'Id', 'Name', 'Status__c', 'Data_de_Cria_o_da_Proposta__c' // Removed Amount__c, Corrected Date field
          // Add any other required fields from Proposta__c
      ].join(', ');
      // Assuming 'Oportunidade__c' is the correct API name for the lookup field on Proposal
      // Order by the corrected date field name
      const proposalQuery = `SELECT ${proposalFields} FROM Proposta__c WHERE Oportunidade__c = '${opportunityId}' ORDER BY Data_de_Cria_o_da_Proposta__c DESC`;
      logger.debug("Proposal Query:", { query: proposalQuery });

      const proposalResult = await callSalesforceApi<{ totalSize: number, records: ProposalData[] }>(async () => await conn.query(proposalQuery));

      logger.info(`Found ${proposalResult.totalSize} related proposals.`);
      // Ensure the mapping here uses the correct field name if needed later
      const proposalsData: ProposalData[] = proposalResult.records;

      // 7. Return Combined Data
      logger.info("Returning success response with fetched data.");
      return {
          success: true,
          data: {
              opportunity: opportunityData,
              proposals: proposalsData,
          }
      };

    } catch (error) {
      logger.error("Error in getSalesforceOpportunityDetails main try block:", error);
      if (error instanceof HttpsError) {
        // If it's already an HttpsError (e.g., from callSalesforceApi or auth checks), rethrow it
        throw error;
      }
      // Wrap unexpected errors
      throw new HttpsError("internal", "An unexpected error occurred.", error);
    }
  }
); 