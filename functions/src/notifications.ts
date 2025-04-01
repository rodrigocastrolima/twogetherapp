import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';

/**
 * Cloud Function that triggers when a new message is added to Firestore
 * and sends push notifications to the appropriate recipients.
 * 
 * Note: This function is set up with the foundation for FCM integration.
 * To fully implement push notifications, you'll need to:
 * 1. Store FCM tokens for each user in Firestore
 * 2. Set up your mobile app to receive FCM notifications
 */
export const onNewMessageNotification = functions.firestore
  .onDocumentCreated('conversations/{conversationId}/messages/{messageId}', async (event) => {
    const message = event.data?.data();
    const conversationId = event.params.conversationId;
    
    if (!message) {
      console.log('No message data found');
      return;
    }
    
    try {
      // Get the conversation document
      const db = admin.firestore();
      const conversationDoc = await db
        .collection('conversations')
        .doc(conversationId)
        .get();
      
      if (!conversationDoc.exists) {
        console.log(`Conversation ${conversationId} does not exist`);
        return;
      }
      
      const conversation = conversationDoc.data();
      if (!conversation) {
        console.log(`No data in conversation ${conversationId}`);
        return;
      }
      
      // Check if recipient is active in conversation (should not send notifications)
      const activeUsers = conversation.activeUsers || [];
      
      // Get sender and determine recipients
      const isFromAdmin = message.isFromAdmin;
      const senderName = isFromAdmin ? 'Support Team' : conversation.resellerName;
      let notificationContent = '';
      
      if (message.type === 'text') {
        notificationContent = message.content;
      } else if (message.type === 'image') {
        notificationContent = `${senderName} sent an image`;
      } else {
        notificationContent = 'New message received';
      }
      
      // Prepare notification data
      const notificationData = {
        title: senderName,
        body: notificationContent,
        conversationId: conversationId,
        timestamp: admin.firestore.Timestamp.now().toMillis().toString(),
      };
      
      // For future FCM implementation:
      if (isFromAdmin) {
        // Check if reseller is active in the conversation
        const resellerId = conversation.resellerId;
        
        // Only send notification if reseller is not active in conversation
        if (!activeUsers.includes(resellerId)) {
          await sendNotificationToReseller(resellerId, notificationData);
          console.log(`Notification sent to reseller ${resellerId}`);
        } else {
          console.log(`Reseller ${resellerId} is active in conversation - no notification sent`);
        }
      } else {
        // Check if admin is active in the conversation
        
        // Only send notification if admin is not active in conversation
        if (!activeUsers.includes('admin')) {
          await sendNotificationToAdmins(notificationData);
          console.log(`Notification sent to admins`);
        } else {
          console.log(`Admin is active in conversation - no notification sent`);
        }
      }
      
    } catch (error) {
      console.error('Error sending notification:', error);
    }
  });

/**
 * Sends a notification to a specific reseller.
 * Note: This function will be fully implemented when FCM tokens are stored in user profiles.
 */
async function sendNotificationToReseller(
  resellerId: string, 
  notificationData: { title: string; body: string; conversationId: string; timestamp: string }
) {
  try {
    // TODO: Implement FCM token retrieval when available
    // For now, we'll just log that we would send a notification
    console.log(`Would send notification to reseller ${resellerId}: ${JSON.stringify(notificationData)}`);
    
    /* 
    // Example implementation once FCM tokens are stored:
    const userDoc = await admin.firestore().collection('users').doc(resellerId).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      if (userData && userData.fcmToken) {
        await admin.messaging().send({
          token: userData.fcmToken,
          notification: {
            title: notificationData.title,
            body: notificationData.body,
          },
          data: {
            conversationId: notificationData.conversationId,
            timestamp: notificationData.timestamp,
          },
        });
      }
    }
    */
    
  } catch (error) {
    console.error(`Error sending notification to reseller ${resellerId}:`, error);
  }
}

/**
 * Sends a notification to all admin users.
 * Note: This function will be fully implemented when FCM tokens are stored in user profiles.
 */
async function sendNotificationToAdmins(
  notificationData: { title: string; body: string; conversationId: string; timestamp: string }
) {
  try {
    // TODO: Implement FCM token retrieval when available
    // For now, we'll just log that we would send a notification
    console.log(`Would send notification to admins: ${JSON.stringify(notificationData)}`);
    
    /*
    // Example implementation once FCM tokens are stored:
    const adminUsersQuery = await admin.firestore().collection('users')
      .where('role', '==', 'admin')
      .get();
      
    const fcmTokens = adminUsersQuery.docs
      .map(doc => doc.data().fcmToken)
      .filter(token => token); // Filter out undefined/null tokens
      
    // Send to each admin
    for (const token of fcmTokens) {
      await admin.messaging().send({
        token: token,
        notification: {
          title: notificationData.title,
          body: notificationData.body,
        },
        data: {
          conversationId: notificationData.conversationId,
          timestamp: notificationData.timestamp,
        },
      });
    }
    */
    
  } catch (error) {
    console.error('Error sending notification to admins:', error);
  }
} 