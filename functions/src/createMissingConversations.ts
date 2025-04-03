import * as admin from 'firebase-admin';

// Initialize the app if it hasn't been initialized yet
try {
  admin.initializeApp();
} catch (e) {
  console.log('Firebase admin already initialized');
}

/**
 * Migration script to create conversation documents for resellers who don't have one yet.
 * This ensures every reseller has a conversation record in Firestore.
 * Run this script with:
 * npx ts-node src/createMissingConversations.ts
 */
async function createMissingConversations() {
  const db = admin.firestore();
  
  try {
    console.log('Starting migration: Creating missing conversations for resellers...');
    
    // Query all reseller users
    const usersSnapshot = await db.collection('users')
      .where('role', '==', 'reseller')
      .get();
    
    console.log(`Found ${usersSnapshot.size} reseller users`);
    
    let createdCount = 0;
    let existingCount = 0;
    
    for (const userDoc of usersSnapshot.docs) {
      const resellerId = userDoc.id;
      
      // Check if a conversation exists for this reseller
      const convSnapshot = await db.collection('conversations')
        .where('resellerId', '==', resellerId)
        .limit(1)
        .get();
      
      if (convSnapshot.empty) {
        const userData = userDoc.data();
        const conversationData = {
          resellerId,
          resellerName: userData.displayName || userData.email || 'Unknown User',
          lastMessageContent: null,  // No stored messages
          lastMessageTime: null,
          active: false,             // Initially inactive
          unreadCounts: {},
          unreadByAdmin: false,
          unreadByReseller: false,
          unreadCount: 0,
          participants: ['admin', resellerId],
          activeUsers: [],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        
        await db.collection('conversations').add(conversationData);
        console.log(`Created conversation for reseller: ${resellerId} (${userData.email || 'unknown email'})`);
        createdCount++;
      } else {
        console.log(`Conversation already exists for reseller: ${resellerId}`);
        existingCount++;
      }
    }
    
    console.log('Migration complete:');
    console.log(`- Created ${createdCount} new conversations`);
    console.log(`- Found ${existingCount} existing conversations`);
    console.log(`- Total resellers processed: ${usersSnapshot.size}`);
    
  } catch (error) {
    console.error('Error during migration:', error);
  }
}

// Execute the migration
createMissingConversations().then(() => {
  console.log('Migration script completed.');
  process.exit(0);
}).catch(error => {
  console.error('Migration script failed:', error);
  process.exit(1);
}); 