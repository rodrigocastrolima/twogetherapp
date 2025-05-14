import axios from 'axios';
import * as logger from "firebase-functions/logger";
import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";

// Interfaces for the request data and the expected Salesforce response
interface RefreshParams {
  refreshToken: string;
}

interface SalesforceRefreshResponse {
  access_token: string;
  instance_url: string;
  id: string;
  token_type: string;
  issued_at: string;
  signature: string;
  // Note: Salesforce often doesn't return refresh_token or expires_in on refresh
}

// Interface for the data returned to the client
interface RefreshResult {
  accessToken: string;
  instanceUrl: string;
  expiresInSeconds: number;
}

// Define constants
// Use the standard Salesforce login URL for token exchange/refresh
const SALESFORCE_TOKEN_ENDPOINT = "https://login.salesforce.com/services/oauth2/token";
const DEFAULT_EXPIRY_SECONDS = 7200; // 2 hours

/**
 * Refreshes a Salesforce access token using a refresh token.
 * Requires the user to be authenticated.
 */
export const refreshSalesforceToken = onCall(
  { enforceAppCheck: false }, // Keep consistent with exchangeSalesforceCode for now
  async (
    request: CallableRequest<RefreshParams>
  ): Promise<RefreshResult> => {
    logger.info("refreshSalesforceToken function called", { structuredData: true });

    // 1. Check Firebase Authentication (Optional but recommended)
    // Uncomment this section if you want to ensure only logged-in Firebase users can refresh.
    /*
    if (!request.auth) {
      logger.error("User is not authenticated.");
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }
    logger.info(`Request received from authenticated user: ${request.auth.uid}`);
    */

    // 2. Validate Input Data
    const { refreshToken } = request.data;
    if (!refreshToken) {
      logger.error("Missing refresh token in request data.");
      throw new HttpsError("invalid-argument", "Refresh token is required.");
    }

    // 3. Load Environment Variables & Validate
    const SALESFORCE_CLIENT_ID = process.env.SALESFORCE_CLIENT_ID;
    const SALESFORCE_CLIENT_SECRET = process.env.SALESFORCE_CLIENT_SECRET; // Secret needed for refresh!

    if (!SALESFORCE_CLIENT_ID) {
      logger.error("Salesforce Client ID is not configured (env var SALESFORCE_CLIENT_ID).");
      throw new HttpsError("internal", "Server configuration error: Salesforce Client ID missing.");
    }
    if (!SALESFORCE_CLIENT_SECRET) {
      logger.error("Salesforce Client Secret is not configured (env var SALESFORCE_CLIENT_SECRET).");
      throw new HttpsError("internal", "Server configuration error: Salesforce Client Secret missing.");
    }

    // 4. Prepare Request to Salesforce Token Endpoint
    const params = new URLSearchParams();
    params.append("grant_type", "refresh_token");
    params.append("refresh_token", refreshToken);
    params.append("client_id", SALESFORCE_CLIENT_ID);
    params.append("client_secret", SALESFORCE_CLIENT_SECRET);

    try {
      // 5. Make POST Request using axios
      logger.info(`Making POST request to Salesforce token endpoint for refresh: ${SALESFORCE_TOKEN_ENDPOINT}`, { structuredData: true });
      const response = await axios.post<SalesforceRefreshResponse>(
        SALESFORCE_TOKEN_ENDPOINT,
        params,
        {
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
          },
          timeout: 15000, // 15 seconds timeout
        }
      );

      // 6. Process Successful Response
      if (
        response.status === 200 &&
        response.data &&
        response.data.access_token &&
        response.data.instance_url
      ) {
        logger.info("Successfully refreshed Salesforce token.", { structuredData: true });

        // Return the new access token, instance URL, and a default expiry
        return {
          accessToken: response.data.access_token,
          instanceUrl: response.data.instance_url,
          expiresInSeconds: DEFAULT_EXPIRY_SECONDS,
        };
      } else {
        // Handle unexpected successful status codes or missing data
        logger.error("Salesforce refresh token response missing required data or had unexpected status.", {
          status: response.status,
          data: response.data,
        });
        throw new HttpsError("internal", "Failed to process Salesforce refresh token response.");
      }
    } catch (error: any) {
      // 7. Handle Errors
      logger.error("Error refreshing Salesforce token:", error);

      // Check if it's an axios error with a response from Salesforce
      if (axios.isAxiosError(error) && error.response) {
        const sfError = error.response.data?.error;
        const sfErrorDesc = error.response.data?.error_description;
        logger.error("Salesforce error response during refresh:", {
          status: error.response.status,
          data: error.response.data,
        });

        // Specific check for invalid refresh token
        if (sfError === "invalid_grant") {
          logger.warn("Invalid refresh token provided. User needs to re-authenticate.", { refreshTokenUsed: refreshToken.substring(0, 10) + "..." }); // Log part of token for correlation
          // Signal to the client that re-authentication is required
          throw new HttpsError(
            "unauthenticated", // Use unauthenticated to signal re-login needed
            `Salesforce refresh failed: ${sfErrorDesc || sfError}`,
            { salesforceError: sfError } // Send SF error code in details
          );
        }

        // Throw a general Salesforce error for other cases
        throw new HttpsError(
          "failed-precondition", // Or internal
          `Salesforce refresh failed: ${sfErrorDesc || sfError || "Unknown Salesforce error"}`,
          error.response.data // Optional details
        );
      } else {
        // Handle other errors (network issues, config problems, timeouts, etc.)
        throw new HttpsError("internal", `An unexpected error occurred during token refresh: ${error.message || error}`);
      }
    }
    // --- End Implementation Steps ---

    // Remove Placeholder return - Now handled above
    /*
    return {
        newAccessToken: "placeholder_access_token",
        newInstanceUrl: "placeholder_instance_url",
        newExpiresInSeconds: DEFAULT_EXPIRY_SECONDS,
    };
    */
  }
); 