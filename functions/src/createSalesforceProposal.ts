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

            // F.1 Create CPE__c Record
            const cpePayload = {
                Name: cpeItem.cpe,
                Entidade__c: data.salesforceAccountId,
                NIF__c: cpeItem.nif,
                Consumo_anual_esperado_KWh__c: consumoIntegerRoundedUp,
                Solu_o__c: data.solution, // Assuming same solution
                Fideliza_o_Anos__c: fidelizacaoAnos,
                Proposta__c: proposalId,
            };
            logger.debug(`CPE__c Payload for item ${index + 1}:`, { payload: cpePayload });

            const cpeResult = await callSalesforceApi<{ id?: string; success?: boolean; errors?: any[] }>(() =>
                conn.sobject('CPE__c').create(cpePayload)
            );

            if (!cpeResult.success || !cpeResult.id) {
                logger.error(`Failed to create CPE__c for item ${index + 1}.`, { result: cpeResult });
                throw new HttpsError("internal", `Failed to create CPE ${cpeItem.cpe} in Salesforce.`, { details: cpeResult.errors });
            }
            const cpeRecordId = cpeResult.id;
            logger.info(`Successfully created CPE__c for item ${index + 1}. ID: ${cpeRecordId}`);

            // F.2 Create CPE_Proposta__c Record
            const cpePropostaPayload = {
                CPE_Proposta__c: cpeRecordId,
                Proposta_CPE__c: proposalId,
                Agente_Retail__c: data.resellerSalesforceId, // <-- Use Reseller User ID from input
                Consumo_ou_Pot_ncia_Pico__c: consumoDecimal,
                Fideliza_o_Anos__c: fidelizacaoAnos,
                Ciclo_de_Activa_o__c: cpeItem.cicloId,
                Comiss_o_Retail__c: comissaoDecimal,
                Status__c: 'Activo', // NEW - Requested Value
            };
            logger.debug(`CPE_Proposta__c Payload for item ${index + 1}:`, { payload: cpePropostaPayload });

            const cpePropostaResult = await callSalesforceApi<{ id?: string; success?: boolean; errors?: any[] }>(() =>
                conn.sobject('CPE_Proposta__c').create(cpePropostaPayload)
            );

            if (!cpePropostaResult.success || !cpePropostaResult.id) {
                 logger.error(`Failed to create CPE_Proposta__c for item ${index + 1}.`, { result: cpePropostaResult });
                throw new HttpsError("internal", `Failed to create CPE-Proposal link for ${cpeItem.cpe}.`, { details: cpePropostaResult.errors });
            }
            logger.info(`Successfully created CPE_Proposta__c link for item ${index + 1}. ID: ${cpePropostaResult.id}`);


            // F.3 Upload Files (ContentVersion)
            if (cpeItem.fileUrls && cpeItem.fileUrls.length > 0) {
                logger.info(`Uploading ${cpeItem.fileUrls.length} files for CPE item ${index + 1}...`);
                for (const fileUrl of cpeItem.fileUrls) {
                    try {
                        // 1. Download file content
                        logger.debug(`Downloading file from: ${fileUrl}`);
                        const response = await axios.get(fileUrl, { responseType: 'arraybuffer' });
                        if (response.status !== 200) {
                            throw new Error(`Failed to download file: Status ${response.status}`);
                        }
                        const fileBuffer = Buffer.from(response.data);
                        logger.debug(`File downloaded. Size: ${fileBuffer.length} bytes.`);

                        // 2. Get filename
                         let fileName = 'UnknownFile';
                        try {
                           const decodedPath = decodeURIComponent(fileUrl.split('/').pop()?.split('?')[0] || 'UnknownFile');
                           fileName = decodedPath.split('/').pop() || 'UnknownFile';
                           // Remove potential query params/storage tokens from display name if needed
                        } catch(e) {
                           logger.warn(`Could not reliably parse filename from URL: ${fileUrl}`, e);
                           fileName = fileUrl.substring(fileUrl.lastIndexOf('/') + 1).split('?')[0] || 'UnknownFile';
                        }
                        logger.debug(`Extracted filename: ${fileName}`);

                        // 3. Base64 Encode
                        const base64Content = fileBuffer.toString('base64');

                        // 4. Create ContentVersion
                        const filePayload = {
                            Title: fileName,
                            PathOnClient: fileName,
                            VersionData: base64Content,
                            FirstPublishLocationId: proposalId, // Link to the main Proposta__c record
                            // Origin: 'H' // 'H' for Chatter, 'C' for Content. Optional.
                        };
                        logger.info(`Uploading ${fileName} (${base64Content.length} chars base64) to Salesforce, linking to Proposal ${proposalId}...`);

                        const fileResult = await callSalesforceApi<{ id?: string; success?: boolean; errors?: any[] }>(() =>
                            conn.sobject('ContentVersion').create(filePayload)
                        );

                        if (!fileResult.success || !fileResult.id) {
                            logger.error(`Failed to upload file ${fileName} to Salesforce.`, { result: fileResult });
                            throw new HttpsError("internal", `Failed to upload file ${fileName}.`, { details: fileResult.errors });
                        }
                        logger.info(`Successfully uploaded file ${fileName} as ContentVersion ${fileResult.id}`);

                    } catch (fileUploadError: any) {
                        logger.error(`Error processing file ${fileUrl}:`, fileUploadError);
                        // If it's an HttpsError (e.g., session expired from callSalesforceApi), rethrow it
                        if (fileUploadError instanceof HttpsError) {
                            throw fileUploadError;
                        }
                        // Otherwise, wrap it - decide if one file failure should stop everything
                        throw new HttpsError("internal", `Failed during file upload process for ${fileUrl}.`, fileUploadError);
                    }
                } // End loop through fileUrls
            } else {
                 logger.info(`No files to upload for CPE item ${index + 1}.`);
            }

        } // End loop through cpeItems

        // --- G. Return Success --- 
        logger.info("All proposal creation steps completed successfully.");
        return { success: true, proposalId: proposalId };

    } catch (error) {
      logger.error("Error caught during proposal creation process:", error);
      // Rollback attempts could be added here if needed, but can be complex.
      // For now, just report the failure.

      if (error instanceof HttpsError) {
          // If it's already an HttpsError, check for sessionExpired detail
          const details = error.details as { sessionExpired?: boolean } | undefined;
          return {
              success: false,
              proposalId: proposalId, // Include proposalId if it was created before failure
              error: error.message,
              sessionExpired: details?.sessionExpired ?? false,
          };
      } else if (error instanceof Error) {
          // Wrap other generic errors
          return { success: false, proposalId: proposalId, error: error.message };
      } else {
          return { success: false, proposalId: proposalId, error: "An unexpected error occurred." };
      }
    }
  }
);


// --- Salesforce API Call Helper Function (Copied from createSalesforceOpportunity) ---
// TODO: Consider moving this to a shared utility file
async function callSalesforceApi<T>(
    apiCall: () => Promise<T>,
    checkSessionExpiry = true // Added flag to control session expiry check
): Promise<T> {
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
            // stack: error.stack // Optional: include stack trace if needed
        });

        // Check for specific Salesforce session invalidation errors only if requested
        if (checkSessionExpiry &&
            (error.name === 'invalid_grant' ||
             error.errorCode === 'INVALID_SESSION_ID' ||
             (error.errorCode && typeof error.errorCode === 'string' && error.errorCode.includes('INVALID_SESSION_ID'))))
        {
            logger.warn('Detected invalid session ID or grant error.');
            throw new HttpsError('unauthenticated', 'Salesforce session expired or invalid.', { sessionExpired: true });
        } else {
            // Throw a generic internal error for other Salesforce issues
            const errorMessage = error.message || error.name || 'Unknown Salesforce API error';
            // Include SF error details if available
            const details = {
                 errorCode: error.errorCode,
                 fields: error.fields // Include fields if available (e.g., validation errors)
             };
            throw new HttpsError('internal', `Salesforce API call failed: ${errorMessage}`, details);
        }
    }
} 