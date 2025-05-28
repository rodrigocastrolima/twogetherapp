import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as jsforce from 'jsforce';
import * as jwt from 'jsonwebtoken';
import axios from 'axios';

// --- Interfaces ---
interface DownloadFileForResellerParams {
  contentVersionId: string;
}
//note
// Structure for the response data sent back to Flutter
interface FileDownloadData {
  fileData: string; // Base64 encoded
  contentType: string;
  fileExtension: string | null;
}

interface DownloadFileForResellerResult {
    success: boolean;
    data?: FileDownloadData;
    error?: string;
}


// --- Helper Function for JWT Connection (Copied from getResellerProposalDetails) ---
// TODO: Consider moving this to a shared utility file
async function getSalesforceConnection(): Promise<jsforce.Connection> {
    const functionName = "downloadFileForReseller"; // Logging context
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
    try {
        const tokenResponse = await axios.post(tokenEndpoint, new URLSearchParams({
            grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            assertion: token
        }).toString(), {
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
        });

        const { access_token, instance_url } = tokenResponse.data;

        if (!access_token || !instance_url) {
            logger.error(`${functionName}: Failed to retrieve access token or instance URL.`, { responseData: tokenResponse.data });
            throw new HttpsError('internal', 'Salesforce JWT authentication failed: Missing token/URL.');
        }
        logger.info(`${functionName}: Salesforce JWT authentication successful.`);
        return new jsforce.Connection({ instanceUrl: instance_url, accessToken: access_token });

    } catch (error: any) {
         logger.error(`${functionName}: Error during Salesforce JWT token request:`, { error: error.message, response: error.response?.data });
         if (axios.isAxiosError(error) && error.response?.data) {
             const sfError = error.response.data.error;
             const sfErrorDesc = error.response.data.error_description;
             throw new HttpsError('internal', `Salesforce auth error: ${sfError} - ${sfErrorDesc}`);
         }
         throw new HttpsError('internal', `Failed to authenticate with Salesforce via JWT: ${error.message}`);
    }
}


// --- Cloud Function Definition ---
export const downloadFileForReseller = onCall(
  {
    region: "us-central1",
    // Add other options like timeout, memory if needed
    // enforceAppCheck: true, // Recommended for production
  },
  async (request: CallableRequest<DownloadFileForResellerParams>): Promise<DownloadFileForResellerResult> => {
    const functionName = "downloadFileForReseller";
    logger.info(`${functionName} function triggered`);

    // 1. Authentication Check (Firebase Auth)
    if (!request.auth) {
      logger.error(`${functionName}: Authentication failed: User is not authenticated.`);
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = request.auth.uid;
    // TODO: Optionally add role check if needed, e.g., ensure user is a reseller
    logger.info(`${functionName}: Firebase Authentication check passed.`, { uid });

    // 2. Input Validation
    const { contentVersionId } = request.data;
    if (!contentVersionId || typeof contentVersionId !== 'string' || !/^[a-zA-Z0-9]{18}$/.test(contentVersionId)) {
      logger.error(`${functionName}: Validation failed: Missing or invalid contentVersionId`);
      throw new HttpsError("invalid-argument", "Missing or invalid contentVersionId");
    }
    logger.info(`${functionName}: Input validation passed.`, { contentVersionId });

    let conn: jsforce.Connection;
    try {
      // 3. Get Salesforce Connection using JWT
      logger.info(`${functionName}: Attempting internal Salesforce JWT authentication...`);
      conn = await getSalesforceConnection();
      logger.info(`${functionName}: Internal Salesforce connection successful.`);

      // 4. Query ContentVersion for FileExtension (same as admin version)
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

      // 5. Construct Salesforce API URL for VersionData
      // Use the connection's version and instance URL
      const apiVersion = conn.version;
      const instanceUrl = conn.instanceUrl;
      const salesforceUrl = `${instanceUrl}/services/data/v${apiVersion}/sobjects/ContentVersion/${contentVersionId}/VersionData`;
      logger.info(`${functionName}: Constructed Salesforce URL.`, { url: salesforceUrl });

      // 6. Call Salesforce API using axios with the JWT token
      logger.info(`${functionName}: Making request to Salesforce for file content...`);
      const response = await axios.get(salesforceUrl, {
        headers: {
          'Authorization': `Bearer ${conn.accessToken}`, // Use token from JWT connection
        },
        responseType: 'arraybuffer' // Get raw bytes
      });

      logger.info(`${functionName}: Successfully received response from Salesforce.`, { status: response.status });

      // 7. Prepare response for Flutter App
      const contentType = response.headers['content-type'] || 'application/octet-stream';
      const fileData = Buffer.from(response.data).toString('base64');
      logger.info(`${functionName}: Encoded file data to Base64.`, { contentType });

      return {
        success: true,
        data: {
          fileData: fileData,
          contentType: contentType,
          fileExtension: fileExtension,
        }
      };

    } catch (error: any) {
      logger.error(`${functionName}: Error during execution:`, error);

      if (error instanceof HttpsError) {
        // Re-throw known errors (auth, invalid args, JWT helper errors)
        throw error;
      } else if (axios.isAxiosError(error)) {
        // Handle errors from the axios call to Salesforce
        let errorMessage = `${functionName}: Salesforce API request failed: ${error.message}`;
        let sfErrorCode = "SF_API_REQUEST_FAILED";
        if (error.response?.data) {
            // Attempt to parse Salesforce error details if available (might be JSON or text)
             let sfErrorDetails = '';
            try {
                // Assuming error details might be in response data (often an array of objects)
                 if (Array.isArray(error.response.data) && error.response.data.length > 0) {
                     sfErrorDetails = error.response.data.map((e: any) => `${e.errorCode}: ${e.message}`).join('; ');
                     sfErrorCode = error.response.data[0].errorCode || sfErrorCode;
                 } else if (typeof error.response.data === 'object') {
                     sfErrorDetails = JSON.stringify(error.response.data);
                 } else {
                      sfErrorDetails = error.response.data.toString();
                 }
            } catch (parseErr) {
                 sfErrorDetails = 'Could not parse SF error response.';
            }
             logger.error(`${functionName}: Salesforce API Error Response:`, { status: error.response?.status, data: sfErrorDetails });
            errorMessage += ` - ${sfErrorDetails}`;
        }
         throw new HttpsError('internal', errorMessage, { errorCode: sfErrorCode });
      } else {
        // Generic internal error
        throw new HttpsError('internal', `${functionName}: An unknown error occurred. ${error.message || ''}`);
      }
    }
  }
); 