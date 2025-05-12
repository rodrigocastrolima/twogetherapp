import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as jsforce from 'jsforce';
import * as jwt from 'jsonwebtoken';
import axios from 'axios';

// --- Interfaces ---
interface FileInfoInput {
    type: 'PR' | 'CC' | 'CRC' | 'Contrato' | string; // Type identifier (e.g., 'PR', 'CC', 'Contrato')
    url: string; // Firebase Storage download URL
    originalFilename: string; // <-- ADDED: Original filename from client
    cpe?: string; // CPE Identifier, required only if type is 'Contrato'
}
//add environment variables
interface AcceptProposalInput {
    proposalId: string;
    nif: string;
    files: FileInfoInput[];
}

interface UploadResult {
    name: string;
    salesforceContentVersionId: string;
    salesforceContentDocumentId: string;
    status: 'success' | 'error';
    errorMessage?: string;
}

interface AcceptProposalResult {
    success: boolean;
    message: string;
    uploadResults?: UploadResult[];
    proposalUpdateStatus?: 'commented_out' | 'attempted' | 'success' | 'failed'; // To track the status update part
    error?: string; // General error message
}


// --- Helper Function for Filename Generation ---
function generateSalesforceFilename(
    type: string,
    nif: string,
    originalFilename: string, // <-- Receive original filename
    cpe?: string
): string {
    let baseName = '';
    switch (type) {
        case 'PR':
            baseName = `PR_${nif}`;
            break;
        case 'CC':
            baseName = `CC_${nif}`;
            break;
        case 'CRC':
            baseName = `CRC_${nif}`;
            break;
        case 'Contrato':
            baseName = cpe ? `Contrato_${cpe}` : `Contrato_UnknownCPE_${nif}`;
            break;
        default:
            baseName = `Doc_${type}_${nif}`;
    }
    // Extract extension (including the dot) or default to empty string
    const extension = originalFilename.includes('.') ? 
                      originalFilename.substring(originalFilename.lastIndexOf('.')) : 
                      ''; 
    return `${baseName}${extension}`; // Append extension
}

// --- Helper Function for JWT Connection (copied from existing functions) ---
// Ensure environment variables SALESFORCE_PRIVATE_KEY, SALESFORCE_CONSUMER_KEY, SALESFORCE_USERNAME are set
async function getSalesforceConnection(): Promise<jsforce.Connection> {
    const functionName = "acceptProposalAndUploadDocs"; // For logging context
    // Use environment variable directly, assuming it contains literal \n
    const privateKey = process.env.SALESFORCE_PRIVATE_KEY?.replace(/\\n/g, '\n');
    const consumerKey = process.env.SALESFORCE_CONSUMER_KEY;
    const salesforceUsername = process.env.SALESFORCE_USERNAME;

    if (!privateKey || !consumerKey || !salesforceUsername) {
        logger.error(`${functionName}: Salesforce environment variables missing.`);
        throw new HttpsError('internal', 'Server configuration error: Salesforce credentials missing.');
    }

    const tokenEndpoint = "https://login.salesforce.com/services/oauth2/token";
    const audience = "https://login.salesforce.com";

    logger.debug(`${functionName}: Generating JWT for Salesforce...`);
    const claim = {
        iss: consumerKey,
        sub: salesforceUsername,
        aud: audience,
        exp: Math.floor(Date.now() / 1000) + (3 * 60) // Expires in 3 minutes
    };

    const token = jwt.sign(claim, privateKey, { algorithm: 'RS256' });

    logger.debug(`${functionName}: Requesting Salesforce access token...`);
    const tokenResponse = await axios.post(tokenEndpoint, new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: token
    }).toString(), {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
    });

    const { access_token, instance_url } = tokenResponse.data;

    if (!access_token || !instance_url) {
        logger.error(`${functionName}: Failed to retrieve access token or instance URL.`, tokenResponse.data);
        throw new HttpsError('internal', 'Salesforce JWT authentication failed: Missing token/URL.');
    }

    logger.info(`${functionName}: Salesforce JWT authentication successful.`);

    return new jsforce.Connection({
        instanceUrl: instance_url,
        accessToken: access_token
    });
}


// --- Cloud Function Definition ---
export const acceptProposalAndUploadDocs = onCall(
    {
        timeoutSeconds: 540, // Increased timeout for downloads/uploads
        memory: "1GiB", // Increased memory for file processing
        region: "us-central1",
        // enforceAppCheck: true, // Recommended for production
    },
    async (request: CallableRequest<AcceptProposalInput>): Promise<AcceptProposalResult> => {
        const functionName = "acceptProposalAndUploadDocs";

        // 1. --- Firebase Authentication Check ---
        if (!request.auth) {
            logger.error(`${functionName}: Unauthenticated call.`);
            throw new HttpsError(
                "unauthenticated",
                "The function must be called while authenticated (reseller)."
            );
        }
        const resellerUid = request.auth.uid;
        logger.info(`${functionName}: Called by authenticated Reseller UID: ${resellerUid}`);

        // 2. --- Input Validation ---
        const data = request.data;
        if (!data.proposalId || !data.nif || !Array.isArray(data.files) || data.files.length === 0) {
            logger.error(`${functionName}: Missing or invalid input data.`, { data });
            throw new HttpsError("invalid-argument", "Missing required fields: proposalId, nif, and files array.");
        }
        logger.info(`${functionName}: Processing acceptance for Proposal SF ID: ${data.proposalId}, NIF: ${data.nif}`);

        let conn: jsforce.Connection;
        const uploadResults: UploadResult[] = [];

        try {
            // 3. --- Salesforce Connection (JWT) ---
            conn = await getSalesforceConnection();
            logger.info(`${functionName}: Salesforce connection established.`);

            // 4. --- File Processing Loop ---
            logger.info(`${functionName}: Starting processing for ${data.files.length} files.`);
            for (const [index, fileInfo] of data.files.entries()) {
                let sfFileName = `Unknown_File_${index + 1}`; // Default fallback name
                let currentFileResult: Partial<UploadResult> = { name: 'unknown', status: 'error' }; // Initialize result for this file

                try {
                    // 4a. --- Determine Salesforce File Name using helper function ---
                    logger.info(`${functionName}: Processing file ${index + 1}/${data.files.length}, Type: ${fileInfo.type}, Original: ${fileInfo.originalFilename}`);
                    
                    // Call the helper function
                    sfFileName = generateSalesforceFilename(
                        fileInfo.type,
                        data.nif,
                        fileInfo.originalFilename, // Pass original filename
                        fileInfo.cpe // Pass CPE if available
                    );
                    
                    currentFileResult.name = sfFileName; // Store the determined name
                    logger.info(`${functionName}: Determined Salesforce file name: ${sfFileName}`);


                    // 4b. --- Download File from Firebase Storage ---
                    logger.debug(`${functionName}: Downloading file from URL: ${fileInfo.url}`);
                    const response = await axios.get(fileInfo.url, { responseType: 'arraybuffer' });
                    if (response.status !== 200) {
                        throw new Error(`Failed to download file from URL. Status: ${response.status}`);
                    }
                    const fileContentBuffer = Buffer.from(response.data);
                    logger.debug(`${functionName}: File downloaded successfully. Size: ${fileContentBuffer.length} bytes.`);


                    // 4c. --- Convert to Base64 ---
                    const fileContentBase64 = fileContentBuffer.toString('base64');
                    logger.debug(`${functionName}: File converted to Base64.`);


                    // 4d. --- Create ContentVersion in Salesforce ---
                    logger.info(`${functionName}: Uploading "${sfFileName}" to Salesforce ContentVersion...`);
                    const cvResult = await conn.sobject('ContentVersion').create({
                        Title: sfFileName,
                        PathOnClient: sfFileName, // Use the same name for PathOnClient
                        VersionData: fileContentBase64,
                        Origin: 'C', // 'C' for Content Library, 'H' for Chatter
                    });

                    if (!cvResult.success || !cvResult.id) {
                        logger.error(`${functionName}: Failed to create ContentVersion for "${sfFileName}".`, { errors: cvResult.errors });
                        throw new Error(`Salesforce API Error creating ContentVersion: ${cvResult.errors?.map(e => e.message).join(', ') || 'Unknown error'}`);
                    }
                    const contentVersionId = cvResult.id;
                    currentFileResult.salesforceContentVersionId = contentVersionId;
                    logger.info(`${functionName}: Successfully created ContentVersion. ID: ${contentVersionId}`);


                    // 4e. --- Get ContentDocumentId ---
                    logger.debug(`${functionName}: Querying ContentDocumentId for ContentVersion ${contentVersionId}...`);
                    const cdQuery = await conn.query<{ ContentDocumentId: string }>(
                        `SELECT ContentDocumentId FROM ContentVersion WHERE Id = '${contentVersionId}' LIMIT 1`
                    );

                    if (!cdQuery.records || cdQuery.records.length === 0 || !cdQuery.records[0].ContentDocumentId) {
                        logger.error(`${functionName}: Failed to retrieve ContentDocumentId for ContentVersion ${contentVersionId}.`);
                        throw new Error("Could not find ContentDocumentId after creating ContentVersion.");
                    }
                    const contentDocumentId = cdQuery.records[0].ContentDocumentId;
                    currentFileResult.salesforceContentDocumentId = contentDocumentId;
                    logger.info(`${functionName}: Retrieved ContentDocumentId: ${contentDocumentId}`);


                    // 4f. --- Create ContentDocumentLink ---
                    logger.info(`${functionName}: Linking ContentDocument ${contentDocumentId} to Proposal ${data.proposalId}...`);
                    const cdlResult = await conn.sobject('ContentDocumentLink').create({
                        ContentDocumentId: contentDocumentId,
                        LinkedEntityId: data.proposalId, // Link directly to the Proposal
                        ShareType: 'V', // 'V'iewer, 'C'ollaborator, 'I'nferred
                        Visibility: 'AllUsers', // Or 'InternalUsers'
                    });

                    if (!cdlResult.success || !cdlResult.id) {
                        logger.error(`${functionName}: Failed to create ContentDocumentLink for Doc ${contentDocumentId} to Proposal ${data.proposalId}.`, { errors: cdlResult.errors });
                        // If linking fails, the file is uploaded but not visible on the proposal. Consider this an error for the file.
                         throw new Error(`Salesforce API Error creating ContentDocumentLink: ${cdlResult.errors?.map(e => e.message).join(', ') || 'Unknown error'}`);
                    }
                    logger.info(`${functionName}: Successfully created ContentDocumentLink. Link ID: ${cdlResult.id}`);

                    // Mark this file as successfully processed
                    currentFileResult.status = 'success';

                } catch (fileProcessingError: any) {
                     logger.error(`${functionName}: Failed processing file "${sfFileName}" (Index ${index}):`, fileProcessingError);
                     currentFileResult.status = 'error';
                     currentFileResult.errorMessage = fileProcessingError.message || "Unknown error during file processing.";
                     // Continue to the next file even if one fails
                } finally {
                    // Add the result of this file attempt to the overall results
                    uploadResults.push(currentFileResult as UploadResult);
                }
            } // End file processing loop

            // Check if all uploads were successful
            const allFilesSuccessful = uploadResults.every(r => r.status === 'success');
            if (!allFilesSuccessful) {
                logger.warn(`${functionName}: Not all files were uploaded successfully for proposal ${data.proposalId}.`);
                // Do not proceed with status update if files failed
                 return {
                    success: false, // Indicate partial failure
                    message: "Some files failed to upload or link.",
                    uploadResults: uploadResults,
                    proposalUpdateStatus: undefined, // Set to undefined as the operation was skipped
                };
            }

            // 5. --- Update Proposal Status (Commented Out) ---
            logger.info(`${functionName}: Proposal Status update to 'Aprovada' is commented out as requested.`);
            const proposalUpdateStatus : AcceptProposalResult['proposalUpdateStatus'] = 'commented_out';
            /*
            try {
                 logger.info(`${functionName}: Attempting to update Proposal ${data.proposalId} status to 'Aprovada'...`);
                 proposalUpdateStatus = 'attempted';
                 const updateResult = await conn.sobject('Proposta__c').update({
                     Id: data.proposalId,
                     Status__c: "Aprovada" // Ensure this API name and value are correct
                 });

                 if (!updateResult.success) {
                     logger.error(`${functionName}: Failed to update proposal status to 'Aprovada'.`, { errors: updateResult.errors });
                     proposalUpdateStatus = 'failed';
                     // Decide if this failure should make the whole function call fail
                     // For now, let's report success with a warning about the status update
                 } else {
                     logger.info(`${functionName}: Successfully updated proposal ${data.proposalId} status to 'Aprovada'.`);
                     proposalUpdateStatus = 'success';
                 }
            } catch (statusUpdateError: any) {
                 logger.error(`${functionName}: Error during proposal status update:`, statusUpdateError);
                 proposalUpdateStatus = 'failed';
                 // Log error but don't necessarily fail the whole function if files uploaded ok
            }
            */

            // 6. --- Return Success ---
            logger.info(`${functionName}: Successfully processed proposal acceptance for ID ${data.proposalId}. All files uploaded.`);
            return {
                success: true,
                message: "Proposal accepted and all documents processed successfully.",
                uploadResults: uploadResults,
                proposalUpdateStatus: proposalUpdateStatus
            };

        } catch (error: any) {
            // --- Error Handling ---
            logger.error(`${functionName}: Top-level error during execution:`, error);

            if (error instanceof HttpsError) {
                // Re-throw HttpsErrors (e.g., auth, invalid args)
                throw error;
            } else if (axios.isAxiosError(error) && error.config?.url?.includes('firebasestorage')) {
                 // Specific error for Firebase Storage download failure
                 logger.error(`${functionName}: Failed to download file from Firebase Storage.`, { url: error.config.url, status: error.response?.status });
                 throw new HttpsError('internal', 'Failed to download required file from storage.', { detail: error.message });
            } else if (error.errorCode === 'INVALID_SESSION_ID' || error.message?.includes('Session expired or invalid')) {
                // Handle Salesforce session expiry
                logger.warn(`${functionName}: Salesforce session expired or invalid.`);
                throw new HttpsError('unauthenticated', 'Salesforce session expired. Please coordinate with admin.', { sessionExpired: true });
            } else if (error.name && error.message && error.errorCode) {
                 // Handle other specific Salesforce errors caught by the connection helper or direct calls
                 logger.error(`${functionName}: Salesforce operation failed.`, { name: error.name, message: error.message, errorCode: error.errorCode });
                 throw new HttpsError('internal', `Salesforce operation failed: ${error.message}`, { errorCode: error.errorCode });
            }
            else {
                // Generic internal error
                 logger.error(`${functionName}: An unexpected error occurred.`, { error: error });
                throw new HttpsError('internal', "An unknown error occurred while processing the proposal acceptance.");
            }
        }
    }
); 