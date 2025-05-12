import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as jsforce from 'jsforce';
import * as jwt from 'jsonwebtoken';
import axios from 'axios';

// --- Interfaces ---
interface RejectProposalInput {
    proposalId: string;
}
//add environment variables
// --- Helper Function for JWT Connection (reused from getResellerProposalDetails.ts) ---
async function getSalesforceConnection(): Promise<jsforce.Connection> {
    const functionName = "rejectProposalForReseller"; // For logging context
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
export const rejectProposalForReseller = onCall(
    {
        region: "us-central1",
        enforceAppCheck: false,
    },
    async (request): Promise<{ success: boolean, message?: string }> => {
        const functionName = "rejectProposalForReseller";
        const contextAuth = request.auth;

        // 1. --- Authentication Check ---
        if (!contextAuth) {
            logger.error(`${functionName}: Unauthenticated call.`);
            throw new HttpsError(
                "unauthenticated",
                "The function must be called while authenticated."
            );
        }
        logger.info(`${functionName}: Called by UID: ${contextAuth.uid}`);

        // 2. --- Input Validation ---
        const data = request.data as RejectProposalInput;
        const { proposalId } = data;
        
        if (!proposalId || typeof proposalId !== 'string' || !/^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$/.test(proposalId)) {
            logger.error(`${functionName}: Missing or invalid 'proposalId' input.`, { data });
            throw new HttpsError("invalid-argument", "Missing or invalid Salesforce Proposal ID.");
        }
        logger.info(`${functionName}: Rejecting proposal with SF ID: ${proposalId}`);

        let conn: jsforce.Connection;

        try {
            // 3. --- Salesforce Connection (JWT) ---
            conn = await getSalesforceConnection();

            // 4. --- Update Proposal Status ---
            logger.info(`${functionName}: Updating proposal ${proposalId} status to "Não Aprovada"`);
            
            // First check if the proposal exists
            const checkResult = await conn.query<{ Id: string, Status__c: string }>(
                `SELECT Id, Status__c FROM Proposta__c WHERE Id = '${proposalId}'`
            );

            if (checkResult.totalSize === 0) {
                logger.warn(`${functionName}: Proposal not found for ID ${proposalId}`);
                throw new HttpsError("not-found", `Proposal with ID ${proposalId} not found.`);
            }

            // Get current status (for logging)
            const currentStatus = checkResult.records[0].Status__c;
            logger.info(`${functionName}: Current status for proposal ${proposalId}: ${currentStatus}`);

            // Update the proposal status
            const updateResult = await conn.sobject('Proposta__c').update({
                Id: proposalId,
                Status__c: "Não Aprovada"
            });

            if (!updateResult.success) {
                logger.error(`${functionName}: Failed to update proposal status.`, updateResult);
                throw new HttpsError(
                    "internal", 
                    `Failed to update proposal status: ${updateResult.errors?.join(", ") || "Unknown error"}`
                );
            }

            // 5. --- Return Success ---
            logger.info(`${functionName}: Successfully updated proposal ${proposalId} status from "${currentStatus}" to "Não Aprovada".`);
            return {
                success: true,
                message: "Proposal status updated successfully to 'Não Aprovada'."
            };

        } catch (err: any) {
            // --- Error Handling ---
            logger.error(`${functionName}: Error during execution:`, err);

            if (err instanceof HttpsError) {
                // Re-throw known errors (auth, invalid args, not-found)
                throw err;
            } else if (axios.isAxiosError(err)) {
                let errorMessage = `Salesforce API request failed: ${err.message}`;
                if (err.response?.data) {
                    logger.error("Salesforce API Error Response:", err.response.data);
                    errorMessage += ` - ${err.response.data.error_description || err.response.data.error || JSON.stringify(err.response.data)}`;
                }
                throw new HttpsError('internal', errorMessage, { errorCode: "SF_API_REQUEST_FAILED" });
            } else if (err.name && err.message) {
                const errorCode = err.errorCode || err.name || "SF_OPERATION_FAILED";
                // Check for session errors
                if (errorCode === 'INVALID_SESSION_ID' || err.name === 'invalid_grant') {
                    logger.warn(`${functionName}: Detected invalid session ID or grant error.`);
                    throw new HttpsError('unauthenticated', 'Salesforce session expired or invalid.', { sessionExpired: true });
                }
                throw new HttpsError('internal', `${err.name}: ${err.message}`, { errorCode });
            } else {
                // Generic internal error
                throw new HttpsError('internal', "An unknown error occurred while updating proposal status.");
            }
        }
    }
); 