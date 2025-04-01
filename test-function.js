const { initializeApp } = require('firebase/app');
const { getFunctions, httpsCallable, connectFunctionsEmulator } = require('firebase/functions');

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyCGe5A2BKBvEVTkZOkFo5j02t8KVT0xpUs",
  authDomain: "twogetherapp-65678.firebaseapp.com",
  projectId: "twogetherapp-65678",
  storageBucket: "twogetherapp-65678.firebasestorage.app",
  messagingSenderId: "415751455004",
  appId: "1:415751455004:web:f0de8e24a10f69eb6a0eef"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const functions = getFunctions(app);

// Connect to the local emulator
connectFunctionsEmulator(functions, '127.0.0.1', 5001);

// Get a reference to the getSalesforceAccessToken function
const getSalesforceAccessToken = httpsCallable(functions, 'getSalesforceAccessToken');

// Call the function
getSalesforceAccessToken({})
  .then((result) => {
    console.log('Function result:', result.data);
  })
  .catch((error) => {
    console.error('Function error:', error);
  }); 