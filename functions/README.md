# TwogetherApp Firebase Cloud Functions

This directory contains the Firebase Cloud Functions for the TwogetherApp, providing secure server-side handling of administrative operations such as user management.

## Prerequisites

Before deploying these functions, ensure you have:

1. A Firebase project upgraded to the Blaze (pay-as-you-go) plan
2. Firebase CLI installed (`npm install -g firebase-tools`)
3. Node.js 16 or later installed

## Available Functions

The following Cloud Functions are implemented:

- **createUser** - Creates new users with specified roles without disrupting admin sessions
- **setUserEnabled** - Enables or disables user accounts
- **resetUserPassword** - Generates password reset links for users

## Deployment

To deploy the functions to your Firebase project:

1. Build the TypeScript files:
   ```
   cd functions
   npm run build
   ```

2. Deploy to Firebase:
   ```
   firebase deploy --only functions
   ```

## Function Usage

These functions are designed to be called from the Flutter app. The integration is already implemented in the `FirebaseFunctionsService` class.

### Security

All functions include security checks to ensure:

- Only authenticated users can call them
- Only users with admin roles can perform administrative actions 
- Proper error handling and validation

## Local Development

For local testing, you can use the Firebase emulators:

```
firebase emulators:start
```

The Flutter app is configured to use the local emulator when running in debug mode.

## Troubleshooting

Common issues:

1. **Deployment fails**: Ensure your Firebase project is on the Blaze plan, as functions require a billing account.
2. **Authentication errors**: Verify the user has admin permissions in the Firestore database.
3. **Region errors**: Check that the region in your Flutter app matches the region where functions are deployed.

## Further Reading

- [Firebase Cloud Functions documentation](https://firebase.google.com/docs/functions)
- [TypeScript documentation](https://www.typescriptlang.org/docs/) 