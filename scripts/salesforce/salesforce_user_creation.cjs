// Salesforce-Firebase User Creation Script
// Run with: node salesforce_user_creation.cjs
//
// This script implements the full account creation process:
// 1. Verify Salesforce ID exists
// 2. Check if account already exists with that ID in Firestore
// 3. Get user data from Salesforce
// 4. Create Firebase authentication for the email
// 5. Create Firestore document with UID as the document name
// 6. Populate document with required fields from Salesforce

const admin = require('firebase-admin');
const axios = require('axios');
const readline = require('readline');
const fs = require('fs');
const crypto = require('crypto');

// Configuration
const REGION = 'us-central1';
const PROJECT_ID = 'twogetherapp-65678';
const SALESFORCE_API_VERSION = 'v58.0'; // Adjust to match your Salesforce API version
const SALESFORCE_TOKEN_FUNCTION = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/getSalesforceAccessToken`;
const DEFAULT_SALESFORCE_INSTANCE = 'https://ldfgrupo.my.salesforce.com'; // Fallback if not returned by function

// Field mapping from Salesforce to Firebase (based on Sync-SalesforceUsers.ps1)
const FIELD_MAPPING = {
    "Id": "salesforceId",
    "Name": "displayName",
    "FirstName": "firstName",
    "LastName": "lastName",
    "Email": "email",
    "Phone": "phoneNumber",
    "MobilePhone": "mobilePhone",
    "Department": "department",
    "IsActive": "isActive",
    "LastLoginDate": "lastSalesforceLoginDate",
    "Username": "salesforceUsername",
    "Revendedor_Retail__c": "revendedorRetail"
};

// Initialize command line interface
const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

// Function to generate a secure password
function generateSecurePassword(length = 12) {
    const upperChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowerChars = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    const specialChars = '!@#$%^&*()';
    const allChars = upperChars + lowerChars + numbers + specialChars;
    
    // Ensure at least one of each type
    let password = '';
    password += upperChars.charAt(Math.floor(Math.random() * upperChars.length));
    password += lowerChars.charAt(Math.floor(Math.random() * lowerChars.length));
    password += numbers.charAt(Math.floor(Math.random() * numbers.length));
    password += specialChars.charAt(Math.floor(Math.random() * specialChars.length));
    
    // Add random characters to reach desired length
    const remainingLength = length - password.length;
    for (let i = 0; i < remainingLength; i++) {
        password += allChars.charAt(Math.floor(Math.random() * allChars.length));
    }
    
    // Shuffle the password characters
    return password.split('').sort(() => 0.5 - Math.random()).join('');
}

// Initialize Firebase Admin SDK
async function initializeFirebase() {
    try {
        console.log('Initializing Firebase Admin SDK...');
        
        // Check if service account file exists
        const serviceAccountPath = './service-account-key.json';
        
        try {
            // Try to load service account from file
            const serviceAccount = require(serviceAccountPath);
            
            // Initialize admin SDK with service account
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount)
            });
            
            console.log('✅ Firebase Admin SDK initialized with service account');
            return true;
        } catch (e) {
            console.log('❌ Service account file not found or invalid:', e.message);
            console.log('Please place a valid service-account-key.json file in the current directory.');
            return false;
        }
    } catch (error) {
        console.error('❌ Failed to initialize Firebase:', error);
        return false;
    }
}

// Get Salesforce token using Firebase function - same as in Get-SalesforceToken.ps1
async function getSalesforceToken() {
    console.log('Getting Salesforce token from Firebase function...');
    console.log(`Calling: ${SALESFORCE_TOKEN_FUNCTION}`);
    
    try {
        const response = await axios({
            method: 'post',
            url: SALESFORCE_TOKEN_FUNCTION,
            headers: {
                'Content-Type': 'application/json'
            },
            data: { data: {} } // Empty data object for the function call
        });
        
        // Check if the response is successful
        if (response.status !== 200) {
            throw new Error(`Function call failed with status code: ${response.status}`);
        }
        
        // Extract the token and instance URL from the response
        const jsonResponse = response.data;
        
        // Firebase callable functions wrap the actual return value in a 'result' property
        if (!jsonResponse || !jsonResponse.result || 
            !jsonResponse.result.access_token || !jsonResponse.result.instance_url) {
            throw new Error('Function response format was unexpected');
        }
        
        const accessToken = jsonResponse.result.access_token;
        const instanceUrl = jsonResponse.result.instance_url;
        
        if (!accessToken || !instanceUrl) {
            throw new Error('Function returned empty access_token or instance_url');
        }
        
        console.log('✅ Successfully obtained Salesforce token and instance URL');
        console.log(`Instance URL: ${instanceUrl}`);
        console.log(`Access Token: ${accessToken.substring(0, Math.min(10, accessToken.length))}...`);
        
        return {
            accessToken,
            instanceUrl
        };
    } catch (error) {
        console.error('❌ Failed to get Salesforce token from Firebase function:', error.message);
        
        if (error.response) {
            console.error('Error response data:', error.response.data);
        }
        
        // Inform the user but don't throw yet - we'll try with fallback
        console.log('⚠️ Attempting to continue with fallback settings...');
        
        // Prompt user if they want to enter credentials manually
        return new Promise((resolve) => {
            rl.question('Do you want to manually enter a Salesforce access token? (y/n): ', async (answer) => {
                if (answer.toLowerCase() === 'y') {
                    rl.question('Salesforce Access Token: ', (token) => {
                        resolve({
                            accessToken: token,
                            instanceUrl: DEFAULT_SALESFORCE_INSTANCE
                        });
                    });
                } else {
                    throw new Error('Failed to get Salesforce token and user declined manual entry');
                }
            });
        });
    }
}

// Check if a Salesforce ID exists and is valid
async function checkSalesforceId(salesforceId, salesforceAuth) {
    console.log(`\n=== Checking if Salesforce ID ${salesforceId} exists ===`);
    
    try {
        // Build the SOQL query to get all fields that we need to map
        const fields = Object.keys(FIELD_MAPPING).join(', ');
        const query = `SELECT ${fields} FROM User WHERE Id = '${salesforceId}' LIMIT 1`;
        
        // Make the API call to Salesforce
        const response = await axios({
            method: 'get',
            url: `${salesforceAuth.instanceUrl}/services/data/${SALESFORCE_API_VERSION}/query?q=${encodeURIComponent(query)}`,
            headers: {
                'Authorization': `Bearer ${salesforceAuth.accessToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        // Check if any records were returned
        if (response.data.records && response.data.records.length > 0) {
            console.log('✅ Salesforce ID is valid and exists');
            return {
                exists: true,
                userData: response.data.records[0]
            };
        } else {
            console.log('❌ Salesforce ID does not exist or is invalid');
            return {
                exists: false,
                userData: null
            };
        }
    } catch (error) {
        console.error('❌ Error checking Salesforce ID:', error.message);
        if (error.response) {
            console.error('Error response:', error.response.data);
        }
        throw error;
    }
}

// Check if user already exists in Firestore with this Salesforce ID
async function checkUserExistsInFirestore(salesforceId) {
    console.log(`\n=== Checking if user with Salesforce ID ${salesforceId} already exists in Firestore ===`);
    
    try {
        // Query Firestore for documents with matching salesforceId
        const snapshot = await admin.firestore()
            .collection('users')
            .where('salesforceId', '==', salesforceId)
            .limit(1)
            .get();
        
        if (!snapshot.empty) {
            const doc = snapshot.docs[0];
            console.log(`❌ User already exists in Firestore with UID: ${doc.id}`);
            return {
                exists: true,
                userDoc: doc
            };
        } else {
            console.log('✅ No existing user found with this Salesforce ID');
            return {
                exists: false
            };
        }
    } catch (error) {
        console.error('❌ Error checking Firestore:', error);
        throw error;
    }
}

// Convert Salesforce data to Firestore document data using our mapping
function mapSalesforceDataToFirestore(salesforceData) {
    console.log('\n=== Mapping Salesforce data to Firestore fields ===');
    
    const firestoreData = {};
    
    // Apply the field mapping
    for (const [sfField, fbField] of Object.entries(FIELD_MAPPING)) {
        if (salesforceData[sfField] !== undefined) {
            firestoreData[fbField] = salesforceData[sfField];
            console.log(`Mapping ${sfField} → ${fbField}: ${salesforceData[sfField]}`);
        }
    }
    
    // Add additional required fields
    firestoreData.createdAt = admin.firestore.FieldValue.serverTimestamp();
    firestoreData.isActive = true;
    firestoreData.isEnabled = true;
    firestoreData.isFirstLogin = true;
    firestoreData.role = "reseller";
    firestoreData.salesforceSyncedAt = admin.firestore.FieldValue.serverTimestamp();
    
    return firestoreData;
}

// Create a user in Firebase Authentication
async function createFirebaseAuthUser(email, password, displayName) {
    console.log(`\n=== Creating Firebase Authentication user for ${email} ===`);
    
    try {
        // Check if user already exists
        try {
            const userRecord = await admin.auth().getUserByEmail(email);
            console.log(`⚠️ User already exists in Firebase Auth with UID: ${userRecord.uid}`);
            return userRecord;
        } catch (error) {
            // User doesn't exist, continue with creation
            if (error.code === 'auth/user-not-found') {
                console.log('User does not exist in Firebase Auth, proceeding with creation...');
            } else {
                throw error;
            }
        }
        
        // Create the user
        const userRecord = await admin.auth().createUser({
            email: email,
            password: password,
            displayName: displayName,
            disabled: false
        });
        
        console.log(`✅ Firebase Auth user created with UID: ${userRecord.uid}`);
        return userRecord;
    } catch (error) {
        console.error('❌ Error creating Firebase Auth user:', error);
        throw error;
    }
}

// Create a document in Firestore with the user data
async function createFirestoreDocument(uid, firestoreData) {
    console.log(`\n=== Creating Firestore document for user ${uid} ===`);
    
    try {
        await admin.firestore()
            .collection('users')
            .doc(uid)
            .set(firestoreData);
        
        console.log(`✅ Firestore document created for user ${uid}`);
        return true;
    } catch (error) {
        console.error('❌ Error creating Firestore document:', error);
        throw error;
    }
}

// Main function to create a user
async function createUser(salesforceId, password = null) {
    console.log(`\n=== Starting user creation process for Salesforce ID: ${salesforceId} ===`);
    
    try {
        // Initialize Firebase
        const firebaseInitialized = await initializeFirebase();
        if (!firebaseInitialized) {
            throw new Error('Firebase initialization failed');
        }
        
        // Get Salesforce authentication using the Firebase function (same as in Get-SalesforceToken.ps1)
        const salesforceAuth = await getSalesforceToken();
        
        // Step 1: Check if Salesforce ID exists
        const salesforceCheck = await checkSalesforceId(salesforceId, salesforceAuth);
        if (!salesforceCheck.exists) {
            throw new Error(`Salesforce ID ${salesforceId} does not exist`);
        }
        
        const salesforceData = salesforceCheck.userData;
        
        // Step 2: Check if user already exists in Firestore
        const firestoreCheck = await checkUserExistsInFirestore(salesforceId);
        if (firestoreCheck.exists) {
            throw new Error(`User with Salesforce ID ${salesforceId} already exists in Firestore`);
        }
        
        // Step 3: Extract relevant data from Salesforce
        console.log('\n=== Salesforce User Data ===');
        console.log(JSON.stringify(salesforceData, null, 2));
        
        // Get email from Salesforce data
        const email = salesforceData.Email;
        if (!email) {
            throw new Error('Email not found in Salesforce data');
        }
        
        // Get display name from Salesforce
        const displayName = salesforceData.Name || `${salesforceData.FirstName} ${salesforceData.LastName}`.trim();
        
        // Generate password if not provided
        if (!password) {
            password = generateSecurePassword();
            console.log(`Generated password: ${password}`);
        }
        
        // Step 4: Create Firebase Authentication user
        const userRecord = await createFirebaseAuthUser(email, password, displayName);
        
        // Step 5 & 6: Create Firestore document and populate with required fields
        const firestoreData = mapSalesforceDataToFirestore(salesforceData);
        await createFirestoreDocument(userRecord.uid, firestoreData);
        
        // Successfully created the user
        console.log('\n=== User Creation Summary ===');
        console.log(`Email: ${email}`);
        console.log(`Display Name: ${displayName}`);
        console.log(`Password: ${password}`);
        console.log(`Firebase UID: ${userRecord.uid}`);
        console.log(`Salesforce ID: ${salesforceId}`);
        
        console.log('\n✅ User creation completed successfully!');
        
        return {
            success: true,
            uid: userRecord.uid,
            email: email,
            displayName: displayName,
            password: password,
            salesforceId: salesforceId
        };
    } catch (error) {
        console.error(`\n❌ User creation failed: ${error.message}`);
        return {
            success: false,
            error: error.message
        };
    }
}

// Main interactive function
async function runInteractive() {
    console.log('=== Salesforce-Firebase User Creation Tool ===');
    
    rl.question('Enter Salesforce ID for the new user: ', async (salesforceId) => {
        if (!salesforceId) {
            console.log('❌ Salesforce ID is required. Exiting.');
            rl.close();
            return;
        }
        
        rl.question('Enter password (leave empty to generate): ', async (password) => {
            try {
                // Run the user creation process
                const result = await createUser(salesforceId, password || null);
                
                if (result.success) {
                    console.log('\n✅ Test completed successfully!');
                } else {
                    console.log('\n❌ User creation failed.');
                }
            } catch (error) {
                console.error('Error in user creation process:', error);
            } finally {
                rl.close();
            }
        });
    });
}

// Entry point
if (require.main === module) {
    runInteractive().catch(error => {
        console.error('Unhandled error:', error);
        rl.close();
        process.exit(1);
    });
}

// Export functions for testing or programmatic use
module.exports = {
    createUser,
    checkSalesforceId,
    checkUserExistsInFirestore,
    mapSalesforceDataToFirestore
}; 