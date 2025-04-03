import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';

// Configuration
const MESSAGE_EXPIRATION_HOURS = 24; // Messages older than this will be deleted (was 6 hours)
const BATCH_SIZE = 400; // Firebase batches are limited to 500 operations

/**
 * Scheduled function that runs daily to clean up expired messages.
 * It deletes messages that are older than MESSAGE_EXPIRATION_HOURS.
 * Important: This function preserves notification state to ensure unread messages remain visible.
 */
export const cleanupExpiredMessages = functions.scheduler
  .onSchedule({
    schedule: '0 0 * * *', // Run at midnight every day (cron syntax)
    timeZone: 'UTC',
  }, async (event) => {
    const db = admin.firestore();
    
    // Calculate the expiration threshold date (24 hours ago)
    const expirationDate = new Date();
    expirationDate.setHours(expirationDate.getHours() - MESSAGE_EXPIRATION_HOURS);
    const expirationTimestamp = admin.firestore.Timestamp.fromDate(expirationDate);
    
    console.log(`Starting message cleanup. Deleting messages older than ${expirationDate.toISOString()} (${MESSAGE_EXPIRATION_HOURS} hours ago)`);
    
    try {
      // Get all conversations
      const conversationsSnapshot = await db.collection('conversations').get();
      
      let totalMessagesDeleted = 0;
      let totalImagesDeleted = 0;
      let conversationsUpdated = 0;
      
      // Process each conversation
      for (const conversationDoc of conversationsSnapshot.docs) {
        const conversationId = conversationDoc.id;
        console.debug(`Processing conversation: ${conversationId}`);
        
        // Find expired messages in this conversation
        const expiredMessagesQuery = await db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('timestamp', '<', expirationTimestamp)
          .get();
        
        if (expiredMessagesQuery.empty) {
          continue; // Skip to next conversation if no expired messages
        }
        
        console.log(`Found ${expiredMessagesQuery.size} expired messages in conversation ${conversationId}`);
        
        // Process messages in batches
        const storage = admin.storage();
        let batch = db.batch();
        let operationCount = 0;
        
        for (const messageDoc of expiredMessagesQuery.docs) {
          // Add message deletion to batch
          batch.delete(messageDoc.ref);
          operationCount++;
          totalMessagesDeleted++;
          
          // Check if we need to delete an image from storage
          const messageData = messageDoc.data();
          if (messageData.type === 'image') {
            try {
              // Extract image path from URL
              const imageUrl = messageData.content as string;
              if (imageUrl && imageUrl.includes('firebase') && imageUrl.includes('storage')) {
                // Extract the filename and path
                const urlParts = imageUrl.split('/');
                const fileName = urlParts[urlParts.length - 1].split('?')[0];
                
                // Delete the image file
                await storage.bucket().file(`chat_images/${fileName}`).delete();
                totalImagesDeleted++;
                
                console.debug(`Deleted image: ${fileName}`);
              }
            } catch (imageError) {
              // Log but continue if image deletion fails
              console.warn(`Error deleting image: ${imageError}`);
            }
          }
          
          // Commit batch when it reaches the size limit
          if (operationCount >= BATCH_SIZE) {
            await batch.commit();
            console.debug(`Committed batch of ${operationCount} operations`);
            batch = db.batch();
            operationCount = 0;
          }
        }
        
        // Commit any remaining operations
        if (operationCount > 0) {
          await batch.commit();
          console.debug(`Committed final batch of ${operationCount} operations`);
        }
        
        // Check if there are any messages left in the conversation
        const remainingMessagesQuery = await db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', 'desc')
          .limit(1)
          .get();
        
        if (remainingMessagesQuery.empty) {
          console.log(`No messages remain in conversation ${conversationId}, updating last message content only`);
          
          // Only update the content indicators but preserve notification state
          const updateData: any = {
            lastMessageContent: null,
            lastMessageIsFromAdmin: null,
            lastMessageTime: null, // Reset the timestamp when no messages remain
            // IMPORTANT: DO NOT reset the following fields to preserve notifications
            // unreadByAdmin: false,
            // unreadByReseller: false,
            // unreadCount: 0
          };
          
          // Don't modify the unreadCounts, preserve them as is
          
          await db.collection('conversations').doc(conversationId).update(updateData);
          
          conversationsUpdated++;
        } else {
          // If there are still messages, update the last message data to the most recent one
          const latestMessage = remainingMessagesQuery.docs[0].data();
          
          await db.collection('conversations').doc(conversationId).update({
            lastMessageContent: latestMessage.content,
            lastMessageIsFromAdmin: latestMessage.isAdmin, // Use isAdmin instead of isFromAdmin to match the schema
            lastMessageTime: latestMessage.timestamp // Ensure this field is updated
            // IMPORTANT: DO NOT update notification fields here
            // This preserves both the legacy unread fields and the new unreadCounts map
          });
          
          console.debug(`Updated conversation ${conversationId} with latest message data`);
          conversationsUpdated++;
        }
      }
      
      console.log(`Message cleanup completed successfully. Deleted ${totalMessagesDeleted} messages and ${totalImagesDeleted} images. Updated ${conversationsUpdated} conversations.`);
      
    } catch (error) {
      console.error(`Error during message cleanup: ${error}`);
      throw error;
    }
  }); 