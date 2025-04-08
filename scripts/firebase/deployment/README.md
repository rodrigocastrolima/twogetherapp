# Firebase Deployment Scripts

This directory contains scripts for deploying and verifying Firebase resources.

## Available Scripts

| Script | Purpose |
|--------|---------|
| `check_firebase_functions.ps1` | Verifies that Firebase Functions are properly deployed and configured |

## Prerequisites

- PowerShell 5.1+
- Firebase CLI installed and authenticated
- Active Firebase project configured

## Usage

### Checking Firebase Functions Deployment

The `check_firebase_functions.ps1` script verifies that your Firebase Functions are properly deployed:

```powershell
./check_firebase_functions.ps1
```

For verbose output (more details):

```powershell
./check_firebase_functions.ps1 -Verbose
```

To attempt automatic fixes for identified issues:

```powershell
./check_firebase_functions.ps1 -FixIssues
```

This script checks:
1. Firebase CLI installation and authentication
2. Presence of required configuration files (`firebase.json`)
3. Functions directory structure and dependencies
4. Currently deployed functions versus required functions
5. Emulator status

## Required Functions

The script verifies that these essential functions are deployed:
- `ping`: Basic connectivity test function
- `createUser`: Creates new users in Firebase Auth and Firestore
- `setUserEnabled`: Enables or disables users
- `syncUserWithSalesforce`: Syncs user data with Salesforce

## Troubleshooting

If issues are identified:

1. Check the Firebase CLI installation: `firebase --version`
2. Verify authentication: `firebase login`
3. Check project selection: `firebase projects:list`
4. Verify functions code is correct
5. Deploy functions: `cd functions && npm run build && firebase deploy --only functions` 