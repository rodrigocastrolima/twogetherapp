import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as jsforce from 'jsforce';
import * as jwt from 'jsonwebtoken';
import axios from 'axios';

// --- Interfaces ---

// Input for the function
interface GetProposalsInput {
    opportunityId: string;
}

// Structure for the CPE_Proposta__c junction object data needed
interface SalesforceCPEProposal {
    Id: string;
    Proposta__c: string; // Link to the Proposal
    Comissao_Retail__c?: number; // The commission field (nullable)
}

// Structure for the Proposta__c object data needed
interface SalesforceProposalBase {
    Id: string;
    Name: string;
    Valor_Investimento_Solar__c?: number; // Nullable number
    // Data_de_Criacao__c: string; // Removed - Will be fetched later if needed
    Data_de_Validade__c: string; // Date string
    Status__c: string; // Status field
}

// Structure for the final result returned by the function (enriched proposal)
interface SalesforceProposal extends SalesforceProposalBase {
    totalComissaoRetail?: number; // Aggregated commission (optional)
}

// Structure for the function's result
interface GetProposalsResult {
    success: boolean;
    proposals?: SalesforceProposal[];
    error?: string;
    errorCode?: string;
}

// Helper Function to get Salesforce Connection (adapted from getResellerOpportunities)
async function getSalesforceConnection(): Promise<jsforce.Connection> {
    // Use environment variable directly, assuming it contains literal \n
    const privateKey = process.env.SALESFORCE_PRIVATE_KEY?.replace(/\\n/g, '\n');
    const consumerKey = process.env.SALESFORCE_CONSUMER_KEY;
    const salesforceUsername = process.env.SALESFORCE_USERNAME;

    if (!privateKey || !consumerKey || !salesforceUsername) {
        logger.error("Salesforce environment variables missing.");
        throw new HttpsError('internal', 'Server configuration error: Salesforce credentials missing.');
    }

    const tokenEndpoint = "https://login.salesforce.com/services/oauth2/token";
    const audience = "https://login.salesforce.com";

    logger.debug('Generating JWT for Salesforce...');
    const claim = {
        iss: consumerKey,
        sub: salesforceUsername,
        aud: audience,
        exp: Math.floor(Date.now() / 1000) + (3 * 60) // Expires in 3 minutes
    };

    // --- Debug Logging --- 
    logger.debug(`GOP: typeof privateKey: ${typeof privateKey}`);
    logger.debug(`GOP: privateKey start: ${privateKey?.substring(0, 30)}`); // Log start
    logger.debug(`GOP: privateKey end: ${privateKey?.substring(privateKey.length - 30)}`); // Log end
    // --- End Debug --- 

    const token = jwt.sign(claim, privateKey, { algorithm: 'RS256' });

    logger.debug('Requesting Salesforce access token...');
    const tokenResponse = await axios.post(tokenEndpoint, new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: token
    }).toString(), {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
    });

    const { access_token, instance_url } = tokenResponse.data;

    if (!access_token || !instance_url) {
        logger.error('Failed to retrieve access token or instance URL.', tokenResponse.data);
        throw new HttpsError('internal', 'Salesforce JWT authentication failed: Missing token/URL.');
    }

    logger.info('Salesforce JWT authentication successful.');

    return new jsforce.Connection({
        instanceUrl: instance_url,
        accessToken: access_token
    });
}


// --- Cloud Function ---

export const getOpportunityProposals = onCall(
    {
        region: "us-central1", // Consistent region
        enforceAppCheck: false, // Consider enabling in production
    },
    async (request): Promise<GetProposalsResult> => {
        const contextAuth = request.auth;

        // 1. --- Authentication Check ---
        if (!contextAuth) {
            logger.error("getOpportunityProposals: Unauthenticated call.");
            throw new HttpsError(
                "unauthenticated",
                "The function must be called while authenticated."
            );
        }
        logger.info(`getOpportunityProposals: Called by UID: ${contextAuth.uid}`);

        // 2. --- Input Validation ---
        const data = request.data as GetProposalsInput;
        const { opportunityId } = data;

        if (!opportunityId || typeof opportunityId !== 'string') {
            logger.error("getOpportunityProposals: Missing or invalid 'opportunityId' input.", data);
            throw new HttpsError(
                "invalid-argument",
                "Missing or invalid 'opportunityId' field in the input data."
            );
        }
         // Basic check for Salesforce ID format
         if (!/^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$/.test(opportunityId)) {
            logger.error("getOpportunityProposals: Invalid Salesforce Opportunity ID format provided.", opportunityId);
            throw new HttpsError(
               "invalid-argument",
               "Invalid Salesforce Opportunity ID format provided."
            );
       }

        logger.info(`getOpportunityProposals: Fetching proposals for Opportunity SF ID: ${opportunityId}`);

        let conn: jsforce.Connection;

        try {
            // 3. --- Salesforce Connection ---
            conn = await getSalesforceConnection(); // Use helper function

            // 4. --- SOQL Query 1: Fetch Proposals ---
            const proposalQuery = `
                SELECT
                    Id,
                    Name,
                    Data_de_Validade__c,
                    Status__c
                FROM Proposta__c
                WHERE Oportunidade__c = '${opportunityId}'
            `;

            logger.info(`getOpportunityProposals: Executing Proposal query for Opp ID ${opportunityId}`);
            logger.debug(`getOpportunityProposals: Proposal Query: ${proposalQuery.replace(/\s+/g, ' ').trim()}`);

            const proposalResult = await conn.query<SalesforceProposalBase>(proposalQuery);
            const baseProposals = proposalResult.records;

            logger.info(`getOpportunityProposals: Found ${proposalResult.totalSize} proposals for Opp ID ${opportunityId}.`);

            if (!baseProposals || baseProposals.length === 0) {
                return { success: true, proposals: [] }; // No proposals found
            }

            // 5. --- SOQL Query 2: Fetch CPE_Proposta Junction Records ---
            const proposalIds = baseProposals.map(p => p.Id);
            const cpeProposalQuery = `
                SELECT
                    Id,
                    Proposta__c
                FROM CPE_Proposta__c
                WHERE Proposta__c IN ('${proposalIds.join("','")}')
            `;

            logger.info(`getOpportunityProposals: Executing CPE_Proposta query for ${proposalIds.length} Proposal IDs.`);
            logger.debug(`getOpportunityProposals: CPE_Proposta Query: ${cpeProposalQuery.replace(/\s+/g, ' ').trim()}`);

            const cpeProposalResult = await conn.query<SalesforceCPEProposal>(cpeProposalQuery);
            const cpeProposals = cpeProposalResult.records;

            logger.info(`getOpportunityProposals: Found ${cpeProposalResult.totalSize} CPE_Proposta records.`);

            // 6. --- Data Aggregation: Calculate Total Commission ---
            const commissionMap = new Map<string, number>(); // Map<ProposalId, TotalCommission>

            if (cpeProposals) {
                for (const cpeProp of cpeProposals) {
                    const proposalId = cpeProp.Proposta__c;
                    const commission = cpeProp.Comissao_Retail__c ?? 0; // Default to 0 if null

                    const currentTotal = commissionMap.get(proposalId) ?? 0;
                    commissionMap.set(proposalId, currentTotal + commission);
                }
            }

            // 7. --- Enrich Proposals with Total Commission ---
            const enrichedProposals: SalesforceProposal[] = baseProposals.map(baseProposal => ({
                ...baseProposal,
                totalComissaoRetail: commissionMap.get(baseProposal.Id) // Will be undefined if no CPE_Proposta records found for this proposal
            }));

             // 8. --- Return Success ---
             logger.info(`getOpportunityProposals: Successfully processed proposals for Opp ID ${opportunityId}.`);
             return {
                 success: true,
                 proposals: enrichedProposals
             };

        } catch (err: any) {
            // --- Error Handling ---
            logger.error("getOpportunityProposals: Error during execution:", err);

            let errorMessage = "An unknown error occurred.";
            let errorCode = "UNKNOWN_ERROR";

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