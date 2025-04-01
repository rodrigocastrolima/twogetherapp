const https = require('https');

// Prepare the request payload for a Firebase Cloud Function
const data = JSON.stringify({
  data: {} // Empty data object since our function doesn't require any input
});

const options = {
  hostname: 'us-central1-twogetherapp-65678.cloudfunctions.net',
  path: '/getSalesforceAccessToken',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

console.log('Sending request to Salesforce access token function...');

const req = https.request(options, (res) => {
  console.log(`Status Code: ${res.statusCode}`);
  
  let responseData = '';
  
  res.on('data', (chunk) => {
    responseData += chunk;
  });
  
  res.on('end', () => {
    console.log('Response received:');
    console.log(responseData);
    
    try {
      const parsedData = JSON.parse(responseData);
      if (parsedData.result && parsedData.result.access_token) {
        console.log('SUCCESS: Function returned a valid access token!');
      } else if (parsedData.error) {
        console.log('ERROR: Function returned an error:', parsedData.error);
      }
    } catch (e) {
      console.log('Error parsing response:', e);
    }
  });
});

req.on('error', (error) => {
  console.error('Error making request:', error);
});

// Send the request
req.write(data);
req.end(); 