import axios from 'axios';
// import * as functions from "firebase-functions";
import * as logger from "firebase-functions/logger";
import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";

// Define interfaces for Salesforce token response and the expected input data
interface SalesforceTokenResponse {
  access_token: string;
  instance_url: string;
  id: string;
  token_type: string;
  issued_at: string;
  signature: string;
  refresh_token?: string; // Make refresh_token optional
  expires_in?: number; // Also make expires_in optional if needed later
  // Potentially others like scope
}

interface ExchangeCodeData {
  code: string;
  verifier: string;
}

// Define constants that don't rely on config
const SALESFORCE_TOKEN_ENDPOINT = "https://ldfgrupo.my.salesforce.com/services/oauth2/token";

/**
 * Exchanges a Salesforce authorization code and PKCE verifier for tokens.
 * Returns access token, instance URL, refresh token, and expiry time.
 */
export const exchangeSalesforceCode = onCall(
  { enforceAppCheck: false }, 
  async (
    request: CallableRequest<ExchangeCodeData>
  ): Promise<{
    accessToken: string;
    instanceUrl: string;
    refreshToken: string;
    expiresInSeconds: number; // Add expires_in
  }> => {
    logger.info("exchangeSalesforceCode function called", { structuredData: true });

    // Load configuration from environment variables (v2 style)
    const SALESFORCE_CLIENT_ID = process.env.SALESFORCE_CLIENT_ID;
    const SALESFORCE_WEB_REDIRECT_URI = process.env.SALESFORCE_WEB_REDIRECT_URI || "http://localhost:5000/#/callback"; // Keep fallback ONLY for local testing if needed

    // Check for configuration errors first
    if (!SALESFORCE_CLIENT_ID) {
      logger.error("Salesforce Client ID is not configured in Firebase environment variables (process.env.SALESFORCE_CLIENT_ID).");
      throw new HttpsError("internal", "Server configuration error: Salesforce Client ID missing.");
    }
    // Be stricter with redirect URI check in production
    if (!SALESFORCE_WEB_REDIRECT_URI || (/*process.env.NODE_ENV === 'production' &&*/ SALESFORCE_WEB_REDIRECT_URI === "http://localhost:5000/#/callback")) {
        if (SALESFORCE_WEB_REDIRECT_URI === "http://localhost:5000/#/callback") {
             logger.warn("Using default localhost redirect URI. Ensure SALESFORCE_WEB_REDIRECT_URI env var is set correctly in production.");
             /* // Temporarily disable this check for local testing against deployed function
             if (process.env.NODE_ENV === 'production') { 
                 throw new HttpsError("internal", "Server configuration error: Default localhost Redirect URI used in production.");
             }
             */
        } else {
             logger.error("Salesforce Web Redirect URI is not configured in Firebase environment variables (process.env.SALESFORCE_WEB_REDIRECT_URI).");
             throw new HttpsError("internal", "Server configuration error: Salesforce Web Redirect URI missing.");
        }
    }

    // 1. Validate Input Data from request.data
    const { code, verifier } = request.data; 
    if (!code || !verifier) {
      logger.error("Missing authorization code or PKCE verifier in request data.");
      throw new HttpsError("invalid-argument", "Authorization code and PKCE verifier are required.");
    }

    // 2. Prepare Request to Salesforce Token Endpoint
    const params = new URLSearchParams();
    params.append("grant_type", "authorization_code");
    params.append("code", code);
    params.append("client_id", SALESFORCE_CLIENT_ID); // Now uses env var
    params.append("redirect_uri", SALESFORCE_WEB_REDIRECT_URI); // Now uses env var
    params.append("code_verifier", verifier);

    try {
      // 3. Make POST Request using axios
      logger.info(`Making POST request to Salesforce token endpoint: ${SALESFORCE_TOKEN_ENDPOINT}`, { structuredData: true });
      const response = await axios.post<SalesforceTokenResponse>(
        SALESFORCE_TOKEN_ENDPOINT,
        params,
        {
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
          },
          // Consider adding a timeout
          // timeout: 10000, // 10 seconds
        }
      );

      // 4. Process Successful Response
      if (
        response.status === 200 &&
        response.data &&
        response.data.access_token &&
        response.data.instance_url
      ) {
        logger.info("Successfully exchanged code for tokens.", { structuredData: true });

        const refreshToken = response.data.refresh_token;
        if (!refreshToken) {
          logger.warn("Salesforce token response did not include a refresh_token. Check Connected App settings (ensure 'refresh_token' scope is included and refresh policy is set).");
          // Decide how to handle missing refresh token: throw error or return empty/null?
          // Throwing error might be better to alert the client.
          throw new HttpsError("internal", "Salesforce did not provide a refresh token.");
        }

        const expiresIn = response.data.expires_in;
        if (typeof expiresIn !== 'number' || expiresIn <= 0) {
           logger.warn(`Salesforce token response missing or invalid expires_in value: ${expiresIn}. Using default.`);
           // Provide a default or throw error? Defaulting to 2 hours for safety.
           // throw new HttpsError("internal", "Salesforce did not provide a valid expires_in value."); 
           // Defaulting might be safer for client handling
            response.data.expires_in = 7200; // 2 hours in seconds
        }

        // Update return object to include refresh token and expiry
        return {
          accessToken: response.data.access_token,
          instanceUrl: response.data.instance_url,
          refreshToken: refreshToken,
          expiresInSeconds: response.data.expires_in!, // Use non-null assertion after check/default
        };
      } else {
        // Handle unexpected successful status codes or missing data
        logger.error("Salesforce token response missing required data or had unexpected status.", {
          status: response.status,
          data: response.data,
        });
        throw new HttpsError("internal", "Failed to process Salesforce token response.");
      }
    } catch (error: any) {
      // 5. Handle Errors
      logger.error("Error exchanging Salesforce code for tokens:", error);

      // Check if it's an axios error with a response from Salesforce
      if (axios.isAxiosError(error) && error.response) {
        logger.error("Salesforce error response:", {
          status: error.response.status,
          data: error.response.data,
        });
        // Throw a more specific error back to the client
        throw new HttpsError(
          "failed-precondition", // Or a more appropriate code
          `Salesforce token exchange failed: ${error.response.data?.error_description || error.response.data?.error || "Unknown Salesforce error"}`,
          error.response.data // Optional details
        );
      } else {
        // Handle other errors (network issues, config problems, etc.)
        throw new HttpsError("internal", `An unexpected error occurred: ${error.message || error}`);
      }
    }
  }
); 