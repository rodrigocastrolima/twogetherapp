import * as functions from "firebase-functions/v2"; // Use v2 imports
// import * as admin from "firebase-admin"; // Unused import removed
import * as jsforce from "jsforce";

// Initialize Firebase Admin SDK if not already done centrally in index.ts
// if (admin.apps.length === 0) {
//   admin.initializeApp();
// }

/**
 * Fetches the total all-time commission for a given reseller ID.
 */
export const getTotalResellerCommission = functions.https.onCall(
  { region: "europe-west1" }, // Move region into options object
  async (request: functions.https.CallableRequest<{ resellerSalesforceId: string }>) => {
    // Use CallableRequest and access data/auth from request object
    // 1. Authentication Check
    if (!request.auth) {
      functions.logger.error("Authentication check failed: User is not authenticated.");
      throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated.",
      );
    }

    const resellerSalesforceId: string = request.data.resellerSalesforceId;
    if (!resellerSalesforceId || typeof resellerSalesforceId !== "string") {
      functions.logger.error("Invalid argument: resellerSalesforceId is missing or invalid.", request.data);
      throw new functions.https.HttpsError(
        "invalid-argument",
        "The function must be called with a valid 'resellerSalesforceId' (string).",
      );
    }

    functions.logger.info(`Fetching total commission for reseller: ${resellerSalesforceId}`);

    // 2. Salesforce Connection (Replace with your actual connection logic)
    // IMPORTANT: Use secure methods like Firebase Runtime Config for credentials
    // Assuming process.env is configured via .env files or similar for local dev
    const sfUsername = process.env.SALESFORCE_USERNAME;
    const sfPassword = process.env.SALESFORCE_PASSWORD;
    const sfSecurityToken = process.env.SALESFORCE_SECURITY_TOKEN;
    const sfLoginUrl = process.env.SALESFORCE_LOGIN_URL ?? "https://login.salesforce.com";

    if (!sfUsername || !sfPassword || !sfSecurityToken) {
        functions.logger.error("Salesforce credentials are not configured in environment variables (SALESFORCE_USERNAME, SALESFORCE_PASSWORD, SALESFORCE_SECURITY_TOKEN).");
        throw new functions.https.HttpsError("internal", "Salesforce connection configuration is missing.");
    }

    const conn = new jsforce.Connection({ loginUrl: sfLoginUrl });

    try {
        await conn.login(sfUsername, sfPassword + sfSecurityToken);
        functions.logger.info(`Successfully logged in to Salesforce instance: ${conn.instanceUrl}`);

        // 3. Construct SOQL Query (NEEDS VERIFICATION)
        // IMPORTANT: Verify field API names and relationship paths!
        // IMPORTANT: Validate inputs before inserting into query string!
        const commissionFieldApiName = "Comissao_Retail__c"; // <-- VERIFY THIS
        const statusFieldApiName = "Status__c"; // <-- VERIFY THIS on Proposta__c
        const acceptedStatusValue = "Aceite"; // <-- VERIFY THIS
        // Relationship path from CPE_Proposta__c up to Reseller__c on Oportunidade__c
        const relationshipPathToReseller = "Proposta__r.Oportunidade__r.Reseller__c"; // <-- VERIFY THIS

        // Validate resellerSalesforceId format before using (basic example)
        if (!/^[a-zA-Z0-9]{15,18}$/.test(resellerSalesforceId)) {
          throw new functions.https.HttpsError("invalid-argument", "Invalid reseller Salesforce ID format.");
        }
        // Validate acceptedStatusValue if it comes from input

        const soql = `
            SELECT SUM(${commissionFieldApiName}) totalCommission
            FROM CPE_Proposta__c
            WHERE ${relationshipPathToReseller} = '${resellerSalesforceId}'
            AND Proposta__r.${statusFieldApiName} = '${acceptedStatusValue}'
        `; // Removed conn.escape

        functions.logger.info(`Executing SOQL: ${soql}`);

        // 4. Execute Query
        // Define the type for the AggregateResult more specifically if possible
        const result = await conn.query<{ totalCommission: number | null }>(soql);

        functions.logger.info("SOQL Result:", JSON.stringify(result));

        // 5. Parse Result
        let totalCommission = 0.0;
        if (
            result &&
            result.totalSize > 0 &&
            result.records[0] &&
            result.records[0].totalCommission != null // Access the aggregated field
        ) {
            // Ensure it's treated as a number before assigning
            const rawSum = result.records[0].totalCommission;
            if (typeof rawSum === 'number') {
                totalCommission = rawSum;
            } else {
                functions.logger.warn(`Received non-numeric sum from SOQL: ${rawSum}`);
            }
        }

        functions.logger.info(`Calculated total commission: ${totalCommission}`);

        // 6. Return Success
        return { success: true, totalCommission: totalCommission };

    } catch (error: any) {
        functions.logger.error("Error fetching total commission:", error);
        // Attempt to logout even if query failed
        try {
            await conn.logout();
        } catch (logoutError) {
            functions.logger.error("Salesforce logout failed:", logoutError);
        }
        // Throw an HttpsError for the client
        if (error instanceof functions.https.HttpsError) throw error; // Rethrow if already HttpsError
        throw new functions.https.HttpsError(
            "internal",
            `Failed to fetch total commission: ${error.message}`,
            error
        );
    } finally {
         // Ensure logout happens in success case too if login was successful
         if (conn.accessToken) { // Check if connection was established
            try {
                await conn.logout();
                functions.logger.info("Salesforce logout successful.");
            } catch (logoutError) {
                functions.logger.error("Salesforce logout failed:", logoutError);
            }
        }
    }
  }
); 