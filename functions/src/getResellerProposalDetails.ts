import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as jsforce from 'jsforce';
import * as jwt from 'jsonwebtoken';
import axios from 'axios';

// --- Interfaces ---

// Input for the function
interface GetResellerProposalDetailsInput {
    proposalId: string;
}

// Structure for the CPE_Proposta__c junction object data needed
interface SalesforceCPEProposalData {
    Id: string;
    Consumo_ou_Potencia_Pico__c?: number; // Nullable number
    Fidelizacao_Anos__c?: number; // Nullable number
    Comissao_Retail__c?: number; // Nullable number
}

// Structure for the Proposta__c object data needed
interface SalesforceProposalData {
    Id: string;
    Name: string;
    Status__c: string | null;
    Data_de_Cria_o_da_Proposta__c: string | null; // Renamed field to match actual data
    Data_de_Validade__c: string | null;
    // Nested structure for related CPEs from subquery
    CPE_Propostas__r?: {
        totalSize: number;
        done: boolean;
        records: SalesforceCPEProposalData[];
    } | null;
}

// Structure for the final result returned by the function (Simplified)
// We can return the main proposal record directly now
/*
interface GetResellerProposalDetailsResult {
    success: boolean;
    proposal?: SalesforceProposalData;
    cpePropostas?: SalesforceCPEProposalData[];
    error?: string;
    errorCode?: string;
}
*/

// --- Helper Function for JWT Connection (copied and adapted slightly) ---
async function getSalesforceConnection(): Promise<jsforce.Connection> {
    const functionName = "getResellerProposalDetails"; // For logging context
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


// --- Cloud Function Definition (UPDATED) ---

export const getResellerProposalDetails = onCall(
    {
        region: "us-central1",
        enforceAppCheck: false,
    },
    // Return type is now SalesforceProposalData or throws error
    async (request): Promise<SalesforceProposalData> => {
        const functionName = "getResellerProposalDetails";
        const contextAuth = request.auth;

        // 1. --- Authentication Check (remains the same) ---
        if (!contextAuth) {
            logger.error(`${functionName}: Unauthenticated call.`);
            throw new HttpsError(
                "unauthenticated",
                "The function must be called while authenticated."
            );
        }
        logger.info(`${functionName}: Called by UID: ${contextAuth.uid}`);

        // 2. --- Input Validation (remains the same) ---
        const data = request.data as GetResellerProposalDetailsInput;
        const { proposalId } = data;
        if (!proposalId || typeof proposalId !== 'string' || !/^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$/.test(proposalId)) {
            logger.error(`${functionName}: Missing or invalid 'proposalId' input.`, { data });
            throw new HttpsError("invalid-argument", "Missing or invalid Salesforce Proposal ID.");
        }
        logger.info(`${functionName}: Fetching details for Proposal SF ID: ${proposalId}`);

        let conn: jsforce.Connection;

        try {
            // 3. --- Salesforce Connection (JWT - remains the same) ---
            conn = await getSalesforceConnection();

            // 4. --- SOQL Query (UPDATED with Subquery, using string concatenation) ---
            const combinedQuery = 
                'SELECT ' +
                'Id, Name, Status__c, Data_de_Cria_o_da_Proposta__c, Data_de_Validade__c, ' +
                '(SELECT Id, Consumo_ou_Pot_ncia_Pico__c, Fideliza_o_Anos__c, Comiss_o_Retail__c FROM CPE_Propostas__r) ' +
                'FROM Proposta__c ' +
                'WHERE Id = \'' + proposalId + '\' ' + // Escape single quotes for proposalId
                'LIMIT 1';

            logger.info(`${functionName}: Executing combined query for Proposal ID ${proposalId}`);
            // Use combinedQuery directly for logging now
            logger.debug(`${functionName}: Query: ${combinedQuery.replace(/\s+/g, ' ').trim()}`);

            const result = await conn.query<SalesforceProposalData>(combinedQuery);

            if (result.totalSize === 0 || !result.records || result.records.length === 0) {
                logger.warn(`${functionName}: Proposal not found for ID ${proposalId}`);
                throw new HttpsError("not-found", `Proposal with ID ${proposalId} not found.`);
            }

            const proposalData = result.records[0];

            // Clean up attributes from nested records if they exist
             if (proposalData.CPE_Propostas__r && proposalData.CPE_Propostas__r.records) {
                 proposalData.CPE_Propostas__r.records = proposalData.CPE_Propostas__r.records.map((r: any) => {
                     delete r.attributes; // Remove Salesforce metadata noise
                     return r;
                 });
             }

            logger.info(`${functionName}: Found Proposal: ${proposalData.Name} with ${proposalData.CPE_Propostas__r?.totalSize ?? 0} CPEs.`);

            // 5. --- Return Success (Return the combined record directly) ---
            logger.info(`${functionName}: Successfully processed proposal details for ID ${proposalId}.`);
            // Remove noisy top-level attributes before returning
            delete (proposalData as any).attributes;
            return proposalData; // Return the main record which now includes nested CPEs

        } catch (err: any) {
            // --- Error Handling (Simplified - throw HttpsError directly) ---
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
                 throw new HttpsError('internal', "An unknown error occurred while fetching proposal details.");
            }
        }
    }
); 