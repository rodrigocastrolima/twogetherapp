import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import axios from "axios"; // Using axios for simpler HTTP requests with binary data handling
import * as jsforce from 'jsforce'; // <-- Import jsforce

// --- Interfaces ---
interface DownloadFileParams {
  contentVersionId: string;
  accessToken: string;
  instanceUrl: string;
  // Optional: Add filename if needed for Content-Disposition, but we get it from SF
}

// Interface for the data returned to Flutter
interface DownloadedFileData {
    fileData: string; // Base64 encoded
    contentType: string; // From response header
    fileExtension: string | null; // <-- ADDED: From SF record
}

// Interface for the overall function result
interface DownloadFileResult {
    success: boolean;
    data?: DownloadedFileData;
    error?: string;
    errorCode?: string;
    sessionExpired?: boolean;
}

// We're not returning structured JSON here, but raw file data.
// The return type in the function signature reflects this,
// but the actual response is handled manually using the raw Express response object.

// --- Cloud Function Definition ---

export const downloadSalesforceFile = onCall(
  {
    timeoutSeconds: 120, // Allow time for download
    memory: "512MiB", // May need adjustment based on file sizes
    region: "us-central1",
    // enforceAppCheck: true, // Recommended for production
    // We need access to the raw response object to stream binary data/set headers
    invoker: "public", // Allows direct HTTPS calls from Flutter if needed, but usually called via SDK
    // Or keep default and use callable SDK, ensuring binary data is handled correctly (base64?)
  },
  async (request: CallableRequest<DownloadFileParams>): Promise<DownloadFileResult> => {
    const functionName = "downloadSalesforceFile";
    logger.info(`${functionName} function triggered`);

    // 1. Authentication Check (Firebase Auth)
    if (!request.auth) {
      logger.error(`${functionName}: Authentication failed: User is not authenticated.`);
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    logger.info(`${functionName}: Firebase Authentication check passed.`, { uid: request.auth.uid });

    // 2. Input Validation
    const { contentVersionId, accessToken, instanceUrl } = request.data;
    if (!contentVersionId || !accessToken || !instanceUrl) {
      logger.error(`${functionName}: Validation failed: Missing required parameters.`);
      throw new HttpsError("invalid-argument", "Missing contentVersionId, accessToken, or instanceUrl");
    }
    logger.info(`${functionName}: Input validation passed.`, { contentVersionId });

    let conn: jsforce.Connection;

    try {
      // 3. Connect to Salesforce using provided credentials
      conn = new jsforce.Connection({ instanceUrl, accessToken });
      logger.info(`${functionName}: Salesforce connection initialized.`);

      // 4. Query ContentVersion for FileExtension
      logger.info(`${functionName}: Querying ContentVersion for FileExtension...`);
      let fileExtension: string | null = null;
      try {
        // Retrieve the full record by ID
        const cvRecord = await conn.sobject('ContentVersion').retrieve(contentVersionId);
        // Access the FileExtension property from the result
        if (cvRecord && typeof cvRecord.FileExtension === 'string') {
          fileExtension = cvRecord.FileExtension;
          logger.info(`${functionName}: Retrieved FileExtension: ${fileExtension}`);
        } else {
          logger.warn(`${functionName}: Could not retrieve FileExtension for ${contentVersionId}. Record: ${JSON.stringify(cvRecord)}`);
        }
      } catch (queryError: any) {
         // Log error but don't fail the whole function, just proceed without extension
         logger.error(`${functionName}: Error querying FileExtension for ${contentVersionId}:`, queryError);
         if (queryError.errorCode === 'NOT_FOUND') {
            throw new HttpsError('not-found', `ContentVersion with ID ${contentVersionId} not found.`);
         } // Other errors might indicate permission issues but we try downloading anyway
      }

      // 5. Construct Salesforce API URL for raw data
      const apiVersion = conn.version; // Use connected API version
      const salesforceUrl = `${instanceUrl}/services/data/v${apiVersion}/sobjects/ContentVersion/${contentVersionId}/VersionData`;
      logger.info(`${functionName}: Constructed Salesforce URL for VersionData.`, { url: salesforceUrl });

      // 6. Call Salesforce API using axios for binary data
      logger.info(`${functionName}: Making request to Salesforce for VersionData...`);
      const response = await axios.get(salesforceUrl, {
        headers: { 'Authorization': `Bearer ${accessToken}` },
        responseType: 'arraybuffer'
      });

      logger.info(`${functionName}: Successfully received VersionData response from Salesforce.`, { status: response.status });

      // 7. Prepare response for Flutter App
      const contentType = response.headers['content-type'] || 'application/octet-stream';
      const fileData = Buffer.from(response.data).toString('base64');
      logger.info(`${functionName}: Encoded file data to Base64.`);

      return {
        success: true,
        data: {
          fileData: fileData,
          contentType: contentType,
          fileExtension: fileExtension, // <-- Include fileExtension
        }
      };

    } catch (error: any) {
      logger.error(`${functionName}: Error during execution:`, error);

      if (error instanceof HttpsError) { 
        throw error; 
      }

      // Handle specific errors like session expiry
      if (error.name === 'invalid_grant' || error.errorCode === 'INVALID_SESSION_ID') {
          logger.warn(`${functionName}: Detected invalid session ID or grant error.`);
          throw new HttpsError('unauthenticated', 'Salesforce session expired or invalid.', { sessionExpired: true });
      }
       if (axios.isAxiosError(error) && error.response) {
        logger.error(`${functionName}: Salesforce API Error Details:`, {
            status: error.response.status,
            data: error.response.data ? Buffer.from(error.response.data).toString() : 'No data', 
        });
        if (error.response.status === 401 || error.response.status === 403) {
           throw new HttpsError('unauthenticated', 'Salesforce session invalid or expired when fetching file.', { sessionExpired: true });
        }
         throw new HttpsError('internal', `Salesforce API request failed with status ${error.response.status}`);
      } else {
        throw new HttpsError("internal", `An unexpected error occurred: ${error.message || 'Unknown error'}`);
      }
    }
  }
); 