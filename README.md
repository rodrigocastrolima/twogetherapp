# TwogetherApp

A Flutter application for managing renewable energy offerings. This app includes user management, authentication, and administrative features with secure Cloud Functions integration.

## Features

- **Authentication**: Secure email/password authentication using Firebase Auth
- **User Management**: Admin dashboard for creating, enabling/disabling users, and resetting passwords
- **Role-Based Access Control**: Different access levels for administrators and resellers
- **Cloud Functions**: Secure server-side operations for user management (requires Blaze plan)

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version recommended)
- Firebase project (Blaze plan required for Cloud Functions)
- Firebase CLI for deploying Cloud Functions

### Project Setup

1. Clone the repository
2. Install dependencies:
   ```
   flutter pub get
   ```
3. Set up Firebase:
   ```
   firebase login
   flutterfire configure
   ```

### Running the App

```
flutter run
```

## Architecture

This project follows a clean architecture approach with:

- **Domain Layer**: Contains business models and repository interfaces
- **Data Layer**: Implements repositories and services for data access
- **Presentation Layer**: UI components, providers, and state management
- **Cloud Functions**: Server-side code for secure administrative operations

## Firebase Cloud Functions

The app integrates with Firebase Cloud Functions for secure user management:

- Creating new users without disrupting admin sessions
- Enabling/disabling user accounts
- Resetting user passwords

**Important**: Cloud Functions require the Firebase Blaze (pay-as-you-go) plan.

See the [functions/README.md](functions/README.md) for detailed setup and deployment instructions.

## Dependencies

Major dependencies include:

- **flutter_riverpod**: State management
- **go_router**: Navigation
- **firebase_auth**: Authentication
- **cloud_firestore**: Database
- **cloud_functions**: Server-side functions

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Scripts and Tools

This project includes various scripts for development, testing, and integration. They are organized as follows:

### Script Organization

```
scripts/                 # Main scripts directory (to be created)
  ├── firebase/          # Firebase-related scripts
  │   ├── testing/       # Scripts for testing Firebase functions
  │   └── deployment/    # Scripts for deploying Firebase resources
  ├── salesforce/        # Salesforce integration scripts
  └── utilities/         # Utility scripts

lib/scripts/             # Flutter app scripts (integrated with the app)
  └── salesforce/        # Salesforce integration scripts for the Flutter app
```

### Key Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| `salesforce_user_creation.cjs` | Create users with Salesforce integration | `scripts/salesforce/` |
| `check_firebase_functions.ps1` | Verify Firebase Functions deployment | `scripts/firebase/deployment/` |
| `test_ping.cjs` | Test Firebase Functions connectivity | `scripts/firebase/testing/` |
| `Sync-SalesforceUsers.ps1` | Sync Salesforce users to Firebase | `lib/scripts/` |

### Testing Firebase Integration

For testing Firebase Cloud Functions:

1. **Basic Connectivity Test**:
   ```
   node scripts/firebase/testing/test_ping.cjs
   ```

2. **User Creation Test**:
   ```
   node scripts/firebase/testing/test_create_user.cjs
   ```

3. **Salesforce Integration Test**:
   ```
   node scripts/salesforce/salesforce_user_creation.cjs
   ```

### Prerequisites for Running Scripts

- Node.js 18+ for JavaScript/TypeScript scripts
- PowerShell 5.1+ for PowerShell scripts
- Firebase CLI installed and authenticated
- Service account key stored at `./service-account-key.json`
- Salesforce credentials configured (see individual script documentation)

For more detailed information about specific scripts, please refer to the README files in each script directory.

# Firebase User Creation Testing

This directory contains scripts to help diagnose issues with the Firebase Cloud Functions-based user creation process. The process relies on several components working together:

1. Firebase Cloud Functions deployment
2. Salesforce integration
3. Firebase Authentication
4. Proper admin privileges

## Test Scripts

There are multiple test scripts provided to diagnose issues from different angles:

### 1. PowerShell Script (test_user_creation.ps1)

This script uses the Firebase CLI to test the Cloud Functions:

```powershell
# Test ping function only
./test_user_creation.ps1 -TestPingOnly

# Test full user creation
./test_user_creation.ps1 -Email "test@example.com" -SalesforceId "00XXXX"
```

### 2. Node.js Script (test_firebase_functions.js)

This script uses the Firebase Admin SDK directly:

```bash
# Install dependencies
npm install firebase-admin

# Place service-account-key.json in the directory
# You can download this from Firebase Console > Project Settings > Service Accounts

# Run the test script
node test_firebase_functions.js
```

## Common Issues & Solutions

### 1. Cloud Functions Not Deployed

Check if the Cloud Functions are properly deployed:

```bash
firebase functions:list
```

You should see `createUser`, `ping`, `setUserEnabled` and other functions listed. If not, deploy them:

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

### 2. Authentication Issues

Make sure you're logged in as an admin user before testing:

```bash
firebase login
```

Also, check that your user has admin privileges in Firestore. The user document should have:
```
{
  "role": "admin"
}
```

### 3. Salesforce Integration Issues

If user creation works but Salesforce sync fails:

1. Verify that the Salesforce credentials are correctly configured
2. Check the Salesforce connection in the SalesforceUserSyncService
3. Ensure the Salesforce ID is valid
4. Look for CORS or network connectivity issues

### 4. Region Issues

Make sure you're using the correct Firebase region. The app is configured for `us-central1`. If your functions are deployed to a different region, update the `REGION` variable in the test scripts.

## Manual Testing in Flutter

You can also test directly in the Flutter app:

1. Sign in as an admin user
2. Navigate to the user management page
3. Try adding a new user with a valid Salesforce ID
4. Check the browser console and network tab for errors

## What to Do if Tests Fail

1. **Ping Test Fails**: Cloud Functions might not be properly deployed or accessible
2. **Authentication Test Fails**: Admin privileges might not be correctly set up
3. **CreateUser Function Fails**: Check error details for specific issues
4. **Salesforce Sync Fails**: Verify Salesforce credentials and connection

## Troubleshooting Process

1. Start with the basic `ping` test to verify Cloud Functions are accessible
2. Check authentication status and refresh tokens
3. Test user creation with minimal information (no Salesforce ID)
4. Add Salesforce ID to test the sync functionality
5. Review logs and error messages for specific failure points

If issues persist, check Firebase project settings, IAM permissions, and network connectivity between your app and Firebase/Salesforce services.
