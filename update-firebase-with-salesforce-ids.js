/**
 * MIGRATION SCRIPT - ONE-TIME USE ONLY
 * 
 * Script to match existing Firebase Authentication users with Salesforce users
 * and update Firebase users with their corresponding Salesforce User IDs.
 * 
 * Prerequisites:
 * - Node.js installed (v14+ recommended)
 * - Firebase Admin SDK installed (`npm install firebase-admin`)
 * - Axios for API calls (`npm install axios`)
 * - Existing Firebase service account key file
 * 
 * Usage:
 * node update-firebase-with-salesforce-ids.js [path-to-service-account-key]
 * 
 * If no path is provided, the script will look for "service-account-key.json" in the current directory.
 */

const admin = require('firebase-admin');
const axios = require('axios');
const fs = require('fs');
const path = require('path');

// Get service account path from command line argument or use default
const serviceAccountPath = process.argv[2] || path.join(__dirname, 'service-account-key.json');

console.log(`Using service account key from: ${serviceAccountPath}`);

// Check if the service account file exists
if (!fs.existsSync(serviceAccountPath)) {
  console.error(`Service account key file not found at: ${serviceAccountPath}`);
  console.error('Please provide the correct path to your Firebase service account key file.');
  console.error('Usage: node update-firebase-with-salesforce-ids.js [path-to-service-account-key]');
  process.exit(1);
}

// Initialize Firebase Admin
try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath)
  });
  console.log('Firebase Admin SDK initialized successfully');
} catch (error) {
  console.error('Failed to initialize Firebase Admin SDK:', error);
  process.exit(1);
}

// Salesforce configuration
const SALESFORCE_INSTANCE_URL = 'https://ldfgrupo.my.salesforce.com'; // Update with your instance URL

// Function to get Salesforce access token
async function getSalesforceAccessToken() {
  try {
    // Call the Firebase function to get the Salesforce token
    console.log('Calling Firebase function to get Salesforce token...');
    const response = await axios.post(
      'https://us-central1-twogetherapp-65678.cloudfunctions.net/getSalesforceAccessToken',
      { data: {} }
    );
    
    if (response.data && response.data.result && response.data.result.access_token) {
      return {
        accessToken: response.data.result.access_token,
        instanceUrl: response.data.result.instance_url || SALESFORCE_INSTANCE_URL
      };
    } else {
      throw new Error('Invalid response format');
    }
  } catch (error) {
    console.error('Error getting Salesforce token:', error.message);
    throw error;
  }
}

// Function to query Salesforce for users
async function querySalesforceUsers(accessToken, instanceUrl) {
  try {
    // Query to get all active users with their IDs, names, and emails
    const query = 'SELECT Id, Name, Email, IsActive FROM User WHERE IsActive = true';
    const encodedQuery = encodeURIComponent(query);
    
    console.log(`Querying Salesforce API at ${instanceUrl}...`);
    const response = await axios.get(
      `${instanceUrl}/services/data/v58.0/query/?q=${encodedQuery}`,
      {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        }
      }
    );
    
    if (response.data && response.data.records) {
      return response.data.records;
    } else {
      throw new Error('Invalid response or no records found');
    }
  } catch (error) {
    console.error('Error querying Salesforce users:', error.message);
    if (error.response) {
      console.error('Response data:', error.response.data);
      console.error('Response status:', error.response.status);
    }
    throw error;
  }
}

// Function to get all Firebase users
async function getFirebaseUsers() {
  try {
    const users = [];
    let nextPageToken;
    
    console.log('Fetching all Firebase users (this may take a while for large user bases)...');
    
    // Firebase only returns 1000 users at a time, so we need to paginate
    do {
      const listUsersResult = await admin.auth().listUsers(1000, nextPageToken);
      users.push(...listUsersResult.users);
      nextPageToken = listUsersResult.pageToken;
      
      if (nextPageToken) {
        console.log(`Fetched ${users.length} users so far, continuing to next page...`);
      }
    } while (nextPageToken);
    
    return users;
  } catch (error) {
    console.error('Error getting Firebase users:', error);
    throw error;
  }
}

// Function to update Firebase user with Salesforce ID
async function updateFirebaseUser(uid, salesforceId, email) {
  try {
    // First, get the current custom claims
    const user = await admin.auth().getUser(uid);
    const currentClaims = user.customClaims || {};
    
    // Update the custom claims with the Salesforce ID
    const newClaims = {
      ...currentClaims,
      salesforceId: salesforceId
    };
    
    // Set the custom claims
    await admin.auth().setCustomUserClaims(uid, newClaims);
    
    // Also update the user document in Firestore
    await admin.firestore().collection('users').doc(uid).set({
      salesforceId: salesforceId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    
    console.log(`✓ Updated user ${email} (Firebase UID: ${uid}) with Salesforce ID: ${salesforceId}`);
    return true;
  } catch (error) {
    console.error(`✗ Error updating user ${email}:`, error);
    return false;
  }
}

// Main function to run the script
async function main() {
  console.log('=========================================');
  console.log('  FIREBASE-SALESFORCE USER ID MIGRATION  ');
  console.log('  ONE-TIME MIGRATION TOOL                ');
  console.log('=========================================');
  
  try {
    // Step 1: Get Salesforce access token
    console.log('\n[1/4] Getting Salesforce access token...');
    const { accessToken, instanceUrl } = await getSalesforceAccessToken();
    console.log('✓ Successfully obtained Salesforce access token');
    
    // Step 2: Query Salesforce for users
    console.log('\n[2/4] Querying Salesforce for users...');
    const salesforceUsers = await querySalesforceUsers(accessToken, instanceUrl);
    console.log(`✓ Found ${salesforceUsers.length} users in Salesforce`);
    
    // Create a map of Salesforce users by email for easy lookup
    const salesforceUsersByEmail = {};
    for (const user of salesforceUsers) {
      if (user.Email) {
        salesforceUsersByEmail[user.Email.toLowerCase()] = user;
      }
    }
    
    // Step 3: Get all Firebase users
    console.log('\n[3/4] Getting all Firebase users...');
    const firebaseUsers = await getFirebaseUsers();
    console.log(`✓ Found ${firebaseUsers.length} users in Firebase`);
    
    // Step 4: Match Firebase users with Salesforce users and update
    console.log('\n[4/4] Matching users and updating Firebase...');
    let matchedCount = 0;
    let updatedCount = 0;
    let notFoundCount = 0;
    
    console.log('\nProcessing users:');
    for (const firebaseUser of firebaseUsers) {
      if (firebaseUser.email) {
        const lowerEmail = firebaseUser.email.toLowerCase();
        const salesforceUser = salesforceUsersByEmail[lowerEmail];
        
        if (salesforceUser) {
          matchedCount++;
          process.stdout.write(`• Processing ${firebaseUser.email} - Match found! Salesforce ID: ${salesforceUser.Id}`);
          
          // Check if user already has this Salesforce ID
          const hasCorrectId = firebaseUser.customClaims && 
                               firebaseUser.customClaims.salesforceId === salesforceUser.Id;
          
          if (!hasCorrectId) {
            const success = await updateFirebaseUser(
              firebaseUser.uid,
              salesforceUser.Id,
              firebaseUser.email
            );
            if (success) updatedCount++;
            process.stdout.write(' ✓ Updated\n');
          } else {
            process.stdout.write(' ⦿ Already has correct ID\n');
          }
        } else {
          notFoundCount++;
          console.log(`• ${firebaseUser.email} - ✗ No matching Salesforce user found`);
        }
      }
    }
    
    // Print summary
    console.log('\n=========================================');
    console.log('              MIGRATION SUMMARY          ');
    console.log('=========================================');
    console.log(`Total Firebase users: ${firebaseUsers.length}`);
    console.log(`Total Salesforce users: ${salesforceUsers.length}`);
    console.log(`Matched users: ${matchedCount}`);
    console.log(`Updated users: ${updatedCount}`);
    console.log(`Users not found in Salesforce: ${notFoundCount}`);
    console.log('=========================================');
    
    if (notFoundCount > 0) {
      console.log('\nNOTE: Users without matching Salesforce accounts will need to be manually');
      console.log('associated or added to Salesforce as needed by the backoffice team.');
    }
    
    console.log('\nMigration completed successfully!');
    
  } catch (error) {
    console.error('\n✗ Migration failed:', error);
    console.error('Please check the error message above and try again.');
  } finally {
    // Properly exit the Node.js process
    process.exit(0);
  }
}

// Run the script
main(); 