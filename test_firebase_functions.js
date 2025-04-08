// Firebase Cloud Functions Test Script
// Run with: node test_firebase_functions.js
//
// This script tests Firebase Cloud Functions directly using the Node.js Admin SDK
// Make sure to run 'npm install firebase-admin' before running this script

const admin = require('firebase-admin');
const readline = require('readline');
const crypto = require('crypto');

// Configuration
const REGION = 'us-central1';

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

// Function to initialize Firebase Admin SDK
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

// Function to test the ping function
async function testPingFunction() {
  console.log('\n=== Testing ping function ===');
  
  try {
    // Get the functions instance for the region
    const functions = admin.functions(REGION);
    
    // Call the ping function
    console.log(`Calling ping function in ${REGION}...`);
    const startTime = Date.now();
    
    const result = await functions.httpsCallable('ping')();
    
    const duration = Date.now() - startTime;
    console.log(`✅ Ping successful! (${duration}ms)`);
    console.log('Response:', result.data);
    
    return true;
  } catch (error) {
    console.error('❌ Ping function error:', error);
    return false;
  }
}

// Function to test the createUser function
async function testCreateUserFunction(email, password, displayName, salesforceId) {
  console.log('\n=== Testing createUser function ===');
  
  if (!email) {
    console.error('❌ Email is required');
    return false;
  }
  
  // Generate password if not provided
  if (!password) {
    password = generateSecurePassword();
    console.log(`Generated password: ${password}`);
  }
  
  // Use email username as display name if not provided
  if (!displayName) {
    displayName = email.split('@')[0];
    console.log(`Using default display name: ${displayName}`);
  }
  
  try {
    // Get the functions instance for the region
    const functions = admin.functions(REGION);
    
    // Prepare data for the function call
    const data = {
      email,
      password,
      displayName,
      role: 'reseller'
    };
    
    if (salesforceId) {
      data.salesforceId = salesforceId;
      console.log(`Including Salesforce ID: ${salesforceId}`);
    }
    
    // Log the data being sent (without password)
    const logData = { ...data, password: '********' };
    console.log('Sending data:', logData);
    
    // Call the createUser function
    console.log('Calling createUser function...');
    const startTime = Date.now();
    
    const result = await functions.httpsCallable('createUser')(data);
    
    const duration = Date.now() - startTime;
    console.log(`✅ User created successfully! (${duration}ms)`);
    console.log('Response:', result.data);
    
    // Return success with user info
    return {
      success: true,
      userId: result.data.uid,
      email: result.data.email,
      password
    };
  } catch (error) {
    console.error('❌ createUser function error:', error);
    
    if (error.code && error.message) {
      console.error(`Error code: ${error.code}`);
      console.error(`Error message: ${error.message}`);
      
      if (error.details) {
        console.error('Error details:', error.details);
      }
    }
    
    return { success: false };
  }
}

// Function to simulate Salesforce sync
async function simulateSalesforceSync(userId, salesforceId) {
  if (!userId || !salesforceId) {
    console.error('❌ User ID and Salesforce ID are required for sync');
    return false;
  }
  
  console.log('\n=== Simulating Salesforce sync ===');
  console.log(`Synchronizing User ID ${userId} with Salesforce ID ${salesforceId}...`);
  
  // In a real implementation, we would call our Salesforce sync service here
  // For now, we'll just simulate it with a delay
  
  return new Promise((resolve) => {
    setTimeout(() => {
      console.log('✅ Salesforce sync simulation completed successfully');
      resolve(true);
    }, 1000);
  });
}

// Main interactive function
async function runInteractive() {
  console.log('=== Firebase Cloud Functions Test Tool ===');
  
  // Initialize Firebase Admin SDK
  const initialized = await initializeFirebase();
  if (!initialized) {
    rl.close();
    return;
  }
  
  // Test the ping function first
  const pingSuccess = await testPingFunction();
  if (!pingSuccess) {
    console.log('❌ Ping test failed. Cloud Functions might not be available.');
    rl.question('Do you want to continue anyway? (y/n): ', async (answer) => {
      if (answer.toLowerCase() !== 'y') {
        rl.close();
        return;
      }
      await promptForUserTest();
    });
  } else {
    await promptForUserTest();
  }
}

// Function to prompt for user creation test
async function promptForUserTest() {
  console.log('\n=== User Creation Test ===');
  
  rl.question('Enter email for the new user: ', (email) => {
    if (!email) {
      console.log('❌ Email is required. Exiting.');
      rl.close();
      return;
    }
    
    rl.question('Enter password (leave empty to generate): ', (password) => {
      rl.question('Enter display name (leave empty for default): ', (displayName) => {
        rl.question('Enter Salesforce ID (optional): ', async (salesforceId) => {
          // Run the create user test
          const result = await testCreateUserFunction(
            email, 
            password || null, 
            displayName || null, 
            salesforceId || null
          );
          
          if (result.success) {
            console.log('\n=== User Creation Summary ===');
            console.log(`Email: ${result.email}`);
            console.log(`Password: ${result.password}`);
            console.log(`User ID: ${result.userId}`);
            
            if (salesforceId) {
              await simulateSalesforceSync(result.userId, salesforceId);
            }
            
            console.log('\n✅ Test completed successfully!');
          } else {
            console.log('\n❌ User creation test failed.');
          }
          
          rl.close();
        });
      });
    });
  });
}

// Entry point
runInteractive().catch(error => {
  console.error('Unhandled error:', error);
  rl.close();
}); 