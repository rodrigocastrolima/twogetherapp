import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as jsforce from "jsforce";

// Ensure Firebase Admin SDK is initialized
try {
  if (admin.apps.length === 0) {
      admin.initializeApp();
      logger.info("Firebase Admin SDK initialized in salesforceFileManagement.");
  }
} catch (e) {
  logger.info("Firebase Admin SDK already initialized.");
}

// --- Interfaces for Upload ---
interface UploadFileParams {
  parentId: string; // e.g., Opportunity ID
  fileName: string;
  fileContentBase64: string;
  mimeType?: string; // Optional, assists Salesforce
  accessToken: string;
  instanceUrl: string;
}

interface UploadFileResult {
  success: boolean;
  contentVersionId?: string;
  contentDocumentId?: string; // Often useful to return this too
  error?: string;
  sessionExpired?: boolean;
}

// --- Interfaces for Delete ---
interface DeleteFileParams {
  contentDocumentId: string;
  accessToken: string;
  instanceUrl: string;
}

interface DeleteFileResult {
  success: boolean;
  error?: string;
  sessionExpired?: boolean;
}

// --- Upload Function --- 
export const uploadSalesforceFile = onCall(
  {
    timeoutSeconds: 120, // Increased timeout for potential large uploads
    memory: "512MiB", // Increased memory for base64 handling
    // enforceAppCheck: true,
  },
  async (request: CallableRequest<UploadFileParams>): Promise<UploadFileResult> => {
    logger.info("uploadSalesforceFile function triggered", { params: { parentId: request.data.parentId, fileName: request.data.fileName, mimeType: request.data.mimeType } });

    // 1. Auth Check
    if (!request.auth) {
      logger.error("UploadFile: Auth failed");
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = request.auth.uid;

    // 2. Input Validation
    const { parentId, fileName, fileContentBase64, mimeType, accessToken, instanceUrl } = request.data;
    if (!parentId || !fileName || !fileContentBase64 || !accessToken || !instanceUrl) {
      logger.error("UploadFile: Validation failed - Missing required fields", { parentId: !!parentId, fileName: !!fileName, fileContentBase64: !!fileContentBase64, accessToken: !!accessToken, instanceUrl: !!instanceUrl });
      throw new HttpsError("invalid-argument", "Missing required fields for file upload.");
    }
    logger.info("UploadFile: Input validation passed.", { uid, parentId });

    try {
      // 3. Salesforce Connection
      const conn = new jsforce.Connection({ instanceUrl, accessToken });
      logger.info("UploadFile: Salesforce connection initialized.");

      // 4. Authorization (Example: Basic admin check - refine as needed)
      // You might want to check if the user has access to the parentId record
      try {
        const userDoc = await admin.firestore().collection('users').doc(uid).get();
        if (userDoc.data()?.role !== 'admin') { 
          // TODO: Add check if user has write access to parentId record
          logger.error("UploadFile: Authorization failed - User not admin", { uid });
          throw new HttpsError("permission-denied", "User does not have permission to upload files here.");
        }
        logger.info("UploadFile: Authorization check passed.", { uid });
      } catch (authError: any) {
        logger.error("UploadFile: Error during authorization check", { uid, error: authError });
        throw new HttpsError("internal", "Failed to verify user permissions.");
      }

      // 5. Create ContentVersion
      logger.info("Attempting to create ContentVersion...", { parentId, fileName });
      const cvData = {
        Title: fileName,
        PathOnClient: fileName,
        VersionData: fileContentBase64,
        FirstPublishLocationId: parentId, // Link to the Opportunity/Parent
        // Origin: 'H' // C = Content Origin, H = Chatter Origin - Typically H for Files
        // SharingOption: 'A' // A = Allowed, R = Restricted (defaults based on org settings)
        // SharingPrivacy: 'N' // N = Network, P = Private, E = PubliclyAvailable (defaults based on org settings)
      };
      if (mimeType) {
        // Add MIME type if provided - helps Salesforce display correctly
        // cvData.MimeType = mimeType; // Not a direct field on ContentVersion, SF infers it.
      }

      const result: any = await conn.sobject('ContentVersion').create(cvData);
      logger.debug("ContentVersion Create Result:", { result });

      // 6. Process Result
      if (result.success) {
        const contentVersionId = result.id;
        logger.info("Successfully created ContentVersion.", { parentId, fileName, contentVersionId });
        
        // Optionally query ContentDocumentId immediately
        let contentDocumentId: string | undefined;
        try {
            // Assert type to 'any' to handle potential jsforce type inference issues for single record retrieve
            const cv: any = await conn.sobject('ContentVersion').retrieve(contentVersionId);
            contentDocumentId = cv.ContentDocumentId; // Access directly now
            logger.info("Retrieved ContentDocumentId for new ContentVersion.", { contentDocumentId });
        } catch (cdIdError) {
            logger.warn("Could not retrieve ContentDocumentId immediately after upload.", { contentVersionId, error: cdIdError });
        }

        return { success: true, contentVersionId, contentDocumentId };
      } else {
        const errors = result.errors || ["Unknown ContentVersion creation error"];
        const errorMessage = errors.map((e: any) => (typeof e === 'string') ? e : `${e.statusCode}: ${e.message}`).join('; ');
        logger.error("Failed to create ContentVersion.", { parentId, fileName, errors: result.errors });
        throw new HttpsError("internal", `Salesforce file upload failed: ${errorMessage}`);
      }

    } catch (error: any) {
      logger.error("Error in uploadSalesforceFile main try block:", error);
      if (error instanceof HttpsError) { throw error; }
      if (error.name === 'invalid_grant' || error.errorCode === 'INVALID_SESSION_ID') {
        logger.warn('UploadFile: Detected invalid session ID or grant error.');
        throw new HttpsError('unauthenticated', 'Salesforce session expired or invalid.', { sessionExpired: true });
      }
      if (error.name === 'REQUEST_LIMIT_EXCEEDED') {
        logger.error("UploadFile: Salesforce API limit exceeded.");
        throw new HttpsError('resource-exhausted', 'Salesforce API limit exceeded.');
      } 
      // Add check for potential file size errors (e.g., MAX_FILE_SIZE_EXCEEDED) - error code might vary
      if (error.errorCode === 'STRING_TOO_LONG' || error.message?.includes('maximum file size')) {
          logger.error("UploadFile: File size limit potentially exceeded.", { error: error.message });
          throw new HttpsError('invalid-argument', 'File size limit exceeded.');
      } 
      throw new HttpsError("internal", "An unexpected error occurred during file upload.", error);
    }
  }
);

// --- Delete Function --- 
export const deleteSalesforceFile = onCall(
  {
    timeoutSeconds: 60,
    memory: "256MiB",
    // enforceAppCheck: true,
  },
  async (request: CallableRequest<DeleteFileParams>): Promise<DeleteFileResult> => {
    logger.info("deleteSalesforceFile function triggered", { params: { contentDocumentId: request.data.contentDocumentId } });

    // 1. Auth Check
    if (!request.auth) {
      logger.error("DeleteFile: Auth failed");
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = request.auth.uid;

    // 2. Input Validation
    const { contentDocumentId, accessToken, instanceUrl } = request.data;
    if (!contentDocumentId || !accessToken || !instanceUrl) {
      logger.error("DeleteFile: Validation failed - Missing required fields", { contentDocumentId: !!contentDocumentId, accessToken: !!accessToken, instanceUrl: !!instanceUrl });
      throw new HttpsError("invalid-argument", "Missing required fields for file deletion.");
    }
    logger.info("DeleteFile: Input validation passed.", { uid, contentDocumentId });

    try {
      // 3. Salesforce Connection
      const conn = new jsforce.Connection({ instanceUrl, accessToken });
      logger.info("DeleteFile: Salesforce connection initialized.");

      // 4. Authorization (Example: Basic admin check - refine as needed)
      // You might want to check if user has rights to delete this specific document
      try {
        const userDoc = await admin.firestore().collection('users').doc(uid).get();
        if (userDoc.data()?.role !== 'admin') { 
          // TODO: Add check if user has delete access to the ContentDocument
          logger.error("DeleteFile: Authorization failed - User not admin", { uid });
          throw new HttpsError("permission-denied", "User does not have permission to delete this file.");
        }
        logger.info("DeleteFile: Authorization check passed.", { uid });
      } catch (authError: any) {
        logger.error("DeleteFile: Error during authorization check", { uid, error: authError });
        throw new HttpsError("internal", "Failed to verify user permissions.");
      }

      // 5. Delete ContentDocument
      logger.info("Attempting to delete ContentDocument...", { contentDocumentId });
      const result: any = await conn.sobject('ContentDocument').destroy(contentDocumentId);
      logger.debug("ContentDocument Delete Result:", { result });

      // 6. Process Result
      if (result.success) {
        logger.info("Successfully deleted ContentDocument.", { contentDocumentId });
        return { success: true };
      } else {
        const errors = result.errors || ["Unknown ContentDocument deletion error"];
        // Check for specific errors like INSUFFICIENT_ACCESS_OR_READONLY
        const errorMessage = errors.map((e: any) => (typeof e === 'string') ? e : `${e.statusCode}: ${e.message}`).join('; ');
        logger.error("Failed to delete ContentDocument.", { contentDocumentId, errors: result.errors });
        throw new HttpsError("internal", `Salesforce file deletion failed: ${errorMessage}`);
      }

    } catch (error: any) {
      logger.error("Error in deleteSalesforceFile main try block:", error);
      if (error instanceof HttpsError) { throw error; }
      if (error.name === 'invalid_grant' || error.errorCode === 'INVALID_SESSION_ID') {
        logger.warn('DeleteFile: Detected invalid session ID or grant error.');
        throw new HttpsError('unauthenticated', 'Salesforce session expired or invalid.', { sessionExpired: true });
      }
      // Handle common deletion errors
      if (error.errorCode === 'ENTITY_IS_DELETED') {
        logger.warn("DeleteFile: File already deleted or not found.", { contentDocumentId });
        // Consider returning success: true if already deleted? Or a specific error.
        // Returning error for now.
        throw new HttpsError('not-found', 'File not found or already deleted.');
      } 
      if (error.errorCode === 'INSUFFICIENT_ACCESS_OR_READONLY') {
         logger.error("DeleteFile: Insufficient access to delete file.", { contentDocumentId, uid });
         throw new HttpsError('permission-denied', 'Insufficient permissions to delete this file.');
      }
      throw new HttpsError("internal", "An unexpected error occurred during file deletion.", error);
    }
  }
); 