import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as jsforce from "jsforce";
import axios from "axios"; // Or node-fetch if preferred

// Initialize Firebase Admin SDK (if not already done in index.ts)
// Consider moving this to index.ts if you have multiple functions
try {
  admin.initializeApp();
} catch (e) {
  logger.info("Firebase Admin SDK already initialized.");
}


// --- Interfaces ---

interface CreateOppParams {
  submissionId: string;
  accessToken: string; // Added
  instanceUrl: string; // Added
  resellerSalesforceId: string;
  opportunityName: string;
  nif: string;
  companyName: string; // For Account creation if needed
  segment: string;
  solution: string;
  closeDate: string; // Expect ISO 8601 string from client
  opportunityType: string;
  phase: string;
  fileUrls?: string[]; // Optional list of file URLs/paths
}

interface CreateOppResult {
  success: boolean;
  opportunityId?: string;
  accountId?: string;
  error?: string;
  sessionExpired?: boolean; // Added
}

// --- Cloud Function Definition ---

export const createSalesforceOpportunity = onCall(
  {
    timeoutSeconds: 300, // Increase timeout for potential file downloads/uploads
    memory: "512MiB", // Allocate more memory if needed for file processing
    // enforceAppCheck: true, // Recommended for production
  },
  async (request: CallableRequest<CreateOppParams>): Promise<CreateOppResult> => {
    logger.info("createSalesforceOpportunity function triggered", { submissionId: request.data.submissionId });
    logger.info("Function execution started. Checking auth context...");

    // 1. Authentication and Authorization Check
    if (!request.auth) {
      logger.error("Authentication failed: User is not authenticated.");
      throw new HttpsError("unauthenticated", "User must be authenticated to perform this action.");
    }
    logger.info("Authentication check passed. Auth object exists.");
    const uid = request.auth.uid; // Get uid for Firestore lookup

    // --- AUTHORIZATION CHECK using Firestore 'role' field --- 
    try {
      const userDoc = await admin.firestore().collection('users').doc(uid).get();
      if (!userDoc.exists) {
        logger.error("Authorization failed: User document not found.", { uid: uid });
        throw new HttpsError("permission-denied", "User data not found.");
      }
      const userData = userDoc.data();
      const userRole = userData?.role;

      if (userRole !== 'admin') {
        logger.error("Authorization failed: User role is not 'admin'.", { uid: uid, role: userRole });
        throw new HttpsError("permission-denied", "User does not have admin permission to perform this action."); // Adjusted message slightly
      }
      logger.info("User authorized as Admin based on Firestore role.", { uid: uid });

    } catch (dbError: any) {
      logger.error("Error fetching user document for authorization:", { uid: uid, error: dbError });
      throw new HttpsError("internal", "Failed to verify user permissions.");
    }
    // --- END AUTHORIZATION CHECK ---

    // 2. Input Validation (Basic)
    const data = request.data;
    logger.info("Received data for validation:", data); // Log before checks

    // --- BEGIN Individual Field Checks --- ADDED DETAILED LOGGING
    logger.info("Checking submissionId...");
    if (!data.submissionId) {
      logger.error("Validation FAILED for submissionId", { value: data.submissionId });
      throw new HttpsError("invalid-argument", "Missing submissionId");
    }
    logger.info("Checking accessToken...");
    if (!data.accessToken) {
       logger.error("Validation FAILED for accessToken", { value: data.accessToken });
      throw new HttpsError("invalid-argument", "Missing accessToken");
    }
    logger.info("Checking instanceUrl...");
    if (!data.instanceUrl) {
       logger.error("Validation FAILED for instanceUrl", { value: data.instanceUrl });
      throw new HttpsError("invalid-argument", "Missing instanceUrl");
    }
    logger.info("Checking resellerSalesforceId...");
    if (!data.resellerSalesforceId) {
       logger.error("Validation FAILED for resellerSalesforceId", { value: data.resellerSalesforceId });
      throw new HttpsError("invalid-argument", "Missing resellerSalesforceId");
    }
    logger.info("Checking opportunityName...");
    if (!data.opportunityName) {
       logger.error("Validation FAILED for opportunityName", { value: data.opportunityName });
      throw new HttpsError("invalid-argument", "Missing opportunityName");
    }
    logger.info("Checking nif...");
    if (!data.nif) {
       logger.error("Validation FAILED for nif", { value: data.nif });
      throw new HttpsError("invalid-argument", "Missing nif");
    }
    logger.info("Checking companyName...");
    if (!data.companyName) {
       logger.error("Validation FAILED for companyName", { value: data.companyName });
      throw new HttpsError("invalid-argument", "Missing companyName");
    }
    logger.info("Checking segment...");
    if (!data.segment) {
       logger.error("Validation FAILED for segment", { value: data.segment });
      throw new HttpsError("invalid-argument", "Missing segment");
    }
    logger.info("Checking solution...");
    if (!data.solution) {
       logger.error("Validation FAILED for solution", { value: data.solution });
      throw new HttpsError("invalid-argument", "Missing solution");
    }
    logger.info("Checking closeDate...");
    if (!data.closeDate) {
       logger.error("Validation FAILED for closeDate", { value: data.closeDate });
      throw new HttpsError("invalid-argument", "Missing closeDate");
    }
    logger.info("Checking opportunityType...");
    if (!data.opportunityType) {
       logger.error("Validation FAILED for opportunityType", { value: data.opportunityType });
      throw new HttpsError("invalid-argument", "Missing opportunityType");
    }
    logger.info("Checking phase...");
    if (!data.phase) {
       logger.error("Validation FAILED for phase", { value: data.phase });
      throw new HttpsError("invalid-argument", "Missing phase");
    }
    // --- END Individual Field Checks ---

    logger.info("All initial validation checks passed."); // Add log to confirm success

    // --- Steps 4-8 ---
    try {
      // Initialize JSforce Connection (Step 4.1, 4.2)
      const conn = new jsforce.Connection({
          instanceUrl: data.instanceUrl,
          accessToken: data.accessToken,
          // version: '58.0' // Optional: specify API version
      });
      logger.info("Salesforce connection initialized using provided token.");

      let accountId: string; // Declare accountId to store the result

      // --- Step 5: Query/Update/Create Account Logic ---
      logger.info("Checking for existing Account with NIF...", { nif: data.nif });
      
      // Validate NIF format before querying (basic example)
      if (!data.nif || typeof data.nif !== 'string' || data.nif.length < 5) { // Basic NIF validation
           throw new HttpsError("invalid-argument", "Invalid or missing NIF provided.");
      }

      const accountQuery = `SELECT Id FROM Account WHERE NIF__c = '${data.nif}' LIMIT 1`;
      
      const existingAccountResult = await callSalesforceApi<{ totalSize: number, records: { Id: string }[] }>(async () => 
          await conn.query(accountQuery)
      );

      if (existingAccountResult.totalSize > 0) {
          // --- Account Found: Update specific fields (NOT Name) ---
          accountId = existingAccountResult.records[0].Id;
          logger.info(`Found existing Account. ID: ${accountId}. Updating EDP fields.`);
          
          const accountUpdatePayload = {
              EDP__c: true,           
              EDP_Status__c: "Prospect" 
              // DO NOT include Name here
          };
          
          await callSalesforceApi<{ id?: string, success?: boolean, errors?: any[] }>(() => 
              conn.sobject('Account').update({ 
                  Id: accountId, 
                  ...accountUpdatePayload 
              })
          );
          // Note: We might want more robust error checking on the update result here.
          logger.info(`Successfully updated EDP fields for existing Account: ${accountId}`);

      } else {
          // --- Account Not Found: Create New Account ---
          logger.info(`No existing Account found with NIF: ${data.nif}. Creating new Account.`);
          const accountCreatePayload = { 
        Name: data.companyName, // Use companyName from submission for Account Name
        NIF__c: data.nif,
              EDP__c: true,            
              EDP_Status__c: "Prospect" 
      };

          const accountCreateResult = await callSalesforceApi<{ id?: string, success?: boolean, errors?: any[] }>(() => 
              conn.sobject('Account').create(accountCreatePayload)
      );
      
          if (!accountCreateResult.id || !accountCreateResult.success) {
              logger.error("Failed to create new Account.", { result: accountCreateResult });
              throw new HttpsError("internal", "Failed to create Account in Salesforce.", { details: accountCreateResult.errors });
      }
          accountId = accountCreateResult.id;
          logger.info(`Successfully created new Account. ID: ${accountId}`);
      }
      // --- End Step 5 ---

      // --- Step 5.5: Fetch Retail Record Type ID ---
      let retailRecordTypeId: string;
      try {
        logger.info("Fetching Retail Record Type ID for Oportunidade__c...");
        const rtQuery = `SELECT Id FROM RecordType WHERE SobjectType = 'Oportunidade__c' AND DeveloperName = 'Retail' LIMIT 1`;
        
        // Directly execute the query using the connection
        const rtResult = await conn.query<{ Id: string }>(rtQuery);

        if (rtResult.records && rtResult.records.length > 0 && rtResult.records[0].Id) {
          retailRecordTypeId = rtResult.records[0].Id;
          logger.info(`Found Retail Record Type ID: ${retailRecordTypeId}`);
        } else {
          logger.error("Retail Record Type ID not found for Oportunidade__c.");
          throw new HttpsError("failed-precondition", "Configuration Error: Retail Record Type not found in Salesforce.");
        }
      } catch (error: any) {
        // Log the specific error from fetching Record Type ID
        logger.error("Error fetching Retail Record Type ID:", error);
        // Handle potential Salesforce API errors from the query
        if (error.name === 'invalid_grant' || error.errorCode === 'INVALID_SESSION_ID') {
             throw new HttpsError('unauthenticated', 'Salesforce session expired or invalid during Record Type fetch.', { sessionExpired: true });
        }
        // Otherwise, wrap it as an internal error
        throw new HttpsError("internal", `Failed to fetch Retail Record Type ID: ${error.message || error}`);
      }
      // --- End Step 5.5 ---

      // --- Step 6: Opportunity Creation Logic ---
      logger.info("Attempting Opportunity creation...", { accountId: accountId, recordTypeId: retailRecordTypeId });
      // Construct the payload, mapping Flutter names/values to SF API names
      const currentDate = new Date().toISOString().split('T')[0]; // Get current date as YYYY-MM-DD
      const oppPayload = {
        Name: data.opportunityName,
        Entidade__c: accountId, // Use the STORED accountId
        RecordTypeId: retailRecordTypeId, // <-- Add fetched Record Type ID
        NIF__c: data.nif,
        Agente_Retail__c: data.resellerSalesforceId, // Use the ID passed from Flutter
        Tipo_de_Oportunidade__c: data.opportunityType,
        Fase__c: data.phase,
        Segmento_de_Cliente__c: data.segment,
        Solu_o__c: data.solution,
        Data_de_Previs_o_de_Fecho__c: data.closeDate, // Assuming client sends 'YYYY-MM-DD'
        Data_de_Cria_o_da_Oportunidade__c: currentDate, // ADDED: Set required creation date
        // Add any other mandatory fields here
      };
      logger.debug("Opportunity Payload:", { payload: oppPayload });

      // Use the helper function to make the call
      const oppResult = await callSalesforceApi<{id?: string, success?: boolean, errors?: any[]}>(() => 
        conn.sobject('Oportunidade__c').create(oppPayload)
      );

      // Validate Opportunity Create result
      const opportunityId = oppResult.id;
      if (!opportunityId || !oppResult.success) {
        logger.error("Opportunity creation failed.", { result: oppResult });
        throw new HttpsError("internal", "Failed to create Opportunity in Salesforce.", { details: oppResult.errors });
      }
      logger.info(`Opportunity creation successful. Opportunity ID: ${opportunityId}`);
      // --- End Step 6 ---

      // --- Step 7: File Upload Logic ---
      const fileUrls = data.fileUrls; // Expecting an array of strings (URLs or paths)
      if (fileUrls && fileUrls.length > 0) {
        logger.info(`Starting file uploads for ${fileUrls.length} files to Opportunity ${opportunityId}...`);
        
        // Process uploads sequentially for simplicity, can be parallelized if needed
        for (const fileUrlOrPath of fileUrls) {
          try {
            logger.info(`Processing file: ${fileUrlOrPath}`);
            
            // 1. Get Filename (basic extraction)
            let fileName = 'UnknownFile';
            try {
               const decodedPath = decodeURIComponent(fileUrlOrPath.split('/').pop()?.split('?')[0] || 'UnknownFile');
               fileName = decodedPath.split('/').pop()?.replace(/^attachment_\d+_/, '') || 'UnknownFile';
            } catch(e) {
               logger.warn(`Could not reliably parse filename from: ${fileUrlOrPath}`, e);
               fileName = fileUrlOrPath.split('/').pop()?.split('?')[0]?.replace(/^attachment_\d+_/, '') || 'UnknownFile';
            }
            logger.info(`Extracted filename: ${fileName}`);

            // 2. Get File Content (assuming direct download URL for now)
            //    If these are Storage paths, you need Firebase Admin Storage SDK here
            let fileBuffer: Buffer;
            try {
              const response = await axios.get(fileUrlOrPath, { responseType: 'arraybuffer' });
              if (response.status !== 200) {
                throw new Error(`Failed to download file ${fileName}: Status ${response.status}`);
              }
              fileBuffer = Buffer.from(response.data);
              logger.info(`Successfully downloaded file content for ${fileName}. Size: ${fileBuffer.length} bytes.`);
            } catch (downloadError: any) {
               logger.error(`Error downloading file ${fileName} from ${fileUrlOrPath}:`, downloadError);
               // Decide: skip this file or fail the whole operation?
               // Let's skip and log for now.
               logger.warn(`Skipping upload for ${fileName} due to download error.`);
               continue; // Move to the next file
            }

            // 3. Base64 Encode
            const base64Content = fileBuffer.toString('base64');

            // 4. Create ContentVersion in Salesforce
            const filePayload = {
              Title: fileName,
              PathOnClient: fileName,
              VersionData: base64Content,
              FirstPublishLocationId: opportunityId, // Link to the Opportunity
            };
            logger.info(`Uploading ${fileName} (${base64Content.length} chars base64) to Salesforce...`);
            
            // Use the helper for the API call
            const fileResult = await callSalesforceApi<{id?: string, success?: boolean, errors?: any[]}>(() => 
              conn.sobject('ContentVersion').create(filePayload)
            );

            if (!fileResult.success || !fileResult.id) {
              logger.error(`Failed to upload file ${fileName} to Salesforce.`, { result: fileResult });
              // Decide: skip or fail?
              // Let's throw an error to indicate upload failure for this file
              throw new HttpsError("internal", `Failed to upload file ${fileName}.`, { details: fileResult.errors });
            }
            logger.info(`Successfully uploaded file ${fileName} as ContentVersion ${fileResult.id}`);

          } catch (fileUploadError) {
            // Catch errors specific to this file's processing/uploading
            logger.error(`Error processing file ${fileUrlOrPath}:`, fileUploadError);
            // If the error is an HttpsError (e.g., session expired from callSalesforceApi), rethrow it
            if (fileUploadError instanceof HttpsError) {
              throw fileUploadError;
            }
            // Otherwise, wrap it and decide if it's fatal
            // Let's make individual file upload errors fatal for now
            throw new HttpsError("internal", `Failed during file upload process for ${fileUrlOrPath}.`, fileUploadError);
          }
        } // End of for loop
        logger.info("Finished processing all file uploads.");
      } else {
        logger.info("No file URLs provided in the submission, skipping file upload step.");
      }
      // --- End Step 7 ---

      // --- Step 8: Return Final Success --- 
      // If we reached here, all steps were successful
      logger.info("All steps completed successfully.");
      return { 
        success: true, 
        opportunityId: opportunityId, 
        accountId: accountId // <-- INCLUDE accountId in the result
      };

    } catch (error) {
      logger.error("Error caught in main try block:", error); // Log the caught error
      if (error instanceof HttpsError) {
        throw error; // Re-throw HttpsErrors
      }
      // Wrap other unexpected errors (e.g., validation errors before API call)
      throw new HttpsError("internal", "An unexpected error occurred.", error);
    }
  }
);

// --- Step 4.3: API Call Helper Function ---
async function callSalesforceApi<T>(apiCall: () => Promise<T>): Promise<T> {
  logger.info("Executing Salesforce API call...");
  try {
    const result = await apiCall();
    logger.info("Salesforce API call successful.");
    return result;
  } catch (error: any) {
    logger.error('Salesforce API Error caught in helper:', { 
        name: error.name, 
        code: error.errorCode, 
        message: error.message, 
        // stack: error.stack // Optional: include stack trace if needed 
    });
    // Check for specific Salesforce session invalidation errors
    if (error.name === 'invalid_grant' || // Often indicates expired/revoked token
        error.errorCode === 'INVALID_SESSION_ID' || 
        (error.errorCode && typeof error.errorCode === 'string' && error.errorCode.includes('INVALID_SESSION_ID'))) 
    {
      logger.warn('Detected invalid session ID or grant error.');
      throw new HttpsError('unauthenticated', 'Salesforce session expired or invalid.', { sessionExpired: true });
    } else {
      // Throw a generic internal error for other Salesforce issues
      const errorMessage = error.message || error.name || 'Unknown Salesforce API error';
      throw new HttpsError('internal', `Salesforce API call failed: ${errorMessage}`, { 
          errorCode: error.errorCode, 
          fields: error.fields // Include fields if available (e.g., validation errors)
      });
    }
  }
} 