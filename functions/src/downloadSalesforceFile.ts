import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import axios from "axios"; // Using axios for simpler HTTP requests with binary data handling

// --- Interfaces ---
interface DownloadFileParams {
  contentVersionId: string;
  accessToken: string;
  instanceUrl: string;
  // Optional: Add filename if needed for Content-Disposition, but we get it from SF
}

// We're not returning structured JSON here, but raw file data.
// The return type in the function signature reflects this,
// but the actual response is handled manually using the raw Express response object.

// --- Cloud Function Definition ---

export const downloadSalesforceFile = onCall(
  {
    timeoutSeconds: 60, // Adjust timeout as needed for potentially large files
    memory: "512MiB",   // Increase memory if handling large files
    // enforceAppCheck: true, // Recommended for production
    // We need access to the raw response object to stream binary data/set headers
    invoker: "public", // Allows direct HTTPS calls from Flutter if needed, but usually called via SDK
    // Or keep default and use callable SDK, ensuring binary data is handled correctly (base64?)
  },
  async (request: CallableRequest<DownloadFileParams>) => {
    // NOTE: If using Callable SDK, request.data contains the params.
    // If making a direct HTTPS request, check query/body based on method.
    // Assuming CallableRequest usage for consistency.

    logger.info("downloadSalesforceFile function triggered");

    // 1. Authentication Check (Firebase Auth) - Standard for Callables
    if (!request.auth) {
      logger.error("Authentication failed: User is not authenticated.");
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = request.auth.uid;
    logger.info("Firebase Authentication check passed.", { uid });

    // 2. Input Validation
    const { contentVersionId, accessToken, instanceUrl } = request.data;
    if (!contentVersionId) {
      logger.error("Validation failed: Missing contentVersionId");
      throw new HttpsError("invalid-argument", "Missing contentVersionId");
    }
    if (!accessToken) {
      logger.error("Validation failed: Missing accessToken");
      throw new HttpsError("invalid-argument", "Missing accessToken");
    }
    if (!instanceUrl) {
      logger.error("Validation failed: Missing instanceUrl");
      throw new HttpsError("invalid-argument", "Missing instanceUrl");
    }
    logger.info("Input validation passed.", { contentVersionId });

    // 3. Construct Salesforce API URL
    // Determine API version dynamically or use a fixed one (e.g., v58.0)
    // For simplicity, using a common recent version. Check jsforce connection version if available elsewhere.
    const apiVersion = "58.0"; // Or determine dynamically if possible
    const salesforceUrl = `${instanceUrl}/services/data/v${apiVersion}/sobjects/ContentVersion/${contentVersionId}/VersionData`;
    logger.info("Constructed Salesforce URL.", { url: salesforceUrl });

    try {
      // 4. Call Salesforce API using axios
      logger.info("Making request to Salesforce...");
      const response = await axios.get(salesforceUrl, {
        headers: {
          // Crucial: Pass the Salesforce access token
          'Authorization': `Bearer ${accessToken}`,
          // Optional: Add other headers if necessary
        },
        responseType: 'arraybuffer' // Important: Get the response as raw bytes
      });

      logger.info("Successfully received response from Salesforce.", { status: response.status });

      // 5. Prepare response for Flutter App
      // Get headers from Salesforce response
      const contentType = response.headers['content-type'] || 'application/octet-stream'; // Default if missing
      const contentDisposition = response.headers['content-disposition']; // For filename

      // Log received headers
      logger.debug("Received Salesforce headers:", { contentType, contentDisposition });

      // Firebase Functions v2 Callables expect a JSON-serializable return value.
      // Returning raw binary data directly isn't standard for 'onCall'.
      // We need to encode the binary data, Base64 is common.
      const fileData = Buffer.from(response.data).toString('base64');

      logger.info("Encoded file data to Base64.");

      // Return data structured for the Callable SDK
      return {
        success: true,
        data: {
          fileData: fileData, // Base64 encoded file data
          contentType: contentType,
        }
      };

    } catch (error: any) {
      logger.error("Error during Salesforce API call or processing:", error);

      // Handle Salesforce session errors specifically if possible (check error structure)
      if (axios.isAxiosError(error) && error.response) {
        logger.error("Salesforce API Error Details:", {
            status: error.response.status,
            headers: error.response.headers,
            data: error.response.data ? Buffer.from(error.response.data).toString() : 'No data', // Try to log error body
        });
        // Check for specific Salesforce error codes if available in the response body
        // e.g., if error.response.data contains XML/JSON with error codes
        if (error.response.status === 401 || error.response.status === 403) {
           throw new HttpsError('unauthenticated', 'Salesforce session invalid or expired when fetching file.', { sessionExpired: true });
        }
         throw new HttpsError('internal', `Salesforce API request failed with status ${error.response.status}`);
      } else if (error instanceof HttpsError) {
         // Rethrow HttpsErrors (e.g., from initial validation)
         throw error;
      } else {
        // Generic internal error
        throw new HttpsError("internal", "An unexpected error occurred while downloading the file.", error.message);
      }
    }
  }
); 