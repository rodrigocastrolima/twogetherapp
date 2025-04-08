# Firebase Functions Refactoring Guide

This guide provides a step-by-step process for refactoring the large `index.ts` file (1273 lines) into smaller, more maintainable modules.

## Current Issues

- The `functions/src/index.ts` file is too large (1273 lines)
- Multiple concerns are mixed in a single file
- Poor separation of concerns makes testing and maintenance difficult
- Some functions have already been moved to separate files, but not consistently

## Recommended Structure

```
functions/src/
├── index.ts                 # Main entry point that exports all functions
├── auth/                    # Authentication-related functions
│   ├── createUser.ts        # User creation function
│   ├── setUserEnabled.ts    # Enable/disable user function
│   └── index.ts             # Exports all auth functions
├── salesforce/              # Salesforce integration 
│   ├── syncUser.ts          # Sync user with Salesforce
│   ├── getSalesforceToken.ts # Get Salesforce JWT token
│   └── index.ts             # Exports all Salesforce functions
├── utils/                   # Shared utilities
│   ├── checkUsageLimits.ts  # Usage limit checking
│   ├── firestore.ts         # Firestore utilities
│   └── index.ts             # Exports all utilities
├── notifications/           # Notification functions
│   ├── notifications.ts     # Exported from here
│   └── index.ts             # Exports all notification functions
└── misc/                    # Miscellaneous functions
    ├── ping.ts              # Simple ping function
    └── index.ts             # Exports all misc functions
```

## Refactoring Steps

### 1. Create the Directory Structure

```bash
cd functions/src
mkdir -p auth salesforce utils notifications misc
touch auth/index.ts salesforce/index.ts utils/index.ts notifications/index.ts misc/index.ts
```

### 2. Extract Utility Functions

Create `utils/checkUsageLimits.ts`:
```typescript
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

// Configuration
const USAGE_COLLECTION = "usage_limits";
const MONTHLY_FUNCTION_INVOCATION_LIMIT = 125000; // 125K free invocations per month
const DAILY_FUNCTION_QUOTA = MONTHLY_FUNCTION_INVOCATION_LIMIT / 30; // Approximate daily quota

/**
 * Check if we're within safe usage limits to prevent unexpected charges
 * 
 * @param {string} functionName - The name of the function being called
 * @return {Promise<boolean>} True if it's safe to proceed, false if limits are reached
 */
export async function checkUsageLimits(functionName: string): Promise<boolean> {
  try {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1; // JavaScript months are 0-indexed
    const day = now.getDate();
    
    // Create tracking IDs for this month and day
    const monthId = `${year}-${month}`;
    const dayId = `${monthId}-${day}`;
    
    // Get the usage tracking document for this function
    const functionRef = admin.firestore()
      .collection(USAGE_COLLECTION)
      .doc(functionName);
    
    // Use a transaction to safely update the counters
    return await admin.firestore().runTransaction(async (transaction) => {
      const functionDoc = await transaction.get(functionRef);
      const data = functionDoc.exists ? functionDoc.data() : {
        monthlyInvocations: {},
        dailyInvocations: {},
      };
      
      // Default to empty objects if data is undefined
      const monthlyInvocations = data?.monthlyInvocations || {};
      const dailyInvocations = data?.dailyInvocations || {};
      
      // Get current counts or initialize if not present
      const monthlyCount = (monthlyInvocations[monthId] || 0) + 1;
      const dailyCount = (dailyInvocations[dayId] || 0) + 1;
      
      // Check if we're approaching limits
      if (monthlyCount > MONTHLY_FUNCTION_INVOCATION_LIMIT * 0.95) {
        logger.warn(
          `⚠️ Monthly function invocations (${monthlyCount}) for ${functionName} near free tier limit!`
        );
        return false; // Stop execution to prevent charges
      }
      
      if (dailyCount > DAILY_FUNCTION_QUOTA * 0.95) {
        logger.warn(
          `⚠️ Daily function invocations (${dailyCount}) approaching daily quota!`
        );
        // Allow execution but log warning
      }
      
      // Update the tracking document
      const updatedData = {
        monthlyInvocations: {
          ...monthlyInvocations,
          [monthId]: monthlyCount,
        },
        dailyInvocations: {
          ...dailyInvocations,
          [dayId]: dailyCount,
        },
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      transaction.set(functionRef, updatedData, {merge: true});
      return true; // Safe to execute
    });
  } catch (error) {
    // If there's an error checking the limit, log it but allow execution
    // Better to allow some functions than break the entire app
    logger.error(`Error checking usage limits: ${error}`);
    return true;
  }
}

export default checkUsageLimits;
```

Create `utils/index.ts`:
```typescript
export { checkUsageLimits } from './checkUsageLimits';
```

### 3. Extract Authentication Functions

Create `auth/createUser.ts`:
```typescript
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { checkUsageLimits } from "../utils";

// Define the type for the user creation data
interface CreateUserData {
  email: string;
  password: string;
  displayName?: string;
  role: string;
}

/**
 * Creates a new user with the specified email, password, and role.
 * Only authenticated admin users can call this function.
 */
export const createUser = onCall({
  enforceAppCheck: false, // Set to true in production
}, async (request) => {
  try {
    // Check if we've reached usage limits
    const withinLimits = await checkUsageLimits("createUser");
    if (!withinLimits) {
      throw new HttpsError(
        "resource-exhausted",
        "Function invocation limit reached to prevent unexpected charges. Please try again tomorrow or contact the administrator."
      );
    }

    // Log request detail to help diagnose issues
    logger.info(`createUser function called with data: ${JSON.stringify(request.data)}`);
    logger.info(`Auth context available: ${Boolean(request.auth)}`);
    
    if (request.auth) {
      logger.info(`Caller UID: ${request.auth.uid}`);
    }

    // Verify authentication
    if (!request.auth) {
      logger.error("No auth context provided");
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to create users"
      );
    }

    // Get the calling user to check if they're an admin
    const callerUid = request.auth.uid;
    const callerDoc = await admin.firestore()
      .collection("users")
      .doc(callerUid)
      .get();
    
    if (!callerDoc.exists) {
      logger.error(`User document not found for UID: ${callerUid}`);
      throw new HttpsError(
        "permission-denied",
        "User data not found"
      );
    }
    
    const callerData = callerDoc.data();
    logger.info(`Caller data from Firestore: ${JSON.stringify(callerData)}`);
    
    if (!callerData || callerData.role?.toLowerCase() !== "admin") {
      logger.error(`User is not an admin. Role: ${callerData?.role}`);
      throw new HttpsError(
        "permission-denied",
        "Only administrators can create users"
      );
    }

    // Extract user data from request
    const data = request.data as CreateUserData;
    const {email, password, displayName, role} = data;
    
    // Validate required fields
    if (!email || !password || !role) {
      throw new HttpsError(
        "invalid-argument",
        "Email, password, and role are required"
      );
    }

    // Create the user in Firebase Authentication
    try {
      const userRecord = await admin.auth().createUser({
        email,
        password,
        displayName: displayName || email.split("@")[0],
      });
      
      // Create user document in Firestore
      await admin.firestore()
        .collection("users")
        .doc(userRecord.uid)
        .set({
          email,
          displayName: displayName || email.split("@")[0],
          role,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: callerUid,
          isActive: true,
          isFirstLogin: true,
        });
      
      // Return the newly created user data
      return {
        uid: userRecord.uid,
        email: userRecord.email,
        displayName: userRecord.displayName,
        role,
      };
    } catch (error) {
      logger.error(`Error creating user: ${error}`);
      throw new HttpsError(
        "internal",
        `Failed to create user: ${error}`
      );
    }
  } catch (error) {
    logger.error(`createUser function error: ${error}`);
    throw error;
  }
});

export default createUser;
```

Create `auth/index.ts`:
```typescript
export { createUser } from './createUser';
// export other auth functions as they're created
```

### 4. Refactor Main Index File

Update the main `index.ts` file to import and re-export all functions:

```typescript
/**
 * Import function triggers from their respective submodules:
 */

import * as admin from "firebase-admin";

// Initialize the Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

// Import and re-export functions from modules
export { createUser } from './auth';
export { removeRememberMeField } from './removeRememberMeField';
export { cleanupExpiredMessages } from './messageCleanup';
export { onNewMessageNotification } from './notifications';

// Export any remaining functions that haven't been moved yet
// TODO: Move these to appropriate modules
```

### 5. Move Remaining Functions

Continue extracting functions from `index.ts` into appropriate modules following the pattern above:

1. Create a new file for each function
2. Move the function implementation to the new file
3. Export the function from the module's `index.ts`
4. Update the main `index.ts` to import and re-export the function

## Testing the Refactored Code

After refactoring, test the functions to ensure they still work:

1. Run the build process: `npm run build`
2. Use the testing scripts to verify each function:
   ```
   node scripts/firebase/testing/test_ping.cjs
   node scripts/firebase/testing/test_create_user.cjs
   ```

## Deployment

When all functions are tested and working:

```bash
firebase deploy --only functions
```

## Benefits of This Approach

- Better organization with separation of concerns
- Easier maintenance and updates
- Improved testability
- Better collaboration as team members can work on different modules
- Clear module dependencies
- Smaller, more focused files 