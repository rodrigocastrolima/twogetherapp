import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as jsforce from "jsforce";
import * as jwt from 'jsonwebtoken';
import axios from 'axios';

export const getResellerDashboardStats = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }

    const resellerSalesforceId: string = request.data.resellerSalesforceId;
    if (!resellerSalesforceId || typeof resellerSalesforceId !== "string") {
      throw new HttpsError("invalid-argument", "Missing or invalid resellerSalesforceId.");
    }

    // Basic check for Salesforce ID format (15 or 18 chars, alphanumeric)
    if (!/^[a-zA-Z0-9]{15,18}$/.test(resellerSalesforceId)) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid Salesforce ID format provided."
      );
    }

    // Salesforce connection setup
    const privateKey = process.env.SALESFORCE_PRIVATE_KEY?.replace(/\\n/g, '\n');
    const consumerKey = process.env.SALESFORCE_CONSUMER_KEY;
    const salesforceUsername = process.env.SALESFORCE_USERNAME;

    if (!privateKey || !consumerKey || !salesforceUsername) {
      throw new HttpsError("internal", "Salesforce connection configuration is missing.");
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
        throw new HttpsError('internal', 'Salesforce JWT authentication failed.');
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

      // --- Query 2: Commission per Proposal ---
      const commissionSOQL = `
        SELECT 
          Proposta_CPE__r.Id,
          SUM(Comiss_o_Retail__c) totalCommission
        FROM CPE_Proposta__c
        WHERE Proposta_CPE__r.Oportunidade__r.Agente_Retail__c = '${resellerSalesforceId}'
          AND Proposta_CPE__r.Status__c = 'Aceite'
        GROUP BY Proposta_CPE__r.Id
      `;
      const commissionResult = await conn.query<any>(commissionSOQL);
      
      logger.info('Commission result:', JSON.stringify(commissionResult.records[0], null, 2));

      // Get proposal details
      const proposalIds = commissionResult.records.map((rec: any) => rec.Id);
      const proposalDetailsSOQL = `
        SELECT 
          Id,
          Name,
          Oportunidade__r.Id,
          Oportunidade__r.Nome_Entidade__c
        FROM Proposta__c
        WHERE Id IN ('${proposalIds.join("','")}')
      `;
      const proposalDetailsResult = await conn.query<any>(proposalDetailsSOQL);

      // Create a map of proposal details
      const proposalDetailsMap = new Map();
      proposalDetailsResult.records.forEach((rec: any) => {
        proposalDetailsMap.set(rec.Id, rec);
      });

      // Get opportunity names for fallback
      const opportunityIds = [...new Set(proposalDetailsResult.records.map((rec: any) => rec.Oportunidade__r.Id))];
      const opportunityNames = new Map();
      
      if (opportunityIds.length > 0) {
        const opportunityQuery = `
          SELECT Id, Name
          FROM Oportunidade__c
          WHERE Id IN ('${opportunityIds.join("','")}')
        `;
        const opportunityResult = await conn.query<any>(opportunityQuery);
        opportunityResult.records.forEach((opp: any) => {
          opportunityNames.set(opp.Id, opp.Name);
        });
      }

      const proposals = (commissionResult.records || []).map((rec: any) => {
        const details = proposalDetailsMap.get(rec.Id);
        return {
          id: rec.Id,
          name: details?.Name,
          opportunityName: details?.Oportunidade__r.Nome_Entidade__c || opportunityNames.get(details?.Oportunidade__r.Id),
          totalCommission: rec.totalCommission || 0,
        };
      });

      return {
        success: true,
        opportunityCount: opportunityCountResult.totalSize || 0,
        proposals,
      };
    } catch (error: any) {
      logger.error("Error fetching dashboard stats:", error);
      throw new HttpsError(
        "internal",
        `Failed to fetch dashboard stats: ${error.message || error}`,
        error
      );
    }
  }
); 