import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as jsforce from "jsforce";
import axios from "axios"; // For downloading files from URLs

// Initialize Firebase Admin SDK (if not already done in index.ts)
try {
  if (admin.apps.length === 0) {
    admin.initializeApp();
    logger.info("Firebase Admin SDK initialized in createSalesforceProposal.");
  }
} catch (e) {
  logger.info("Firebase Admin SDK already initialized.");
}

// --- Interfaces ---

interface CpeItemData {
  cpe: string;
  nif: string;
  consumo: string; // String from Flutter, needs parsing
  fidelizacao: string; // String (years) from Flutter, needs parsing
  cicloId: string; // Salesforce ID
  comissao: string; // String from Flutter, needs parsing
  fileUrls: string[]; // Array of Firebase Storage download URLs
}

interface CreateProposalParams {
  // Salesforce Credentials
  accessToken: string;
  instanceUrl: string;

  // Linking IDs
  salesforceOpportunityId: string;
  salesforceAccountId: string;
  resellerSalesforceId: string; // This is the SF USER ID of the Reseller Agent

  // Proposal Fields
  proposalName: string;
  solution: string;
  energiaChecked: boolean;
  validityDate: string; // Expects 'YYYY-MM-DD'
  bundle: string | null;
  solarChecked: boolean;
  solarInvestment: string | null; // String value, needs parsing
  mainNif: string;
  responsavelNegocio: string | null;

  // CPE Items
  cpeItems: CpeItemData[];
}

interface CreateProposalResult {
  success: boolean;
  proposalId?: string;
  error?: string;
  sessionExpired?: boolean;
}

// --- Cloud Function Definition ---

export const createSalesforceProposal = onCall(
  {
    timeoutSeconds: 540, // Longer timeout for potential multiple file uploads
    memory: "1GiB",    // More memory for file processing
    region: "us-central1", // Specify region consistently
    // enforceAppCheck: true, // Recommended for production
  },
  async (request: CallableRequest<CreateProposalParams>): Promise<CreateProposalResult> => {
    logger.info("createSalesforceProposal function triggered");

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

    // 2. Input Validation (Basic)
    const data = request.data;
    // Add checks for essential fields like IDs, proposalName, cpeItems array etc.
    if (!data.accessToken || !data.instanceUrl || !data.salesforceOpportunityId ||
        !data.salesforceAccountId || !data.resellerSalesforceId || !data.proposalName ||
        !data.solution || !data.validityDate || !data.mainNif || !data.cpeItems || data.cpeItems.length === 0)
    {
        logger.error("Validation failed: Missing required fields", { receivedKeys: Object.keys(data) });
        throw new HttpsError("invalid-argument", "Missing required proposal data.");
    }
    // TODO: Add more specific validation for cpeItems content if needed
    logger.info("Input validation passed.");

    // 3. Salesforce Connection
    let conn: jsforce.Connection;
    try {
      conn = new jsforce.Connection({
        instanceUrl: data.instanceUrl,
        accessToken: data.accessToken,
      });
      logger.info("Salesforce connection initialized.");
      // Optional: Verify connection with a simple query like conn.identity()
    } catch (connError: any) {
        logger.error("Failed to initialize Salesforce connection:", connError);
        // This typically wouldn't fail unless inputs are malformed, already caught above.
        throw new HttpsError("internal", "Failed to establish Salesforce connection.");
    }

    let proposalId: string | undefined = undefined;

    try {
        // --- E. Create Proposta__c Record ---
        logger.info("Attempting to create Proposta__c record...");
        const currentDate = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
        let solarInvestmentValue: number | null = null;
        if(data.solarChecked && data.solarInvestment) {
            solarInvestmentValue = parseFloat(data.solarInvestment.replace('€', '').trim());
            if (isNaN(solarInvestmentValue)) {
                logger.warn('Could not parse solar investment value:', data.solarInvestment);
                solarInvestmentValue = null;
            }
        }

        const proposalPayload = {
            Name: data.proposalName,
            Entidade__c: data.salesforceAccountId,
            Oportunidade__c: data.salesforceOpportunityId,
            NIF__c: data.mainNif,
            Agente_Retail__c: data.resellerSalesforceId, // <-- Use Reseller User ID from input
            Solu_o__c: data.solution,
            Energia__c: data.energiaChecked,
            Data_de_Validade__c: data.validityDate,
            Data_de_Cria_o_da_Proposta__c: currentDate,
            Status__c: 'Enviada', // NEW - Requested Value
            // Optional fields:
            Bundle__c: data.bundle, // Assuming SF field name
            Solar__c: data.solarChecked, // Assuming SF field name
            Valor_de_Investimento_Solar__c: solarInvestmentValue, // NEW - Correct Field Name
            Respons_vel_de_Neg_cio_Retail__c: data.responsavelNegocio, // NEW - Correct Field Name
        };
        logger.debug("Proposta__c Payload:", { payload: proposalPayload });

        const proposalResult = await callSalesforceApi<{ id?: string; success?: boolean; errors?: any[] }>(() =>
            conn.sobject('Proposta__c').create(proposalPayload)
        );

        if (!proposalResult.success || !proposalResult.id) {
            logger.error("Failed to create Proposta__c.", { result: proposalResult });
            throw new HttpsError("internal", "Failed to create Proposal in Salesforce.", { details: proposalResult.errors });
        }
        proposalId = proposalResult.id;
        logger.info(`Successfully created Proposta__c. ID: ${proposalId}`);

        // --- F. Process CPE Items (Loop) ---
        logger.info(`Processing ${data.cpeItems.length} CPE items...`);
        const allCpeIds: string[] = []; // Keep track of created CPE Ids if needed

        for (const [index, cpeItem] of data.cpeItems.entries()) {
            logger.info(`Processing CPE Item #${index + 1}: ${cpeItem.cpe}`);

            // F.0 Data Transformation for this CPE
            let consumoDecimal: number;
            let consumoIntegerRoundedUp: number;
            let fidelizacaoAnos: number;
            let comissaoDecimal: number;

            try {
                consumoDecimal = parseFloat(cpeItem.consumo.replace(',', '.').trim());
                if (isNaN(consumoDecimal)) throw new Error('Invalid consumo value');
                consumoIntegerRoundedUp = Math.ceil(consumoDecimal);

                fidelizacaoAnos = parseInt(cpeItem.fidelizacao.trim(), 10);
                if (isNaN(fidelizacaoAnos)) throw new Error('Invalid fidelizacao value');

                comissaoDecimal = parseFloat(cpeItem.comissao.replace('€', '').replace(',', '.').trim());
                 if (isNaN(comissaoDecimal)) throw new Error('Invalid comissao value');

            } catch (parseError: any) {
                logger.error(`Failed to parse data for CPE ${cpeItem.cpe}: ${parseError.message}`);
                throw new HttpsError("invalid-argument", `Invalid numeric data for CPE ${cpeItem.cpe}: ${parseError.message}`);
            }

            // --- START: Find or Create CPE__c Record ---
            let cpeRecordId: string | null = null;
            try {
                logger.info(`Querying for existing CPE__c with Name = ${cpeItem.cpe}`);
                const existingCpeQuery = await callSalesforceApi<jsforce.QueryResult<{ Id: string }>>(async () =>
                   conn.query(`SELECT Id FROM CPE__c WHERE Name = '${cpeItem.cpe}' LIMIT 1`)
                );

                if (existingCpeQuery.totalSize > 0 && existingCpeQuery.records[0].Id) {
                    cpeRecordId = existingCpeQuery.records[0].Id;
                    logger.info(`Found existing CPE__c record. ID: ${cpeRecordId}`);
                } else {
                    logger.info(`No existing CPE__c found. Creating new CPE__c for ${cpeItem.cpe}...`);
                    const cpeCreatePayload = {
                Name: cpeItem.cpe,
                Entidade__c: data.salesforceAccountId,
                NIF__c: cpeItem.nif,
                Consumo_anual_esperado_KWh__c: consumoIntegerRoundedUp,
                        Solu_o__c: data.solution, // Set on CPE as well
                        Fideliza_o_Anos__c: fidelizacaoAnos, // Set on CPE as well
                        // Add other required fields for CPE__c here if necessary and available
                    };
                    logger.debug("New CPE__c Payload:", { payload: cpeCreatePayload });

                    const cpeCreateResult = await callSalesforceApi<{ id?: string; success?: boolean; errors?: any[] }>(() =>
                       conn.sobject('CPE__c').create(cpeCreatePayload)
                    );

                    if (!cpeCreateResult.success || !cpeCreateResult.id) {
                        logger.error(`Failed to create new CPE__c for ${cpeItem.cpe}.`, { result: cpeCreateResult });
                        throw new HttpsError("internal", `Failed to create CPE ${cpeItem.cpe} in Salesforce.`, { details: cpeCreateResult.errors });
                    }
                    cpeRecordId = cpeCreateResult.id;
                    logger.info(`Successfully created new CPE__c. ID: ${cpeRecordId}`);
                }
            } catch (cpeFindOrCreateError: any) {
                logger.error(`Error finding or creating CPE__c for ${cpeItem.cpe}:`, { error: cpeFindOrCreateError.message || cpeFindOrCreateError });
                // Rethrow if it's an HttpsError (like session expiry), otherwise wrap it
                if (cpeFindOrCreateError instanceof HttpsError) throw cpeFindOrCreateError;
                throw new HttpsError("internal", `Failed to process CPE ${cpeItem.cpe}.`, { detail: cpeFindOrCreateError.message });
            }

            if (!cpeRecordId) { // Should not happen if logic above is correct, but safety check
                 logger.error(`Failed to obtain CPE__c ID for ${cpeItem.cpe}. Skipping this item.`);
                 continue; // Skip to the next cpeItem
            }
            // --- END: Find or Create CPE__c Record ---

            // --- F.1 Create CPE_Proposta__c Record ---
            const cpePropostaPayload = {
                CPE_Proposta__c: cpeRecordId,        // CORRECT API Name for Lookup to CPE__c
                Proposta_CPE__c: proposalId,        // CORRECT API Name for Lookup to Proposta__c
                Ciclo_de_Activa_o__c: cpeItem.cicloId, // Field specific to proposal context
                Comiss_o_Retail__c: comissaoDecimal,         // Field specific to proposal context
                Consumo_ou_Pot_ncia_Pico__c: consumoDecimal, // Field specific to proposal context
                Fideliza_o_Anos__c: fidelizacaoAnos,         // Field specific to proposal context
                Agente_Retail__c: data.resellerSalesforceId, // Field specific to proposal context
                // Solu_o__c: data.solution,             // REMOVED - This field belongs on CPE__c, not CPE_Proposta__c
                // Add other fields from CPE_Proposta__c object if needed
            };
            // Log the payload BEFORE sending it to Salesforce
            logger.debug(`CPE_Proposta__c Payload #${index + 1}:`, { payload: cpePropostaPayload });

            // Create the CPE_Proposta__c junction record
            const cpePropostaResult = await callSalesforceApi<{ id?: string; success?: boolean; errors?: any[] }>(() =>
                conn.sobject('CPE_Proposta__c').create(cpePropostaPayload)
            );

            if (!cpePropostaResult.success || !cpePropostaResult.id) {
                logger.error(`Failed to create CPE_Proposta__c for CPE ${cpeItem.cpe}.`, { result: cpePropostaResult });
                // Decide: stop processing or skip this CPE? Let's throw for now.
                throw new HttpsError("internal", `Failed to create CPE-Proposal link for ${cpeItem.cpe}.`, { details: cpePropostaResult.errors });
            }
            const cpePropostaId = cpePropostaResult.id;
            allCpeIds.push(cpePropostaId);
            logger.info(`Successfully created CPE_Proposta__c for ${cpeItem.cpe}. ID: ${cpePropostaId}`);

            // --- START: File Processing for THIS CPE_Proposta__c ---
            if (cpeItem.fileUrls && cpeItem.fileUrls.length > 0) {
                logger.info(`Processing ${cpeItem.fileUrls.length} files for CPE ${cpeItem.cpe}...`);
                for (const fileUrl of cpeItem.fileUrls) {
                    try {
                        logger.info(`Downloading file for CPE ${cpeItem.cpe} from: ${fileUrl}`);
                        const response = await axios.get(fileUrl, { responseType: 'arraybuffer' });
                        const fileContentBase64 = Buffer.from(response.data, 'binary').toString('base64');
                        const fileName = fileUrl.split('/').pop()?.split('?')[0] ?? `file_${Date.now()}`; // Extract filename
                        const mimeType = response.headers['content-type'] || 'application/octet-stream'; // Get MIME type

                        logger.info(`Uploading file "${fileName}" (${mimeType}) to Salesforce ContentVersion...`);

                        // Create ContentVersion
                        const contentVersionResult = await callSalesforceApi<{ id?: string; success?: boolean; errors?: any[] }>(() =>
                            conn.sobject('ContentVersion').create({
                                Title: fileName,
                                PathOnClient: fileName,
                                VersionData: fileContentBase64,
                                Origin: 'H', // 'H' for Chatter File, 'C' for Content Document
                                // FirstPublishLocationId: cpePropostaId, // Link on creation (Alternative)
                            })
                        );

                        if (!contentVersionResult.success || !contentVersionResult.id) {
                           logger.error(`Failed to create ContentVersion for file "${fileName}" for CPE ${cpeItem.cpe}.`, { result: contentVersionResult });
                           // Log error and continue with next file/CPE?
                           continue; // Skip linking this file
                        }
                        const contentVersionId = contentVersionResult.id;
                        logger.info(`Successfully created ContentVersion for "${fileName}". ID: ${contentVersionId}`);

                        // Query ContentDocumentId
                        const contentVersion = await callSalesforceApi<jsforce.QueryResult<{ ContentDocumentId: string }>>(async () => {
                           return conn.query(`SELECT ContentDocumentId FROM ContentVersion WHERE Id = '${contentVersionId}'`);
                        });

                        if (!contentVersion.records || contentVersion.records.length === 0 || !contentVersion.records[0].ContentDocumentId) {
                           logger.error(`Failed to retrieve ContentDocumentId for ContentVersion ${contentVersionId}.`);
                           // Log error and continue?
                           continue; // Skip linking this file
                        }
                        const contentDocumentId = contentVersion.records[0].ContentDocumentId;
                        logger.info(`Retrieved ContentDocumentId: ${contentDocumentId}`);

                        // Create ContentDocumentLink to link the file to the CPE_Proposta__c
                        const contentLinkResult = await callSalesforceApi<{ id?: string; success?: boolean; errors?: any[] }>(() =>
                           conn.sobject('ContentDocumentLink').create({
                               ContentDocumentId: contentDocumentId,
                               LinkedEntityId: cpePropostaId, // <-- LINK TO THE CPE_Proposta__c ID
                               ShareType: 'V', // 'V' = Viewer, 'C' = Collaborator, 'I' = Inferred
                               Visibility: 'AllUsers', // Or 'InternalUsers'
                           })
                        );

                         if (!contentLinkResult.success || !contentLinkResult.id) {
                            logger.error(`Failed to create ContentDocumentLink for Doc ${contentDocumentId} to CPE ${cpePropostaId}.`, { result: contentLinkResult });
                            // Log error and continue?
                            continue; // Skip linking this file
                        }
                        logger.info(`Successfully created ContentDocumentLink for Doc ${contentDocumentId} to CPE ${cpePropostaId}. Link ID: ${contentLinkResult.id}`);

                    } catch (fileError: any) {
                         logger.error(`Error processing file ${fileUrl} for CPE ${cpeItem.cpe}:`, { error: fileError.message || fileError });
                         // Log error and continue with the next file?
                         // Consider if one file failure should stop the whole CPE processing.
                    }
                } // End loop through files for this CPE
            } else {
                 logger.info(`No files provided for CPE ${cpeItem.cpe}.`);
            }
            // --- END: File Processing for THIS CPE_Proposta__c ---

        } // End loop through cpeItems

        // --- G. REMOVED OLD File Processing Block ---
        // The block that iterated through all fileUrls and linked to proposalId is deleted.

        // --- H. Return Success ---
        logger.info(`Successfully created proposal ${proposalId} and processed ${data.cpeItems.length} CPE items.`);
        return { success: true, proposalId: proposalId };

    } catch (error: any) {
        // ... (existing error handling) ...
        logger.error("Error during Salesforce operation:", { errorMessage: error.message, errorCode: error.errorCode, fields: error.fields });

        // Check for specific Salesforce session expiry error
        if (error.errorCode === 'INVALID_SESSION_ID' || error.message?.includes('Session expired or invalid')) {
            logger.warn("Salesforce session expired or invalid.");
            // Attempt to delete partially created proposal if ID exists? (Complex rollback)
            return { success: false, error: "Salesforce session expired. Please log in again.", sessionExpired: true };
        }

        // Check for HttpsError from validation, auth, or sub-calls
      if (error instanceof HttpsError) {
            logger.error("Caught HttpsError:", { code: error.code, message: error.message, details: error.details });
            // Rethrow HttpsError to be handled by the Functions framework
             throw error;
        }

        // Generic internal error for other Salesforce or unexpected issues
        logger.error("Caught unexpected error:", error);
        throw new HttpsError("internal", "An internal error occurred while creating the proposal.", { detail: error.message });

    }
  }
);


// --- Helper function to call Salesforce API with error handling ---
// Ensure this helper handles session expiry correctly if needed by specific calls
async function callSalesforceApi<T>(
    apiCall: () => Promise<T>,
    checkSessionExpiry = true // Added flag to control session expiry check
): Promise<T> {
    try {
        return await apiCall();
    } catch (error: any) {
        logger.error("Salesforce API call failed:", { errorMessage: error.message, errorCode: error.errorCode });
        // Check for session expiry if requested
         if (checkSessionExpiry && (error.errorCode === 'INVALID_SESSION_ID' || error.message?.includes('Session expired or invalid'))) {
             logger.warn("Session expired detected in callSalesforceApi helper.");
            // Rethrow the specific error to be handled by the main function logic
            throw error;
        }
        // Rethrow other errors to be handled by the main function's catch block
        throw error;
    }
} 