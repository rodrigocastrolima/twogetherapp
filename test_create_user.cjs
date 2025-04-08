const https = require('https');
const fs = require('fs');
const readline = require('readline');

// Configuration
const REGION = 'us-central1';
const PROJECT_ID = 'twogetherapp-65678'; // Your Firebase project ID

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
    // Load service account key
    console.log('Loading service account key...');
    const serviceAccount = JSON.parse(fs.readFileSync('./service-account-key.json'));
    
    // Prepare data for the function call
    const data = {
      data: {
        email,
        password,
        displayName,
        role: 'reseller'
      }
    };
    
    if (salesforceId) {
      data.data.salesforceId = salesforceId;
      console.log(`Including Salesforce ID: ${salesforceId}`);
    }
    
    // Log the data being sent (without password)
    const logData = { ...data, data: { ...data.data, password: '********' } };
    console.log('Sending data:', JSON.stringify(logData, null, 2));
    
    // URL for the createUser function
    const functionUrl = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/createUser`;
    console.log(`Calling createUser function at: ${functionUrl}`);
    
    // Make the HTTP request
    return new Promise((resolve, reject) => {
      const jsonData = JSON.stringify(data);
      
      const options = {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': jsonData.length
        }
      };
      
      const req = https.request(functionUrl, options, (res) => {
        let responseData = '';
        
        res.on('data', (chunk) => {
          responseData += chunk;
        });
        
        res.on('end', () => {
          console.log('Status Code:', res.statusCode);
          
          try {
            const jsonResponse = JSON.parse(responseData);
            console.log('Response:', JSON.stringify(jsonResponse, null, 2));
            
            if (res.statusCode === 200 && jsonResponse.result) {
              console.log('✅ User creation successful!');
              resolve({
                success: true,
                userId: jsonResponse.result.uid,
                email: jsonResponse.result.email,
                password,
                response: jsonResponse
              });
            } else {
              console.error('❌ User creation failed with error:', jsonResponse);
              resolve({ success: false, response: jsonResponse });
            }
          } catch (e) {
            console.log('Raw Response:', responseData);
            resolve({ success: false, raw: responseData });
          }
        });
      });
      
      req.on('error', (error) => {
        console.error('Request error:', error);
        reject(error);
      });
      
      req.write(jsonData);
      req.end();
    });
  } catch (error) {
    console.error('Error in testCreateUserFunction:', error);
    return { success: false, error: error.message };
  }
}

// Main interactive function
async function runTest() {
  console.log('=== Firebase User Creation Test Tool ===');
  
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

// Run the test
runTest().catch(error => {
  console.error('Unhandled error:', error);
  rl.close();
}); 