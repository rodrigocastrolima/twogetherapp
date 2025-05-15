import * as functions from "firebase-functions/v2";
import * as jsforce from "jsforce";
import * as jwt from 'jsonwebtoken';
import axios from 'axios';

export const getResellerDashboardStats = functions.https.onCall(
  { region: "europe-west1" },
  async (request: functions.https.CallableRequest<{ resellerSalesforceId: string }>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }

    const resellerSalesforceId: string = request.data.resellerSalesforceId;
    if (!resellerSalesforceId || typeof resellerSalesforceId !== "string") {
      throw new functions.https.HttpsError("invalid-argument", "Missing or invalid resellerSalesforceId.");
    }

    // Salesforce connection setup (same as your other functions)
    const privateKey = process.env.SALESFORCE_PRIVATE_KEY?.replace(/\\n/g, '\n');
    const consumerKey = process.env.SALESFORCE_CONSUMER_KEY;
    const salesforceUsername = process.env.SALESFORCE_USERNAME;

    if (!privateKey || !consumerKey || !salesforceUsername) {
      throw new functions.https.HttpsError("internal", "Salesforce connection configuration is missing.");
    }

    let conn: jsforce.Connection;

    try {
      // JWT Auth
      const tokenEndpoint = "https://login.salesforce.com/services/oauth2/token";
      const audience = "https://login.salesforce.com";
      const claim = {
        iss: consumerKey,
        sub: salesforceUsername,
        aud: audience,
        exp: Math.floor(Date.now() / 1000) + (3 * 60),
      };
      const token = jwt.sign(claim, privateKey, { algorithm: 'RS256' });

      const tokenResponse = await axios.post(tokenEndpoint, new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: token,
      }).toString(), {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      });

      const { access_token, instance_url } = tokenResponse.data;
      if (!access_token || !instance_url) {
        throw new functions.https.HttpsError('internal', 'Salesforce JWT authentication failed.');
      }

      conn = new jsforce.Connection({
        instanceUrl: instance_url,
        accessToken: access_token,
      });

      // --- Query 1: Opportunity Count ---
      const opportunityCountSOQL = `
        SELECT COUNT()
        FROM Oportunidade__c
        WHERE Agente_Retail__c = '${resellerSalesforceId}'
      `;
      const opportunityCountResult = await conn.query<{ totalSize: number }>(opportunityCountSOQL);

      // --- Query 2: Commission per Proposal (with Opportunity Name) ---
      const commissionPerProposalSOQL = `
        SELECT Proposta_CPE__r.Id, Proposta_CPE__r.Oportunidade__r.Nome_Entidade__c, SUM(Comiss_o_Retail__c) totalCommission
        FROM CPE_Proposta__c
        WHERE Proposta_CPE__r.Oportunidade__r.Agente_Retail__c = '${resellerSalesforceId}'
          AND Proposta_CPE__r.Status__c = 'Aceite'
        GROUP BY Proposta_CPE__r.Id, Proposta_CPE__r.Oportunidade__r.Nome_Entidade__c
      `;
      const commissionResult = await conn.query<any>(commissionPerProposalSOQL);

      const proposals = (commissionResult.records || []).map((rec: any) => ({
        id: rec.Proposta_CPE__r.Id,
        opportunityName: rec.Proposta_CPE__r.Oportunidade__r.Nome_Entidade__c || rec.Proposta_CPE__r.Oportunidade__r.Name,
        totalCommission: rec.totalCommission || 0,
      }));

      return {
        success: true,
        opportunityCount: opportunityCountResult.totalSize || 0,
        proposals,
      };
    } catch (error: any) {
      throw new functions.https.HttpsError(
        "internal",
        `Failed to fetch dashboard stats: ${error.message || error}`,
        error
      );
    }
  }
); 