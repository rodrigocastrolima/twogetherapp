import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as jsforce from "jsforce";

// Initialize Firebase Admin SDK (if not already done in index.ts)
try {
  if (admin.apps.length === 0) {
    admin.initializeApp();
    logger.info("Firebase Admin SDK initialized in createCpeForProposal.");
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
  files: Array<{
    fileName: string;
    fileContentBase64: string;
  }>; // Base64 encoded files from Flutter
}

interface CreateCpeForProposalParams {
  // Salesforce Credentials
  accessToken: string;
  instanceUrl: string;

  // Existing Proposal Context
  proposalId: string;
  accountId: string; // From the existing proposal
  resellerSalesforceId: string; // From the existing proposal

  // CPE Data
  cpeItems: CpeItemData[];
}

interface CreateCpeForProposalResult {
  success: boolean;
  createdCpePropostaIds?: string[];
  error?: string;
  sessionExpired?: boolean;
}

// --- Cloud Function Definition ---

export const createCpeForProposal = onCall(
  {
    timeoutSeconds: 540, // Longer timeout for potential multiple file uploads
    memory: "1GiB",    // More memory for file processing
    region: "us-central1", // Specify region consistently
  },
  async (request: CallableRequest<CreateCpeForProposalParams>): Promise<CreateCpeForProposalResult> => {
    logger.info("createCpeForProposal function triggered");

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
    if (!data.accessToken || !data.instanceUrl || !data.proposalId ||
        !data.accountId || !data.resellerSalesforceId || !data.cpeItems || data.cpeItems.length === 0)
    {
        logger.error("Validation failed: Missing required fields", { receivedKeys: Object.keys(data) });
        throw new HttpsError("invalid-argument", "Missing required CPE data.");
    }
    logger.info("Input validation passed.");

    // 3. Salesforce Connection
    let conn: jsforce.Connection;
    try {
      conn = new jsforce.Connection({
        instanceUrl: data.instanceUrl,
        accessToken: data.accessToken,
      });
      logger.info("Salesforce connection initialized.");
    } catch (connError: any) {
        logger.error("Failed to initialize Salesforce connection:", connError);
        throw new HttpsError("internal", "Failed to establish Salesforce connection.");
    }

    // 4. Verify proposal exists
    try {
      const proposalResult = await conn.sobject('Proposta__c').findOne({ Id: data.proposalId }, ['Id', 'Name']);
      if (!proposalResult) {
        logger.error("Proposal not found in Salesforce.", { proposalId: data.proposalId });
        throw new HttpsError("not-found", `Proposal with ID ${data.proposalId} not found.`);
      }
      logger.info("Proposal verified:", { proposalId: data.proposalId, proposalName: proposalResult.Name });
    } catch (error: any) {
      if (error instanceof HttpsError) throw error;
      logger.error("Error verifying proposal:", error);
      throw new HttpsError("internal", "Failed to verify proposal exists.");
    }

    const createdCpePropostaIds: string[] = [];

    try {
        // --- Process CPE Items (Loop) ---
        logger.info(`Processing ${data.cpeItems.length} CPE items for proposal ${data.proposalId}...`);

        for (const [index, cpeItem] of data.cpeItems.entries()) {
            logger.info(`Processing CPE Item #${index + 1}: ${cpeItem.cpe}`);

            // Data Transformation for this CPE
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

            // --- Find or Create CPE__c Record ---
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
                        Entidade__c: data.accountId,
                        NIF__c: cpeItem.nif,
                        Consumo_anual_esperado_KWh__c: consumoIntegerRoundedUp,
                        Fideliza_o_Anos__c: fidelizacaoAnos,
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
                if (cpeFindOrCreateError instanceof HttpsError) throw cpeFindOrCreateError;
                throw new HttpsError("internal", `Failed to process CPE ${cpeItem.cpe}.`, { detail: cpeFindOrCreateError.message });
            }

            if (!cpeRecordId) {
                 logger.error(`Failed to obtain CPE__c ID for ${cpeItem.cpe}. Skipping this item.`);
                 continue;
            }

            // --- Create CPE_Proposta__c Record ---
            const cpePropostaPayload = {
                CPE_Proposta__c: cpeRecordId,        // Lookup to CPE__c
                Proposta_CPE__c: data.proposalId,   // Lookup to Proposta__c
                Ciclo_de_Activa_o__c: cpeItem.cicloId,
                Comiss_o_Retail__c: comissaoDecimal,
                Consumo_ou_Pot_ncia_Pico__c: consumoDecimal,
                Fideliza_o_Anos__c: fidelizacaoAnos,
                Agente_Retail__c: data.resellerSalesforceId,
            };
            logger.debug(`CPE_Proposta__c Payload #${index + 1}:`, { payload: cpePropostaPayload });

            const cpePropostaResult = await callSalesforceApi<{ id?: string; success?: boolean; errors?: any[] }>(() =>
                conn.sobject('CPE_Proposta__c').create(cpePropostaPayload)
            );

            if (!cpePropostaResult.success || !cpePropostaResult.id) {
                logger.error(`Failed to create CPE_Proposta__c for CPE ${cpeItem.cpe}.`, { result: cpePropostaResult });
                throw new HttpsError("internal", `Failed to create CPE-Proposal link for ${cpeItem.cpe}.`, { details: cpePropostaResult.errors });
            }
            const cpePropostaId = cpePropostaResult.id;
            createdCpePropostaIds.push(cpePropostaId);
            logger.info(`Successfully created CPE_Proposta__c for ${cpeItem.cpe}. ID: ${cpePropostaId}`);

            // --- File Processing for THIS CPE_Proposta__c ---
            if (cpeItem.files && cpeItem.files.length > 0) {
                logger.info(`Processing ${cpeItem.files.length} files for CPE ${cpeItem.cpe}...`);
                for (const fileData of cpeItem.files) {
                    try {
                        logger.info(`Uploading file "${fileData.fileName}" to Salesforce ContentVersion...`);

                        // Create ContentVersion
                        const contentVersionResult = await callSalesforceApi<{ id?: string; success?: boolean; errors?: any[] }>(() =>
                            conn.sobject('ContentVersion').create({
                                Title: fileData.fileName,
                                PathOnClient: fileData.fileName,
                                VersionData: fileData.fileContentBase64,
                                Origin: 'H', // 'H' for Chatter File
                            })
                        );

                        if (!contentVersionResult.success || !contentVersionResult.id) {
                           logger.error(`Failed to create ContentVersion for file "${fileData.fileName}" for CPE ${cpeItem.cpe}.`, { result: contentVersionResult });
                           continue; // Skip linking this file
                        }
                        const contentVersionId = contentVersionResult.id;
                        logger.info(`Successfully created ContentVersion for "${fileData.fileName}". ID: ${contentVersionId}`);

                        // Query ContentDocumentId
                        const contentVersion = await callSalesforceApi<jsforce.QueryResult<{ ContentDocumentId: string }>>(async () => {
                           return conn.query(`SELECT ContentDocumentId FROM ContentVersion WHERE Id = '${contentVersionId}'`);
                        });

                        if (!contentVersion.records || contentVersion.records.length === 0 || !contentVersion.records[0].ContentDocumentId) {
                           logger.error(`Failed to retrieve ContentDocumentId for ContentVersion ${contentVersionId}.`);
                           continue; // Skip linking this file
                        }
                        const contentDocumentId = contentVersion.records[0].ContentDocumentId;
                        logger.info(`Retrieved ContentDocumentId: ${contentDocumentId}`);

                        // Create ContentDocumentLink to link the file to the CPE_Proposta__c
                        const contentLinkResult = await callSalesforceApi<{ id?: string; success?: boolean; errors?: any[] }>(() =>
                           conn.sobject('ContentDocumentLink').create({
                               ContentDocumentId: contentDocumentId,
                               LinkedEntityId: cpePropostaId, // Link to the CPE_Proposta__c
                               ShareType: 'V', // 'V' = Viewer
                               Visibility: 'AllUsers',
                           })
                        );

                         if (!contentLinkResult.success || !contentLinkResult.id) {
                            logger.error(`Failed to create ContentDocumentLink for Doc ${contentDocumentId} to CPE ${cpePropostaId}.`, { result: contentLinkResult });
                            continue; // Skip linking this file
                        }
                        logger.info(`Successfully created ContentDocumentLink for Doc ${contentDocumentId} to CPE ${cpePropostaId}. Link ID: ${contentLinkResult.id}`);

                    } catch (fileError: any) {
                         logger.error(`Error processing file ${fileData.fileName} for CPE ${cpeItem.cpe}:`, { error: fileError.message || fileError });
                         // Continue with next file
                    }
                } // End loop through files for this CPE
            } else {
                 logger.info(`No files provided for CPE ${cpeItem.cpe}.`);
            }

        } // End loop through cpeItems

        // --- Return Success ---
        logger.info(`Successfully processed ${data.cpeItems.length} CPE items for proposal ${data.proposalId}. Created CPE-Proposta IDs: ${createdCpePropostaIds.join(', ')}`);
        return { success: true, createdCpePropostaIds: createdCpePropostaIds };

    } catch (error: any) {
        logger.error("Error during Salesforce operation:", { errorMessage: error.message, errorCode: error.errorCode, fields: error.fields });

        // Check for specific Salesforce session expiry error
        if (error.errorCode === 'INVALID_SESSION_ID' || error.message?.includes('Session expired or invalid')) {
            logger.warn("Salesforce session expired or invalid.");
            return { success: false, error: "Salesforce session expired. Please log in again.", sessionExpired: true };
        }

        // Check for HttpsError from validation, auth, or sub-calls
        if (error instanceof HttpsError) {
            logger.error("Caught HttpsError:", { code: error.code, message: error.message, details: error.details });
            throw error;
        }

        // Generic internal error for other Salesforce or unexpected issues
        logger.error("Caught unexpected error:", error);
        throw new HttpsError("internal", "An internal error occurred while creating CPEs for the proposal.", { detail: error.message });
    }
  }
);

// --- Helper function to call Salesforce API with error handling ---
async function callSalesforceApi<T>(
    apiCall: () => Promise<T>,
    checkSessionExpiry = true
): Promise<T> {
    try {
        return await apiCall();
    } catch (error: any) {
        logger.error("Salesforce API call failed:", { errorMessage: error.message, errorCode: error.errorCode });
        if (checkSessionExpiry && (error.errorCode === 'INVALID_SESSION_ID' || error.message?.includes('Session expired or invalid'))) {
             logger.warn("Session expired detected in callSalesforceApi helper.");
            throw error;
        }
        throw error;
    }
} 