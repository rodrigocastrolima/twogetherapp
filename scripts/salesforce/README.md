# Salesforce Integration Scripts

This directory contains scripts for integrating with Salesforce and testing the integration with Firebase.

## Available Scripts

| Script | Purpose |
|--------|---------|
| `salesforce_user_creation.cjs` | Create Firebase users with data from Salesforce using JWT authentication |

## Prerequisites

- Node.js 18+
- Firebase Admin SDK: `npm install firebase-admin`
- Axios for HTTP requests: `npm install axios`
- Service account key file at `service-account-key.json`
- Access to the Firebase Cloud Function that provides Salesforce JWT authentication

## Usage

### Creating Users with Salesforce Integration

The `salesforce_user_creation.cjs` script creates a new user in Firebase Authentication and Firestore with data fetched from Salesforce:

```bash
node salesforce_user_creation.cjs
```

This script will:

1. Prompt for a Salesforce User ID
2. Authenticate with Salesforce via the Firebase Function (JWT authentication)
3. Check if the Salesforce ID exists and fetch user data
4. Check if the user already exists in Firestore
5. Create a new user in Firebase Authentication
6. Create a Firestore document with mapped fields from Salesforce

## Understanding the Salesforce Integration

This integration uses a JWT authentication flow where:

1. A Firebase Cloud Function (`getSalesforceAccessToken`) obtains a Salesforce access token using JWT
2. The token is used to make secure API calls to Salesforce
3. User data is mapped from Salesforce fields to Firebase fields

## Field Mapping

The script maps Salesforce User fields to Firestore fields as follows:

- `Id` → `salesforceId`
- `Name` → `displayName`
- `FirstName` → `firstName`
- `LastName` → `lastName`
- `Email` → `email`
- `Phone` → `phoneNumber`
- `MobilePhone` → `mobilePhone`
- `Department` → `department`
- `IsActive` → `isActive`
- `LastLoginDate` → `lastSalesforceLoginDate`
- `Username` → `salesforceUsername`
- `Revendedor_Retail__c` → `revendedorRetail`

## Troubleshooting

If you encounter issues:

1. Verify that the Firebase Function for Salesforce authentication is correctly deployed
2. Check that your service account has appropriate permissions
3. Ensure the Salesforce ID exists and the user has an email address
4. Check Firebase logs for more detailed error information 