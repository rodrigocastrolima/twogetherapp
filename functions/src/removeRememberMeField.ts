import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

/**
 * Cloud function to remove the "rememberMe" field from all user documents in Firestore.
 * This function should be called manually via the Firebase console or CLI.
 * 
 * Usage: 
 * - Deploy using `firebase deploy --only functions:removeRememberMeField`
 * - Execute manually from Firebase console
 */
export const removeRememberMeField = onCall({
  enforceAppCheck: false, // Set to true in production
}, async (request) => {
  // Ensure the request is made by an authenticated admin user
  if (!request.auth) {
    logger.error("Unauthenticated call to removeRememberMeField");
    throw new HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  // Check if the user is an admin (adjust this check according to your app's admin verification logic)
  const uid = request.auth.uid;
  
  try {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const userData = userDoc.data();
    
    if (!userData || userData.role?.toLowerCase() !== "admin") {
      logger.error(`User is not an admin. Role: ${userData?.role}`);
      throw new HttpsError(
        "permission-denied",
        "Only admin users can run this function."
      );
    }

    logger.info(`Starting removal of rememberMe field by admin user: ${uid}`);
    
    // Get all user documents
    const usersSnapshot = await admin.firestore().collection("users").get();
    
    // Count and stats
    const totalUsers = usersSnapshot.size;
    let usersWithRememberMe = 0;
    let processedUsers = 0;
    
    // Process in batches to avoid timeouts
    const batch = admin.firestore().batch();
    
    // Find users with rememberMe field and prepare batch update
    usersSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      if (data.rememberMe !== undefined) {
        usersWithRememberMe++;
        batch.update(doc.ref, {
          rememberMe: admin.firestore.FieldValue.delete(),
        });
        processedUsers++;
      }
    });
    
    // Commit the batch update if there are users to process
    if (usersWithRememberMe > 0) {
      await batch.commit();
      logger.info(`Successfully removed rememberMe field from ${processedUsers} user documents.`);
    } else {
      logger.info("No users found with rememberMe field.");
    }
    
    // Return summary of operations
    return {
      success: true,
      totalUsers,
      usersWithRememberMe,
      processedUsers,
      message: `Successfully removed 'rememberMe' field from ${processedUsers} user documents.`,
    };
  } catch (error) {
    logger.error(`Error removing rememberMe fields: ${error}`);
    throw new HttpsError(
      "internal",
      `Error removing rememberMe fields: ${error instanceof Error ? error.message : String(error)}`
    );
  }
}); 