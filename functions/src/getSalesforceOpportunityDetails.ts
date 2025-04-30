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
  Id: string; // Original Salesforce ID (keep for reference/logging if needed)
  id: string; // Lowercase ID for Flutter model compatibility
  Name: string; // Original Salesforce Name
  name: string; // Lowercase Name for Flutter model compatibility
  // --- Use camelCase keys matching Flutter model expectations ---
  accountName?: string; // From Entidade__r.Name
  accountId?: string;   // From Entidade__c
  resellerName?: string; // From Agente_Retail__r.Name
  resellerSalesforceId?: string; // From Agente_Retail__c
  nifC?: string; // From NIF__c
  faseC?: string; // From Fase__c
  createdDate?: string; // From CreatedDate
  tipoDeOportunidadeC?: string; // From Tipo_de_Oportunidade__c
  segmentoDeClienteC?: string; // From Segmento_de_Cliente__c
  soluOC?: string; // From Solu_o__c
  dataDePrevisaoDeFechoC?: string; // From Data_de_Previs_o_de_Fecho__c
  dataDeCriacaoDaOportunidadeC?: string; // From Data_de_Cria_o_da_Oportunidade__c
  ownerName?: string; // From Owner.Name
  observacoes?: string; // From Observa_es__c
  motivoDaPerda?: string; // From Motivo_da_Perda__c
  qualificacaoConcluida?: boolean; // From Qualifica_o_conclu_da__c (currently commented out in query)
  redFlag?: string; // From Red_Flag_Oportunidade__c
  faseLDF?: string; // From Fase_LDF__c (currently commented out in query)
  ultimaListaCicloName?: string; // From ltima_Lista_de_Ciclo__r.Name (currently commented out in query)
  dataContacto?: string; // From Data_do_Contacto__c
  dataReuniao?: string; // From Data_da_Reuni_o__c
  dataProposta?: string; // From Data_da_Proposta__c
  dataFecho?: string; // From Data_do_Fecho__c (Actual close)
  dataUltimaAtualizacaoFase?: string; // From Data_da_ltima_actualiza_o_de_Fase__c
  backOffice?: string; // From Back_Office__c
  cicloDoGanhoName?: string; // From Ciclo_do_Ganho__r.Name
  // --- End camelCase keys ---
}

// Define structure for the proposal data
interface ProposalData {
  Id: string;
  Name: string;
  Status__c?: string; // Assuming Status field API name
  Data_de_Cria_o_da_Proposta__c?: string; // Corrected field name
  // Add other relevant proposal fields
}

// --- Added: Define structure for File Data ---
interface FileData {
  id: string; // ContentDocument Id
  contentVersionId: string; // The ID needed for download
  title: string;
  fileType: string;
  downloadUrl: string; // Keep for reference, might remove later if unused
}
// --- End File Data ---

interface GetOppDetailsResult {
  success: boolean;
  data?: {
    opportunityDetails: DetailedOpportunityData; // Renamed key
    proposals: ProposalData[];
    files: FileData[]; // Added files array
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
          'Entidade__c',             // Account ID
          'Entidade__r.Name',        // Account Name
          'Agente_Retail__c',        // Reseller SF ID
          'Agente_Retail__r.Name',   // Reseller Name
          // --- New fields added to query ---
          'OwnerId',                 // Needed for Owner.Name relationship
          'Owner.Name',
          'Observa_es__c',
          'Motivo_da_Perda__c',
          // 'Qualifica_o_conclu_da__c', // Commented out due to potential FLS/permission issue
          'Red_Flag_Oportunidade__c',
          // 'Fase_LDF__c', // Commented out due to potential FLS/permission issue
          // 'ltima_Lista_de_Ciclo__c', // Commented out due to potential FLS/permission issue
          // 'ltima_Lista_de_Ciclo__r.Name', // Commented out due to potential FLS/permission issue
          'Data_do_Contacto__c',
          'Data_da_Reuni_o__c',
          'Data_da_Proposta__c',
          'Data_do_Fecho__c',
          'Data_da_ltima_actualiza_o_de_Fase__c',
          'Back_Office__c',
          'Ciclo_do_Ganho__c',       // Needed for relationship name
          'Ciclo_do_Ganho__r.Name'
          // --- End new fields ---
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
      // Using consistent camelCase keys expected by Flutter's fromJson
      const opportunityData: DetailedOpportunityData = {
          Id: rawOpportunityData.Id, // Keep original Id (Uppercase) if needed for interface
          id: rawOpportunityData.Id, // Lowercase id for Flutter
          Name: rawOpportunityData.Name, // Keep original Name (Uppercase) if needed for interface
          name: rawOpportunityData.Name, // Lowercase name for Flutter
          // --- Map using camelCase keys expected by Flutter --- 
          accountName: rawOpportunityData.Entidade__r?.Name ?? null,
          accountId: rawOpportunityData.Entidade__c ?? null,
          resellerName: rawOpportunityData.Agente_Retail__r?.Name ?? null,
          resellerSalesforceId: rawOpportunityData.Agente_Retail__c ?? null,
          nifC: rawOpportunityData.NIF__c ?? null,
          faseC: rawOpportunityData.Fase__c ?? null,
          createdDate: rawOpportunityData.CreatedDate ?? null, // Assuming Flutter expects camelCase
          tipoDeOportunidadeC: rawOpportunityData.Tipo_de_Oportunidade__c ?? null,
          segmentoDeClienteC: rawOpportunityData.Segmento_de_Cliente__c ?? null,
          soluOC: rawOpportunityData.Solu_o__c ?? null,
          dataDePrevisaoDeFechoC: rawOpportunityData.Data_de_Previs_o_de_Fecho__c ?? null,
          dataDeCriacaoDaOportunidadeC: rawOpportunityData.Data_de_Cria_o_da_Oportunidade__c ?? null,
          ownerName: rawOpportunityData.Owner?.Name ?? null, // Already camelCase
          observacoes: rawOpportunityData.Observa_es__c ?? null,
          motivoDaPerda: rawOpportunityData.Motivo_da_Perda__c ?? null,
          // qualificacaoConcluida: rawOpportunityData.Qualifica_o_conclu_da__c ?? false, // Commented out
          redFlag: rawOpportunityData.Red_Flag_Oportunidade__c ?? null,
          // faseLDF: rawOpportunityData.Fase_LDF__c ?? null, // Commented out
          // ultimaListaCicloName: rawOpportunityData.ltima_Lista_de_Ciclo__r?.Name ?? null, // Commented out
          dataContacto: rawOpportunityData.Data_do_Contacto__c ?? null,
          dataReuniao: rawOpportunityData.Data_da_Reuni_o__c ?? null,
          dataProposta: rawOpportunityData.Data_da_Proposta__c ?? null,
          dataFecho: rawOpportunityData.Data_do_Fecho__c ?? null, // Actual close date
          dataUltimaAtualizacaoFase: rawOpportunityData.Data_da_ltima_actualiza_o_de_Fase__c ?? null,
          backOffice: rawOpportunityData.Back_Office__c ?? null,
          cicloDoGanhoName: rawOpportunityData.Ciclo_do_Ganho__r?.Name ?? null, // Already camelCase
          // --- End camelCase mapping ---
      };
      logger.info("Successfully fetched opportunity details.");
      logger.debug("Mapped Opportunity Data:", { data: opportunityData }); // Log the final mapped object

      // --- Fetch Related Files ---
      logger.info("Fetching related files...", { opportunityId });
      let filesData: FileData[] = [];
      try {
          // Step 1: Get ContentDocumentLink records to find associated ContentDocument IDs
          const fileLinksQuery = `SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = '${opportunityId}'`;
          const fileLinksResult = await callSalesforceApi<{ totalSize: number, records: { ContentDocumentId: string }[] }>(
              async () => await conn.query(fileLinksQuery)
          );
          logger.debug("File Links Result:", { count: fileLinksResult.totalSize });

          if (fileLinksResult.records.length > 0) {
              const docIds = fileLinksResult.records.map(link => `'${link.ContentDocumentId}'`).join(',');
              logger.debug("Querying ContentDocuments for LatestVersionIds:", { docIds });

              // Step 2: Get the LATEST ContentVersion ID for each ContentDocument
              // We only need the ID of the *latest* version to download
              const latestVersionQuery = `
                  SELECT Id, LatestPublishedVersionId, Title, FileType
                  FROM ContentDocument
                  WHERE Id IN (${docIds}) AND IsArchived = false AND LatestPublishedVersionId != null
              `;
              const contentDocsResult = await callSalesforceApi<{ totalSize: number, records: { Id: string, LatestPublishedVersionId: string, Title: string, FileType: string }[] }>(
                  async () => await conn.query(latestVersionQuery)
              );
              logger.debug("ContentDocuments Query Result:", { count: contentDocsResult.totalSize });

              // Map ContentDocument data and construct download URLs
              filesData = contentDocsResult.records
                  .map(doc => {
                      if (!doc.LatestPublishedVersionId) {
                          logger.warn(`Missing LatestPublishedVersionId for ContentDocument Id: ${doc.Id}, Title: ${doc.Title}. Skipping file.`);
                          return null; // Skip if no latest version ID
                      }
                      // Step 3: Construct the download URL using the ContentVersion ID
                      // Format: /services/data/v<API_VERSION>/sobjects/ContentVersion/<VersionId>/VersionData
                      // Using conn.version gives the API version used by jsforce connection
                      // This URL is now primarily for reference, the proxy function is preferred for download
                      const downloadUrl = `${conn.instanceUrl}/services/data/v${conn.version}/sobjects/ContentVersion/${doc.LatestPublishedVersionId}/VersionData`;
                      return {
                          id: doc.Id, // Using ContentDocument Id as the main identifier
                          contentVersionId: doc.LatestPublishedVersionId, // The ID needed for download
                          title: doc.Title,
                          fileType: doc.FileType,
                          downloadUrl: downloadUrl, // Keep for reference
                      };
                  })
                  .filter((file): file is FileData => file !== null); // Filter out nulls

              logger.info(`Successfully processed ${filesData.length} related files for Opportunity ${opportunityId}`);
          } else {
               logger.info(`No related files found for Opportunity ${opportunityId}`);
          }
      } catch (fileError: any) {
          logger.error(`Error fetching files for Opportunity ${opportunityId}:`, fileError);
          // Logged error, returning empty list for files as fallback
          filesData = [];
      }
      // --- End Fetch Related Files ---

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

      // --- Added Debug Log ---
      logger.debug("Final mapped data being returned:", {
          opportunityId: opportunityData.Id, // Log the Id from original record
          mappedIdKeyExists: opportunityData.hasOwnProperty('id'), // Check if lowercase 'id' key exists
          mappedIdValue: opportunityData.id, // Log the mapped lowercase 'id' value
          mappedNameKeyExists: opportunityData.hasOwnProperty('name'), // Check if lowercase 'name' key exists
          mappedNameValue: opportunityData.name, // Log the mapped lowercase 'name' value
          // Optionally log other key fields
      });
      // --- End Debug Log ---

      // 7. Return Combined Data
      logger.info("Returning success response with fetched data.");
      return {
          success: true,
          data: {
              opportunityDetails: opportunityData, // Renamed key
              files: filesData,             // Added files array
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