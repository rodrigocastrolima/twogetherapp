import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as jsforce from "jsforce";
import * as jwt from 'jsonwebtoken'; // <-- Add JWT import
import axios from 'axios'; // <-- Add axios import
//add var

// Initialize Firebase Admin SDK if not already done centrally in index.ts
// if (admin.apps.length === 0) {
//   admin.initializeApp()
/**
 * Fetches the total all-time commission for a given reseller ID.
 */
export const getTotalResellerCommission = onCall(
  { region: "us-central1" },
  async (request) => {
    // Use CallableRequest and access data/auth from request object
    // 1. Authentication Check
    if (!request.auth) {
      logger.error("Authentication check failed: User is not authenticated.");
      throw new HttpsError(
        "unauthenticated",
        "The function must be called while authenticated.",
      );
    }

    const resellerSalesforceId: string = request.data.resellerSalesforceId;
    if (!resellerSalesforceId || typeof resellerSalesforceId !== "string") {
      logger.error("Invalid argument: resellerSalesforceId is missing or invalid.", request.data);
      throw new HttpsError(
        "invalid-argument",
        "The function must be called with a valid 'resellerSalesforceId' (string).",
      );
    }

    logger.info(`Fetching total commission for reseller: ${resellerSalesforceId}`);

    // 2. Salesforce Connection (Using JWT Bearer Flow)
    const privateKey = process.env.SALESFORCE_PRIVATE_KEY?.replace(/\\n/g, '\n'); // <-- Use Private Key
    const consumerKey = process.env.SALESFORCE_CONSUMER_KEY; // <-- Use Consumer Key
    const salesforceUsername = process.env.SALESFORCE_USERNAME; // <-- Keep Username
    // const sfLoginUrl = process.env.SALESFORCE_LOGIN_URL ?? "https://login.salesforce.com"; // Login URL needed for token endpoint

    // Validate that environment variables are set
    if (!privateKey || !consumerKey || !salesforceUsername) {
        logger.error("Salesforce JWT credentials are not configured in environment variables (SALESFORCE_USERNAME, SALESFORCE_CONSUMER_KEY, SALESFORCE_PRIVATE_KEY).");
        throw new HttpsError("internal", "Salesforce connection configuration is missing.");
    }

    let conn: jsforce.Connection; // Declare conn here

    try {
        // --- JWT Authentication Logic ---
        const tokenEndpoint = "https://login.salesforce.com/services/oauth2/token"; // Standard endpoint
        const audience = "https://login.salesforce.com"; // Standard audience

        logger.debug('getTotalResellerCommission: Generating JWT for Salesforce...');
        const claim = {
            iss: consumerKey,
            sub: salesforceUsername,
            aud: audience,
            exp: Math.floor(Date.now() / 1000) + (3 * 60), // Expires in 3 minutes
        };
        const token = jwt.sign(claim, privateKey, { algorithm: 'RS256' });

        logger.debug('getTotalResellerCommission: Requesting Salesforce access token...');
        const tokenResponse = await axios.post(tokenEndpoint, new URLSearchParams({
            grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            assertion: token,
        }).toString(), {
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        });

        const { access_token, instance_url } = tokenResponse.data;

        if (!access_token || !instance_url) {
            logger.error('getTotalResellerCommission: Failed to retrieve access token or instance URL.', tokenResponse.data);
            throw new HttpsError('internal', 'Salesforce JWT authentication failed: Missing token/URL.');
        }

        logger.info(`getTotalResellerCommission: Salesforce JWT authentication successful. Instance: ${instance_url}`);

        // Create jsforce connection with obtained token and URL
        conn = new jsforce.Connection({
            instanceUrl: instance_url,
            accessToken: access_token,
        });
        // --- End JWT Authentication ---

        // 3. Construct SOQL Query (NEEDS VERIFICATION - Keep existing logic)
        // IMPORTANT: Verify field API names and relationship paths!
        // IMPORTANT: Validate inputs before inserting into query string!
        const commissionFieldApiName = "Comiss_o_Retail__c"; // <-- VERIFY THIS
        const statusFieldApiName = "Status__c"; // <-- VERIFY THIS on Proposta__c
        const acceptedStatusValue = "Aceite"; // <-- VERIFY THIS
        // Relationship path from CPE_Proposta__c up to Reseller__c on Oportunidade__c
        const relationshipPathToResellerViaProposal = "Proposta_CPE__r.Oportunidade__r.Agente_Retail__c"; // Corrected relationship
        const relationshipPathToStatus = "Proposta_CPE__r"; // Corrected relationship

        // Validate resellerSalesforceId format before using (basic example)
        if (!/^[a-zA-Z0-9]{15,18}$/.test(resellerSalesforceId)) {
          throw new HttpsError("invalid-argument", "Invalid reseller Salesforce ID format.");
        }
        // Validate acceptedStatusValue if it comes from input

        const soql = `
            SELECT SUM(${commissionFieldApiName}) totalCommission
            FROM CPE_Proposta__c
            WHERE ${relationshipPathToResellerViaProposal} = '${resellerSalesforceId}'
            AND ${relationshipPathToStatus}.${statusFieldApiName} = '${acceptedStatusValue}'
        `; // Removed conn.escape as SF ID is validated by regex

        logger.info(`Executing SOQL: ${soql}`);

        // 4. Execute Query (Keep existing logic)
        const result = await conn.query<{ totalCommission: number | null }>(soql);

        logger.info("SOQL Result:", JSON.stringify(result));

        // 5. Parse Result (Keep existing logic)
        let totalCommission = 0.0;
        if (
            result &&
            result.totalSize > 0 &&
            result.records[0] &&
            result.records[0].totalCommission != null // Access the aggregated field
        ) {
            const rawSum = result.records[0].totalCommission;
            if (typeof rawSum === 'number') {
                totalCommission = rawSum;
            } else {
                logger.warn(`Received non-numeric sum from SOQL: ${rawSum}`);
            }
        }

        logger.info(`Calculated total commission: ${totalCommission}`);

        // 6. Return Success (Keep existing logic)
        return { success: true, totalCommission: totalCommission };

    } catch (error: any) {
        logger.error("Error fetching total commission:", error);
        // Logout is not needed with JWT flow as tokens are short-lived

        // Throw an HttpsError for the client
        if (error instanceof HttpsError) throw error; // Rethrow if already HttpsError

        // Handle Axios errors specifically if needed
        if (axios.isAxiosError(error)) {
            let detailedErrorMessage = `Salesforce API request failed: ${error.message}`;
             if (error.response?.data) {
                 logger.error("Salesforce API Error Response:", error.response.data);
                 detailedErrorMessage += ` - ${error.response.data.error_description || error.response.data.error || JSON.stringify(error.response.data)}`;
             }
             throw new HttpsError("internal", detailedErrorMessage, error.response?.data);
        }

        // General internal error
        throw new HttpsError(
            "internal",
            `Failed to fetch total commission: ${error.message || error}`,
            error
        );
    }
  }
); 