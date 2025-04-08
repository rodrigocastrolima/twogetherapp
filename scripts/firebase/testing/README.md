# Firebase Testing Scripts

This directory contains scripts for testing Firebase Cloud Functions.

## Available Scripts

| Script | Purpose |
|--------|---------|
| `test_ping.cjs` | Tests basic connectivity to Firebase Cloud Functions |
| `test_create_user.cjs` | Tests the user creation functionality |

## Prerequisites

- Node.js 18+
- Firebase Admin SDK installed: `npm install firebase-admin`
- Service account key file in the root directory: `service-account-key.json`

## Usage

### Testing Basic Connectivity

The `test_ping.cjs` script checks if your Firebase Functions are accessible:

```bash
node test_ping.cjs
```

This script:
1. Loads your Firebase service account
2. Makes an HTTP request to the `ping` Cloud Function
3. Reports the result and any errors

### Testing User Creation

The `test_create_user.cjs` script tests the user creation process:

```bash
node test_create_user.cjs
```

This script will:
1. Prompt for email, password, display name, and optional Salesforce ID
2. Make a request to the `createUser` Cloud Function
3. Report the result and display user details if successful

## Troubleshooting

If the tests fail:

1. Verify that your service account key is correct and has sufficient permissions
2. Check that the Cloud Functions are properly deployed with `firebase functions:list`
3. Ensure the region is correct (default is `us-central1`)
4. Check Firebase project settings and authentication configuration 