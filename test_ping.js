const https = require('https');
const fs = require('fs');

// Configuration
const REGION = 'us-central1';
const PROJECT_ID = 'twogetherapp-65678'; // Your Firebase project ID

async function testPingFunction() {
  console.log('=== Testing ping function ===');
  
  try {
    // Load service account key
    const serviceAccount = JSON.parse(fs.readFileSync('./service-account-key.json'));
    
    // Create a token manually for authentication
    console.log('Loading service account key...');
    
    // URL for the ping function
    const functionUrl = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/ping`;
    console.log(`Calling ping function at: ${functionUrl}`);
    
    // Make an HTTP request
    return new Promise((resolve, reject) => {
      const data = JSON.stringify({
        data: {} // Empty data object for ping function
      });
      
      const options = {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': data.length
        }
      };
      
      const req = https.request(functionUrl, options, (res) => {
        let responseData = '';
        
        res.on('data', (chunk) => {
          responseData += chunk;
        });
        
        res.on('end', () => {
          console.log('Status Code:', res.statusCode);
          console.log('Response Headers:', res.headers);
          
          try {
            const jsonResponse = JSON.parse(responseData);
            console.log('Response:', jsonResponse);
            resolve(jsonResponse);
          } catch (e) {
            console.log('Raw Response:', responseData);
            resolve(responseData);
          }
        });
      });
      
      req.on('error', (error) => {
        console.error('Request error:', error);
        reject(error);
      });
      
      req.write(data);
      req.end();
    });
  } catch (error) {
    console.error('Error:', error);
    return null;
  }
}

// Run the test
testPingFunction().then(() => {
  console.log('Test completed');
}).catch(error => {
  console.error('Test failed:', error);
}); 