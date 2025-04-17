import * as functions from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK (ensure this is done once, typically in index.ts if not already)
// If admin.apps.length === 0 { admin.initializeApp(); }
// Check if already initialized to prevent errors during deploy/emulation
if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();
const messaging = admin.messaging();

// Define interfaces for data structures for clarity
interface MessageData {
  senderId: string;
  content: string;
  type: 'text' | 'image' | string; // Allow other types potentially
  isAdmin: boolean;
  // Add other relevant message fields if needed
}

interface ConversationData {
  resellerId: string;
  resellerName?: string; // Optional: fetch sender name if not stored here
  participants: string[]; // Should contain 'admin' and resellerId
  activeUsers?: string[];
  // Add other relevant conversation fields
}

interface UserData {
  displayName?: string;
  email?: string;
  role?: string;
  fcmTokens?: string[]; // List of FCM tokens for the user
}

/**
 * Cloud Function that triggers when a new message is added to Firestore
 * and sends push notifications to the appropriate recipients using FCM.
 */
export const sendMessageNotification = functions.onDocumentCreated(
  'conversations/{conversationId}/messages/{messageId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      logger.warn('No data associated with the event');
      return;
    }
    const message = snap.data() as MessageData;
    const conversationId = event.params.conversationId;
    const messageId = event.params.messageId; // Get messageId for logging

    logger.info(`New message ${messageId} in conversation ${conversationId}`, { structuredData: true });

    if (!message || !message.senderId) {
      logger.warn('Message data or senderId missing', { messageId, conversationId });
      return;
    }

    try {
      // 1. Get the conversation document
      const conversationRef = db.collection('conversations').doc(conversationId);
      const conversationDoc = await conversationRef.get();

      if (!conversationDoc.exists) {
        logger.error(`Conversation ${conversationId} does not exist`, { messageId });
        return;
      }

      const conversation = conversationDoc.data() as ConversationData | undefined;
      if (!conversation || !conversation.participants || !conversation.resellerId) {
        logger.error(`Incomplete conversation data for ${conversationId}`, { messageId });
        return;
      }

      // 2. Determine Sender Name
      let senderName = 'User'; // Default sender name
      try {
        const senderDoc = await db.collection('users').doc(message.senderId).get();
        if (senderDoc.exists) {
          const senderData = senderDoc.data() as UserData | undefined;
          senderName = senderData?.displayName ?? senderData?.email ?? senderName;
        } else {
           // Fallback if sender is not in users collection (e.g., old messages?)
           if (message.isAdmin) {
               senderName = 'Support Team';
           } else if (conversation.resellerName) {
               senderName = conversation.resellerName;
           }
           logger.warn(`Sender document ${message.senderId} not found, using fallback name: ${senderName}`, { messageId, conversationId });
        }
      } catch (err) {
        logger.error(`Error fetching sender ${message.senderId} name:`, err, { messageId, conversationId });
      }


      // 3. Determine Recipients and Check Activity
      const activeUsers = conversation.activeUsers || [];
      const recipients: { userId: string; tokens: string[] }[] = [];
      const recipientIds = conversation.participants.filter(
        (pId) => pId !== message.senderId && !activeUsers.includes(pId)
      );

      if (recipientIds.length === 0) {
        logger.info(`No inactive recipients found for message ${messageId} in ${conversationId}. Sender: ${message.senderId}, Active: ${activeUsers.join(',')}`, { structuredData: true });
        return;
      }

      logger.info(`Inactive recipients for ${messageId}: ${recipientIds.join(',')}`, { structuredData: true });

      // 4. Fetch Recipient Tokens
      const tokenFetchPromises = recipientIds.map(async (userId) => {
        try {
          // Handle 'admin' user identifier
          if (userId === 'admin') {
            // Query all users with the admin role
            const adminSnapshot = await db.collection('users').where('role', '==', 'admin').get();
            if (!adminSnapshot.empty) {
              adminSnapshot.forEach(adminDoc => {
                  const adminData = adminDoc.data() as UserData | undefined;
                  if (adminData?.fcmTokens && adminData.fcmTokens.length > 0) {
                      // Check if this admin is already in recipients (can happen if 'admin' is explicitly in participants)
                      const existingAdminRecipient = recipients.find(r => r.userId === adminDoc.id);
                      if (!existingAdminRecipient) {
                           recipients.push({ userId: adminDoc.id, tokens: adminData.fcmTokens });
                           logger.info(`Found admin ${adminDoc.id} with ${adminData.fcmTokens.length} tokens.`, { messageId, conversationId });
                      } else {
                           // Optionally merge tokens if admin ID might appear twice (unlikely but safe)
                           existingAdminRecipient.tokens = [...new Set([...existingAdminRecipient.tokens, ...adminData.fcmTokens])];
                      }
                  } else {
                     logger.warn(`Admin user ${adminDoc.id} has no FCM tokens.`, { messageId, conversationId });
                  }
              });
            } else {
               logger.warn(`No users found with role 'admin'.`, { messageId, conversationId });
            }
          } else {
            // Fetch regular user (reseller)
            const userDoc = await db.collection('users').doc(userId).get();
            if (userDoc.exists) {
              const userData = userDoc.data() as UserData | undefined;
              if (userData?.fcmTokens && userData.fcmTokens.length > 0) {
                recipients.push({ userId: userId, tokens: userData.fcmTokens });
                logger.info(`Found user ${userId} with ${userData.fcmTokens.length} tokens.`, { messageId, conversationId });
              } else {
                 logger.warn(`User ${userId} has no FCM tokens.`, { messageId, conversationId });
              }
            } else {
              logger.warn(`Recipient user document ${userId} not found.`, { messageId, conversationId });
            }
          }
        } catch (err) {
          logger.error(`Error fetching tokens for recipient ${userId}:`, err, { messageId, conversationId });
        }
      });

      await Promise.all(tokenFetchPromises);

      // 4b. Increment Unread Counts for Inactive Recipients
      const unreadUpdatePromises = recipientIds.map(async (userId) => {
        // Prepare the update payload for Firestore transaction
        // Use dot notation for map fields
        const userUnreadCountField = `unreadCounts.${userId}`;
        try {
          // We need to run this within the same transaction or ensure atomicity if possible.
          // For simplicity here, we perform separate updates. Consider transactions for robustness.
          // Increment the count for the specific user ID
          await conversationRef.update({
            [userUnreadCountField]: admin.firestore.FieldValue.increment(1),
            // Also update last message details for convenience (optional but good practice)
            lastMessageContent: message.content,
            lastMessageTime: admin.firestore.FieldValue.serverTimestamp(), // Use server time
            lastMessageSenderId: message.senderId, // Store sender ID
            lastMessageIsAdmin: message.isAdmin, // Store if sender was admin
          });
          logger.info(`Incremented unread count for ${userId} in conversation ${conversationId}`, { messageId });
        } catch (err) {
          logger.error(`Failed to increment unread count for ${userId} in ${conversationId}:`, err, { messageId });
          // Check if the field doesn't exist and try setting it to 1
          if ((err as any).code === 5) { // Firestore error code 5: NOT_FOUND (often means field path doesn't exist)
             logger.info(`Field ${userUnreadCountField} not found, attempting to set count to 1 for ${userId}.`);
             try {
                await conversationRef.update({
                    [userUnreadCountField]: 1,
                    // Also update last message details
                    lastMessageContent: message.content,
                    lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
                    lastMessageSenderId: message.senderId,
                    lastMessageIsAdmin: message.isAdmin,
                });
             } catch (setErr) {
                logger.error(`Failed to set initial unread count for ${userId} after increment failed:`, setErr, { messageId });
             }
          }
        }
      });

      // Wait for all unread count updates to complete (or at least be initiated)
      // Note: If one fails, others might still succeed. Consider error handling needs.
      await Promise.all(unreadUpdatePromises);
      logger.info(`Finished processing unread counts for message ${messageId}.`, { structuredData: true });


      // Aggregate all tokens
      const allTokens: string[] = recipients.flatMap(r => r.tokens);
      if (allTokens.length === 0) {
        logger.warn(`No valid FCM tokens found for any recipient for message ${messageId}`, { structuredData: true });
        return;
      }
      logger.info(`Total tokens to send to for message ${messageId}: ${allTokens.length}`, { structuredData: true });


      // 5. Construct Notification Payload
      let notificationBody = 'New message received';
      if (message.type === 'text') {
        notificationBody = message.content.length > 100 ? message.content.substring(0, 97) + '...' : message.content;
      } else if (message.type === 'image') {
        notificationBody = `${senderName} sent an image`;
      }
      // Add conditions for other types if needed

      const payload: admin.messaging.MulticastMessage = {
        notification: {
          title: senderName,
          body: notificationBody,
          // Add sound, badge, etc. if needed
        },
        data: {
          conversationId: conversationId,
          // Add any other data needed by the client to handle the notification
        },
        tokens: allTokens,
        // --- APNS (iOS) Specific Config ---
        apns: {
            headers: {
                'apns-priority': '10', // High priority for immediate delivery
            },
            payload: {
                aps: {
                    sound: 'default', // Use default iOS notification sound
                    badge: 1, // Example: Set badge count to 1 (consider fetching real count)
                    'content-available': 1 // For background updates if needed
                },
            },
        },
        // --- Android Specific Config ---
        android: {
            priority: 'high', // High priority
            notification: {
                sound: 'default', // Use default Android notification sound
                // channelId: 'your_channel_id', // IMPORTANT: Specify channel ID created in your Flutter app
                // icon: 'notification_icon', // Optional: Specify custom icon name (without extension) from android/app/src/main/res/drawable
                // color: '#FF0000', // Optional: Notification color
            },
        },
      };

      // 6. Send Notifications via FCM
      const response = await messaging.sendEachForMulticast(payload);
      logger.info(`FCM send completed for message ${messageId}: ${response.successCount} successes, ${response.failureCount} failures.`, { structuredData: true });


      // 7. Handle Invalid Tokens & Cleanup
      const tokensToRemoveByUser: { [userId: string]: string[] } = {};
      response.responses.forEach((resp, idx) => {
        const token = allTokens[idx];
        if (!resp.success) {
          logger.warn(`Failed to send to token: ${token}`, resp.error, { structuredData: true });

          // Check for specific errors indicating an invalid/unregistered token
          if (
            resp.error?.code === 'messaging/invalid-registration-token' ||
            resp.error?.code === 'messaging/registration-token-not-registered'
          ) {
             // Find which user this token belongs to
             const recipient = recipients.find(r => r.tokens.includes(token));
             if (recipient) {
                 if (!tokensToRemoveByUser[recipient.userId]) {
                     tokensToRemoveByUser[recipient.userId] = [];
                 }
                 if (!tokensToRemoveByUser[recipient.userId].includes(token)) { // Avoid duplicates
                    tokensToRemoveByUser[recipient.userId].push(token);
                 }
             } else {
                 logger.error(`Could not find owner for invalid token ${token}. Cannot schedule for removal.`, { messageId, conversationId });
             }
          }
        }
      });

      // Perform Firestore updates to remove invalid tokens
      const cleanupPromises = Object.entries(tokensToRemoveByUser).map(
        async ([userId, tokens]) => {
            if (tokens.length > 0) {
                logger.info(`Removing ${tokens.length} invalid tokens for user ${userId}: ${tokens.join(', ')}`, { messageId, conversationId });
                try {
                    const userRef = db.collection('users').doc(userId);
                    await userRef.update({
                        fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokens),
                    });
                } catch (err) {
                    logger.error(`Failed to remove tokens for user ${userId}:`, err, { structuredData: true });
                }
            }
        }
      );

      await Promise.all(cleanupPromises);


    } catch (error) {
      logger.error(`Unhandled error processing message ${messageId} in conversation ${conversationId}:`, error, { structuredData: true });
    }
  }
);
