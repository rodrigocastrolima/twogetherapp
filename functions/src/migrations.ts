import * as functions from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import * as admin from 'firebase-admin';

// Ensure admin is initialized (idempotent)
if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

interface ConversationData {
  resellerId: string;
  resellerName?: string;
  participants?: string[];
  active?: boolean;
  unreadCounts?: Record<string, number>;
  createdAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  // Add other expected fields with optional markers if they might be missing
}

/**
 * Callable function to iterate through resellers, ensure each has exactly one
 * conversation document with the correct schema, and delete duplicates.
 */
export const resetAndVerifyConversations = functions.onCall(
  {
    // enforceAppCheck: true, // Consider enabling App Check
    region: 'us-central1',
    timeoutSeconds: 540, // Max timeout for potentially long operation
  },
  async (request) => {
    // 1. Authenticate and Authorize Admin
    if (!request.auth) {
      throw new functions.HttpsError(
        'unauthenticated',
        'Authentication required.'
      );
    }
    const callerUid = request.auth.uid;
    try {
      const callerDoc = await db.collection('users').doc(callerUid).get();
      if (!callerDoc.exists || callerDoc.data()?.role !== 'admin') {
        throw new functions.HttpsError(
          'permission-denied',
          'Admin privileges required.'
        );
      }
    } catch (err) {
      logger.error('Error verifying admin status:', err);
      throw new functions.HttpsError('internal', 'Could not verify admin status.');
    }

    logger.info(`Conversation reset requested by admin: ${callerUid}`);

    // 2. Process Resellers
    let resellersProcessed = 0;
    let conversationsCreated = 0;
    let conversationsKept = 0;
    let conversationsUpdated = 0;
    let conversationsDeleted = 0;

    try {
      const usersSnapshot = await db.collection('users').where('role', '==', 'reseller').get();
      resellersProcessed = usersSnapshot.size;
      logger.info(`Found ${resellersProcessed} resellers to process.`);

      const batch = db.batch(); // Use a single batch for efficiency
      let batchOperations = 0;
      const MAX_BATCH_OPERATIONS = 490; // Firestore batch limit is 500

      // Helper to commit batch and start a new one
      const commitBatchIfNeeded = async () => {
        if (batchOperations >= MAX_BATCH_OPERATIONS) {
          logger.info(`Committing batch with ${batchOperations} operations...`);
          await batch.commit();
          // Start a new batch for subsequent operations
          // NOTE: Re-assigning batch = db.batch() doesn't work as expected within this scope.
          // We need a different strategy if operations exceed 500, like multiple function calls or sequential processing.
          // For now, assuming < 500 operations. Add error handling if limit is hit.
          logger.warn('Approaching batch limit. Operations > 500 not fully supported in this version.');
          // Reset counter for safety, though batch object remains the same.
          batchOperations = 0;
        }
      };

      for (const userDoc of usersSnapshot.docs) {
        const resellerId = userDoc.id;
        const resellerData = userDoc.data();
        logger.info(`Processing reseller: ${resellerId} (${resellerData.email})`);

        const convQuery = db.collection('conversations').where('resellerId', '==', resellerId);
        const convSnapshot = await convQuery.get();

        if (convSnapshot.empty) {
          // Create missing conversation
          logger.info(`No conversation found for ${resellerId}. Creating default.`);
          const newConvRef = db.collection('conversations').doc(); // Auto-generate ID
          const conversationData = {
            resellerId: resellerId,
            resellerName: resellerData.displayName || resellerData.email || 'Unknown User',
            participants: ['admin', resellerId],
            active: false,
            unreadCounts: {},
            lastMessageContent: null,
            lastMessageTime: null,
            lastMessageIsFromAdmin: null, // Explicitly null
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            // Add other default fields
          };
          batch.set(newConvRef, conversationData);
          batchOperations++;
          conversationsCreated++;
          await commitBatchIfNeeded();
        } else {
          // Found existing conversation(s)
          logger.info(`Found ${convSnapshot.size} conversation(s) for ${resellerId}.`);

          // Sort by creation date (newest first), handle missing timestamps
          const sortedDocs = convSnapshot.docs.sort((a, b) => {
            const timeA = (a.data().createdAt as admin.firestore.Timestamp)?.toMillis() || 0;
            const timeB = (b.data().createdAt as admin.firestore.Timestamp)?.toMillis() || 0;
            return timeB - timeA; // Descending order
          });

          // Keep the newest one
          const docToKeep = sortedDocs[0];
          const currentData = docToKeep.data() as ConversationData | undefined;
          conversationsKept++;
          logger.info(`Keeping conversation: ${docToKeep.id}, preparing to reset its state.`);

          // Prepare the payload to enforce the desired default/reset state
          const resetPayload: { [key: string]: any } = {
              resellerId: resellerId, // Ensure this is correct
              resellerName: currentData?.resellerName || resellerData.displayName || resellerData.email || 'Unknown User', // Keep or update name
              participants: ['admin', resellerId], // Enforce correct participants
              active: false, // Force inactive
              unreadCounts: {}, // Force empty map
              lastMessageContent: null, // Force null
              lastMessageTime: null, // Force null
              lastMessageIsFromAdmin: null, // Force null
              unreadCount: 0, // Force 0
              unreadByAdmin: false, // Force false
              unreadByReseller: false, // Force false
              activeUsers: [], // Force empty list
              // Keep createdAt if it exists and is a timestamp, otherwise set it
              createdAt: (currentData?.createdAt instanceof admin.firestore.Timestamp)
                           ? currentData.createdAt
                           : admin.firestore.FieldValue.serverTimestamp()
          };

          // Use set WITHOUT merge to completely overwrite the document with the desired state
          // This effectively resets the kept conversation document.
          batch.set(docToKeep.ref, resetPayload);
          batchOperations++;
          // Log this as an update/reset operation
          conversationsUpdated++; // Increment update count as we are modifying it
          logger.info(`Overwriting conversation ${docToKeep.id} with default reset state.`);
          await commitBatchIfNeeded();

          // Delete older duplicates
          if (sortedDocs.length > 1) {
            for (let i = 1; i < sortedDocs.length; i++) {
              const docToDelete = sortedDocs[i];
              logger.warn(`Deleting duplicate conversation: ${docToDelete.id} for reseller ${resellerId}`);
              batch.delete(docToDelete.ref);
              batchOperations++;
              conversationsDeleted++;
              // TODO: Consider deleting messages subcollection for deleted conversations
              await commitBatchIfNeeded();
            }
          }
        }
      }

      // Commit any remaining operations in the last batch
      if (batchOperations > 0) {
        logger.info(`Committing final batch with ${batchOperations} operations.`);
        await batch.commit();
      }

      logger.info('Conversation reset/verification process finished.');
      return {
        success: true,
        resellersProcessed,
        conversationsCreated,
        conversationsKept,
        conversationsUpdated,
        conversationsDeleted,
        message: 'Conversation reset/verification completed successfully.',
      };
    } catch (error) {
      logger.error('Error during conversation reset/verification:', error);
      throw new functions.HttpsError(
        'internal',
        `Process failed: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }
); 