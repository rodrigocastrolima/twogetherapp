import * as functions from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import { FirestoreEvent, Change, DocumentSnapshot } from "firebase-functions/v2/firestore";

// Initialize Firebase Admin SDK (ensure this is done only once, 
// typically in your main functions file like index.ts, but including it here 
// for completeness if this is run standalone or imported)
try {
  if (admin.apps.length === 0) {
    admin.initializeApp();
    console.log("Admin SDK initialized.");
  } else {
    console.log("Admin SDK already initialized.");
  }
} catch (e) {
  console.error("Error initializing Admin SDK: ", e);
}

/**
 * Cloud Function triggered when a user document in Firestore (/users/{userId}) is written (v2 Syntax).
 * It checks the 'role' field and sets/removes the 'admin' custom claim accordingly.
 */
export const handleUserRoleChange = functions.onDocumentWritten(
  "users/{userId}", 
  async (event: FirestoreEvent<Change<DocumentSnapshot> | undefined>) => {
    const userId = event.params.userId;

    // Get data snapshots directly from event.data (which is a Change object)
    const snapshotBefore = event.data?.before; // Snapshot before the change
    const snapshotAfter = event.data?.after;  // Snapshot after the change

    const userDataAfter = snapshotAfter?.data();
    const userDataBefore = snapshotBefore?.data();

    // --- Determine the role after the write ---
    const roleAfter = userDataAfter?.role;
    const roleBefore = userDataBefore?.role;

    // --- Exit early if role hasn't changed --- 
    if (roleAfter === roleBefore) {
      console.log(`Role unchanged or user doc created/deleted without role change for ${userId}. No claim update needed.`);
      return null;
    }

    console.log(`Role change detected for ${userId}. Before: '${roleBefore}', After: '${roleAfter}'.`);

    // Handle deletion - if doc deleted, ensure claim is removed if it existed
    if (!snapshotAfter?.exists) {
        console.log(`User document ${userId} deleted. Attempting claim removal.`);
        try {
            const userRecord = await admin.auth().getUser(userId);
            const currentClaims = userRecord.customClaims || {};
            if (currentClaims.admin === true) {
                const newClaims = { ...currentClaims };
                delete newClaims.admin;
                await admin.auth().setCustomUserClaims(userId, newClaims);
                console.log(`Successfully removed admin claim for deleted user ${userId}.`);
            } else {
                console.log(`No admin claim to remove for deleted user ${userId}.`);
            }
        } catch (error: any) {
             // Handle potential errors if user doesn't exist in Auth anymore either
             if (error.code === 'auth/user-not-found') {
                 console.log(`User ${userId} not found in Auth, cannot remove claims.`);
             } else {
                 console.error(`Error removing claim for deleted user ${userId}:`, error);
             }
        }
        return null;
    }

    // Handle create/update
    try {
      // --- Get existing custom claims --- 
      const userRecord = await admin.auth().getUser(userId);
      const currentClaims = userRecord.customClaims || {}; // Default to empty object
      const newClaims = { ...currentClaims }; // Create a mutable copy

      // --- Determine the new claim state --- 
      let claimsChanged = false;
      if (roleAfter === "admin") {
        if (newClaims.admin !== true) {
          console.log(`Setting admin claim to true for user: ${userId}`);
          newClaims.admin = true;
          claimsChanged = true;
        } else {
          console.log(`Admin claim already true for user: ${userId}`);
        }
      } else { 
        // If the role is not 'admin' (but document exists), ensure the claim is removed
        if (newClaims.admin === true) {
          console.log(`Removing admin claim for user: ${userId} (role is now ${roleAfter})`);
          delete newClaims.admin;
          claimsChanged = true;
        } else {
           console.log(`Admin claim already absent for user: ${userId}`);
        }
      }

      // --- Apply claims ONLY if they have actually changed --- 
      if (claimsChanged) {
         await admin.auth().setCustomUserClaims(userId, newClaims);
         console.log(`Successfully set custom claims for ${userId}:`, newClaims);
      } else {
         console.log(`Custom claims for ${userId} did not need updating.`);
      }

    } catch (error) {
      console.error(`Error processing role change for user ${userId}:`, error);
    }

    return null; // Indicate successful completion
  }); 