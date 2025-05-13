import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as jsforce from 'jsforce';
import * as jwt from 'jsonwebtoken';
import axios from 'axios';

// --- Interfaces ---

interface GetResellerProposalsInput {
    opportunityId: string;
}

// UPDATE: Interface now includes Id, Name, Status, and Creation Date
interface SalesforceProposalRef { 
    Id: string; 
    Name: string;
    Status__c: string | null; // Added Status
    Data_de_Cria_o_da_Proposta__c: string | null; // Added Creation Date
}

interface GetResellerProposalsResult {
    success: boolean;
    proposals?: SalesforceProposalRef[]; // Updated type
    error?: string;
    errorCode?: string;
}

// --- Cloud Function ---

export const getResellerOpportunityProposals = onCall(
    {
        region: "us-central1", // Specify region consistently
        // Consider memory/timeout if query might be large
        // memory: "256MiB",
        // timeoutSeconds: 60,
        enforceAppCheck: false, // Set to true in production if using AppCheck
    },
    async (request): Promise<GetResellerProposalsResult> => {
        const contextAuth = request.auth;

        // 1. --- Authentication Check ---
        if (!contextAuth) {
            logger.error("getResellerOpportunityProposals: Unauthenticated call.");
            throw new HttpsError(
                "unauthenticated",
                "The function must be called while authenticated."
            );
        }
        const uid = contextAuth.uid;
        logger.info(`getResellerOpportunityProposals: Called by UID: ${uid}`);

        // 2. --- Input Validation ---
        const data = request.data as GetResellerProposalsInput;
        const { opportunityId } = data;

        if (!opportunityId || typeof opportunityId !== 'string') {
            logger.error("getResellerOpportunityProposals: Missing or invalid 'opportunityId' input.", data);
            throw new HttpsError(
                "invalid-argument",
                "Missing or invalid 'opportunityId' field in the input data."
            );
        }
        // Basic check for Salesforce ID format
        if (!/^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$/.test(opportunityId)) {
             logger.error("getResellerOpportunityProposals: Invalid Salesforce Opportunity ID format provided.", opportunityId);
             throw new HttpsError(
                "invalid-argument",
                "Invalid Salesforce Opportunity ID format provided."
             );
        }

        logger.info(`getResellerOpportunityProposals: Fetching proposal names for Opportunity SF ID: ${opportunityId}`);

        let conn: jsforce.Connection;

        try {
            // 4. --- Salesforce Connection and Login (JWT Flow) ---
            // Using environment variables
            const privateKey = process.env.SALESFORCE_PRIVATE_KEY?.replace(/\\n/g, '\n');
            const consumerKey = process.env.SALESFORCE_CONSUMER_KEY;
            const salesforceUsername = process.env.SALESFORCE_USERNAME; // System user for JWT

            if (!privateKey || !consumerKey || !salesforceUsername) {
                logger.error("getResellerOpportunityProposals: Salesforce environment variables missing.");
                throw new HttpsError('internal', 'Server configuration error: Salesforce credentials missing.');
            }

            const tokenEndpoint = "https://login.salesforce.com/services/oauth2/token";
            const audience = "https://login.salesforce.com";

            logger.debug('getResellerOpportunityProposals: Generating JWT for Salesforce...');
            const claim = {
                iss: consumerKey,
                sub: salesforceUsername,
                aud: audience,
                exp: Math.floor(Date.now() / 1000) + (3 * 60) // Expires in 3 minutes
            };

            const token = jwt.sign(claim, privateKey, { algorithm: 'RS256' });

            logger.debug('getResellerOpportunityProposals: Requesting Salesforce access token...');
            const tokenResponse = await axios.post(tokenEndpoint, new URLSearchParams({
                grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                assertion: token
            }).toString(), {
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
            });

            const { access_token, instance_url } = tokenResponse.data;

            if (!access_token || !instance_url) {
                logger.error('getResellerOpportunityProposals: Failed to retrieve access token or instance URL.', tokenResponse.data);
                throw new HttpsError('internal', 'Salesforce JWT authentication failed: Missing token/URL.');
            }

            logger.info('getResellerOpportunityProposals: Salesforce JWT authentication successful.');

            conn = new jsforce.Connection({
                instanceUrl: instance_url,
                accessToken: access_token
            });

            // 5. --- SOQL Query (UPDATED) ---
            // Select Id, Name, Status__c, and Data_de_Cria_o_da_Proposta__c
            // Order by creation date descending to get newest first
            const soqlQuery = `
                SELECT Id, Name, Status__c, Data_de_Cria_o_da_Proposta__c
                FROM Proposta__c
                WHERE Oportunidade__c = '${opportunityId}'
                ORDER BY Data_de_Cria_o_da_Proposta__c DESC
            `;

            logger.info(`getResellerOpportunityProposals: Executing SOQL query for Opportunity ID ${opportunityId}`);
            logger.debug(`getResellerOpportunityProposals: Query: ${soqlQuery.replace(/\s+/g, ' ').trim()}`);

            // Use the updated Interface type for the query result
            const result = await conn.query<SalesforceProposalRef>(soqlQuery);

            logger.info(`getResellerOpportunityProposals: Query successful. Found ${result.totalSize} proposals for Opportunity ${opportunityId}.`);

            // 6. --- Return Success ---
            return {
                success: true,
                proposals: result.records // Return the array of proposal records (now containing Id, Name, Status, and Creation Date)
            };

        } catch (err: any) {
            // --- Error Handling ---
            logger.error("getResellerOpportunityProposals: Error during execution:", err);

            let errorMessage = "An unknown error occurred while fetching proposals.";
            let errorCode = "UNKNOWN_PROPOSAL_FETCH_ERROR";

            if (err instanceof HttpsError) {
                // Re-throw HttpsErrors (e.g., auth, invalid args)
                throw err;
            } else if (axios.isAxiosError(err)) {
                errorMessage = `Salesforce API request failed: ${err.message}`;
                errorCode = "SF_API_REQUEST_FAILED";
                if (err.response?.data) {
                    logger.error("Salesforce API Error Response:", err.response.data);
                    errorMessage += ` - ${err.response.data.error_description || err.response.data.error || JSON.stringify(err.response.data)}`;
                }
            } else if (err.name && err.message) { // Handle jsforce or other standard errors
                 errorMessage = `${err.name}: ${err.message}`;
                 errorCode = err.errorCode || err.name || "SF_OPERATION_FAILED";
            } else if (typeof err === 'string') {
                 errorMessage = err;
            }

             // Return a structured error for client handling
             return {
                 success: false,
                 error: errorMessage,
                 errorCode: errorCode,
             };
        }
    }
); 