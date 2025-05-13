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

// --- NEW: Interface for File Info --- //
interface SalesforceFileInfo {
    id: string; // ContentVersion ID
    title: string; // File name (Title from ContentVersion)
}

// Structure for the CPE_Proposta__c junction object data needed
interface SalesforceCPEProposalData {
    Id: string;
    CPE__c?: string; // Added to store the CPE SFID/Number
    Consumo_ou_Potencia_Pico__c?: number; // Nullable number
    Fidelizacao_Anos__c?: number; // Nullable number
    Comissao_Retail__c?: number; // Nullable number
    // --- ADDED: Field for attached files --- //
    attachedFiles?: SalesforceFileInfo[];
}

// Structure for the Proposta__c object data needed
interface SalesforceProposalData {
    Id: string;
    Name: string;
    NIF__c: string | null;
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

// Structure for ContentDocumentLink query result
interface ContentDocumentLinkRecord {
    Id: string;
    LinkedEntityId: string;
    ContentDocumentId: string;
}

// Structure for ContentVersion query result
interface ContentVersionRecord {
    Id: string;
    ContentDocumentId: string;
    Title: string;
}

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

            // 4. --- SOQL Query for Proposal and CPEs (remains the same) ---
            const proposalQuery = 
                'SELECT ' +
                'Id, Name, Status__c, Data_de_Cria_o_da_Proposta__c, Data_de_Validade__c, ' +
                'NIF__c, ' +
                '(SELECT Id, CPE__c, Consumo_ou_Pot_ncia_Pico__c, Fideliza_o_Anos__c, Comiss_o_Retail__c FROM CPE_Propostas__r) ' +
                'FROM Proposta__c ' +
                'WHERE Id = \'' + proposalId + '\' ' +
                'LIMIT 1';

            logger.info(`${functionName}: Executing query for Proposal ID ${proposalId}`);
            logger.debug(`${functionName}: Query: ${proposalQuery.replace(/\s+/g, ' ').trim()}`);

            const result = await conn.query<SalesforceProposalData>(proposalQuery);

            if (result.totalSize === 0 || !result.records || result.records.length === 0) {
                logger.warn(`${functionName}: Proposal not found for ID ${proposalId}`);
                throw new HttpsError("not-found", `Proposal with ID ${proposalId} not found.`);
            }

            const proposalData = result.records[0];

            // Clean up attributes from nested records if they exist
            if (proposalData.CPE_Propostas__r && proposalData.CPE_Propostas__r.records) {
                proposalData.CPE_Propostas__r.records = proposalData.CPE_Propostas__r.records.map((r: any) => {
                    delete r.attributes; // Remove Salesforce metadata noise
                    r.attachedFiles = []; // Initialize attached files array
                    return r;
                });
            } else {
                // Ensure CPE_Propostas__r is not null if no records exist
                proposalData.CPE_Propostas__r = { totalSize: 0, done: true, records: [] };
            }

            logger.info(`${functionName}: Found Proposal: ${proposalData.Name} with ${proposalData.CPE_Propostas__r?.totalSize ?? 0} CPEs.`);

            // --- 5. Fetch Attached Files for CPEs --- //
            const cpeProposalIds = proposalData.CPE_Propostas__r.records.map((cpe) => cpe.Id);

            if (cpeProposalIds.length > 0) {
                logger.info(`${functionName}: Fetching files linked to ${cpeProposalIds.length} CPE_Proposta__c records...`);

                // Query ContentDocumentLink
                const linkedEntityIdsString = "('" + cpeProposalIds.join("\',\'") + "')"; // Format for IN clause
                const linkQuery = `SELECT Id, LinkedEntityId, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN ${linkedEntityIdsString}`;
                logger.debug(`${functionName}: Link Query: ${linkQuery}`);
                const linkResult = await conn.query<ContentDocumentLinkRecord>(linkQuery);
                const contentDocumentIds = linkResult.records.map((link) => link.ContentDocumentId);

                if (contentDocumentIds.length > 0) {
                    logger.info(`${functionName}: Found ${contentDocumentIds.length} ContentDocumentLinks. Fetching ContentVersions...`);

                    // Query ContentVersion for latest versions
                    const contentDocIdsString = "('" + contentDocumentIds.join("\',\'") + "')";
                    const versionQuery = `SELECT Id, ContentDocumentId, Title FROM ContentVersion WHERE ContentDocumentId IN ${contentDocIdsString} AND IsLatest = true`;
                    logger.debug(`${functionName}: Version Query: ${versionQuery}`);
                    const versionResult = await conn.query<ContentVersionRecord>(versionQuery);

                    // Map files back to CPE Proposals
                    const fileMap = new Map<string, SalesforceFileInfo[]>();
                    for (const version of versionResult.records) {
                        // Find the corresponding link(s) to get the LinkedEntityId (CPE_Proposta__c ID)
                        const links = linkResult.records.filter(link => link.ContentDocumentId === version.ContentDocumentId);
                        for (const link of links) {
                            const cpeProposalId = link.LinkedEntityId;
                            const fileInfo: SalesforceFileInfo = { id: version.Id, title: version.Title };
                            if (fileMap.has(cpeProposalId)) {
                                fileMap.get(cpeProposalId)?.push(fileInfo);
                            } else {
                                fileMap.set(cpeProposalId, [fileInfo]);
                            }
                        }
                    }

                    // Add files to the proposalData
                    proposalData.CPE_Propostas__r.records.forEach(cpe => {
                        if (fileMap.has(cpe.Id)) {
                            cpe.attachedFiles = fileMap.get(cpe.Id);
                            logger.debug(`${functionName}: Added ${cpe.attachedFiles?.length} files to CPE Proposal ${cpe.Id}`);
                        }
                    });
                } else {
                    logger.info(`${functionName}: No ContentDocumentLinks found for the CPE Proposals.`);
                }
            } else {
                logger.info(`${functionName}: No CPE Proposals found to fetch files for.`);
            }
            // --- END Fetch Attached Files --- //

            // 6. --- Return Success (Return the augmented record) ---
            logger.info(`${functionName}: Successfully processed proposal details and files for ID ${proposalId}.`);
            delete (proposalData as any).attributes; // Remove top-level attributes
            proposalData.NIF__c = proposalData.NIF__c ?? null; // Ensure it's null if missing
            return proposalData;

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