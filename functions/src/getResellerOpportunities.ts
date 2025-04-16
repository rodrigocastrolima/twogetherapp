import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as jsforce from 'jsforce';
import * as jwt from 'jsonwebtoken';
import axios from 'axios';

// --- Interfaces ---

interface GetOpportunitiesInput {
    resellerSalesforceId: string;
}

// Define the expected structure of Salesforce Opportunity records from the query
interface SalesforceOpportunity {
    Id: string;
    Name: string;
    NIF__c: string | null; // Added NIF field
    Fase__c: string | null;
    CreatedDate: string; // Date field (ISO 8601 format)
    // Removed: AccountId, Account, Solu_o__c, Data_de_Previs_o_de_Fecho__c
}

interface GetOpportunitiesResult {
    success: boolean;
    opportunities?: SalesforceOpportunity[];
    error?: string;
    errorCode?: string;
}

// --- Cloud Function ---

export const getResellerOpportunities = onCall(
    {
        region: "us-central1", // Specify region consistently
        enforceAppCheck: false, // Set to true in production if using AppCheck
    },
    async (request): Promise<GetOpportunitiesResult> => {
        const contextAuth = request.auth;

        // 1. --- Authentication Check ---
        if (!contextAuth) {
            logger.error("getResellerOpportunities: Unauthenticated call.");
            throw new HttpsError(
                "unauthenticated",
                "The function must be called while authenticated."
            );
        }
        // Optional: Add role check if needed (e.g., ensure caller is reseller or admin)
        // const callerDoc = await admin.firestore().collection("users").doc(contextAuth.uid).get();
        // const callerRole = callerDoc.data()?.role?.toLowerCase();
        // if (callerRole !== 'reseller' && callerRole !== 'admin') { ... }

        logger.info(`getResellerOpportunities: Called by UID: ${contextAuth.uid}`);

        // 2. --- Input Validation ---
        const data = request.data as GetOpportunitiesInput;
        const { resellerSalesforceId } = data;

        if (!resellerSalesforceId || typeof resellerSalesforceId !== 'string') {
            logger.error("getResellerOpportunities: Missing or invalid 'resellerSalesforceId' input.", data);
            throw new HttpsError(
                "invalid-argument",
                "Missing or invalid 'resellerSalesforceId' field in the input data."
            );
        }
        // Basic check for Salesforce ID format (15 or 18 chars, alphanumeric)
        if (!/^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$/.test(resellerSalesforceId)) {
             logger.error("getResellerOpportunities: Invalid Salesforce ID format provided.", resellerSalesforceId);
             throw new HttpsError(
                "invalid-argument",
                "Invalid Salesforce ID format provided."
             );
        }


        logger.info(`getResellerOpportunities: Fetching opportunities for Reseller SF ID: ${resellerSalesforceId}`);

        let conn: jsforce.Connection;

        try {
            // 3. --- Salesforce Connection and Login ---
            // Using environment variables instead of functions.config()
            const privateKey = process.env.SALESFORCE_PRIVATE_KEY?.replace(/\\n/g, '\n');
            const consumerKey = process.env.SALESFORCE_CONSUMER_KEY;
            const salesforceUsername = process.env.SALESFORCE_USERNAME;
            
            // Validate that environment variables are set
            if (!privateKey || !consumerKey || !salesforceUsername) {
                logger.error("getResellerOpportunities: Salesforce environment variables missing.");
                throw new HttpsError('internal', 'Server configuration error: Salesforce credentials missing.');
            }

            const tokenEndpoint = "https://login.salesforce.com/services/oauth2/token";
            const audience = "https://login.salesforce.com";

            logger.debug('getResellerOpportunities: Generating JWT for Salesforce...');
            const claim = {
                iss: consumerKey,
                sub: salesforceUsername,
                aud: audience,
                exp: Math.floor(Date.now() / 1000) + (3 * 60) // Expires in 3 minutes
            };
            const token = jwt.sign(claim, privateKey, { algorithm: 'RS256' });

            logger.debug('getResellerOpportunities: Requesting Salesforce access token...');
            const tokenResponse = await axios.post(tokenEndpoint, new URLSearchParams({
                grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                assertion: token
            }).toString(), {
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
            });

            const { access_token, instance_url } = tokenResponse.data;

            if (!access_token || !instance_url) {
                logger.error('getResellerOpportunities: Failed to retrieve access token or instance URL.', tokenResponse.data);
                throw new HttpsError('internal', 'Salesforce JWT authentication failed: Missing token/URL.');
            }

            logger.info('getResellerOpportunities: Salesforce JWT authentication successful.');

            conn = new jsforce.Connection({
                instanceUrl: instance_url,
                accessToken: access_token
            });

            // 4. --- SOQL Query ---
            // Select only the fields requested by the user
            const soqlQuery = `
                SELECT
                    Id,
                    Name,
                    NIF__c,
                    Fase__c,
                    CreatedDate
                FROM Oportunidade__c
                WHERE Agente_Retail__c = '${resellerSalesforceId}'
                ORDER BY CreatedDate DESC
            `;
            // Removed: AccountId, Account.Name, Solu_o__c, Data_de_Previs_o_de_Fecho__c, and the inline comment

            logger.info(`getResellerOpportunities: Executing SOQL query for ${resellerSalesforceId}`);
            logger.debug(`getResellerOpportunities: Query: ${soqlQuery.replace(/\s+/g, ' ').trim()}`);

            const result = await conn.query<SalesforceOpportunity>(soqlQuery);

            logger.info(`getResellerOpportunities: Query successful. Found ${result.totalSize} opportunities for ${resellerSalesforceId}.`);

            // 5. --- Return Success ---
            return {
                success: true,
                opportunities: result.records // Return the array of opportunity records
            };

        } catch (err: any) {
            // --- Error Handling ---
            logger.error("getResellerOpportunities: Error during execution:", err);

            let errorMessage = "An unknown error occurred during Salesforce operation.";
            let errorCode = "UNKNOWN_SF_ERROR";

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
