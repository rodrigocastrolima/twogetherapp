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

# Twogether App - Firebase Functions

This directory contains Firebase Cloud Functions for the Twogether App.

## Chat Feature

The chat feature has been redesigned with the following principles:

1. **Every reseller always has a conversation document** in Firestore
2. **Conversations are inactive by default** until non-default messages are sent
3. **Active state is managed automatically** through Firebase triggers 
4. **Conversations can be reset** rather than deleted, providing a better UX

### Firebase Functions for Chat

1. **updateConversationActivity**: Automatically detects if a conversation should be active based on its messages
2. **resetConversation**: Allows admins to clear a conversation's messages without deleting the conversation
3. **getInactiveConversations**: Lets admins see which conversations are inactive
4. **deleteConversation**: Completely removes a conversation and its messages (existing function)

### Migration Script

For existing reseller accounts that don't have a conversation document, we've provided a migration script.

To run the migration:

```bash
# Install ts-node if not already installed
npm install -g ts-node

# Run the migration script 
npm run migration:create-conversations
```

The script will:
1. Find all reseller users in the database
2. Check if they have an existing conversation
3. Create a conversation document for any reseller without one

### Deployment

To deploy these functions:

```bash
npm run build
firebase deploy --only functions
```

## Security Rules

The security rules have been updated to accommodate this new design, ensuring:

1. Resellers can only access their own conversations
2. Admins can access and manage all conversations
3. Participants can read and write to their conversations

## Function Usage from Dart Client

The client-side repository has been updated with methods to:

1. `ensureResellerHasConversation`: Make sure every reseller has a conversation
2. `resetConversation`: Reset a conversation (admin only)
3. `getInactiveConversations`: Get all inactive conversations (admin only)

These can be called from the appropriate UI components. 