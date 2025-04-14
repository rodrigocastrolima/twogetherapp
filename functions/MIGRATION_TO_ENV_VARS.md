# Migration from functions.config() to Environment Variables

## Background

Firebase Cloud Functions has moved from version 1 to version 2, and the method for storing configuration has changed. The `functions.config()` approach is no longer available in v2 of the Firebase Functions SDK. Instead, you need to use environment variables.

## Error

You may see this error:
```
Error: functions.config() is no longer available in Cloud Functions for Firebase v2. Please see the latest documentation for information on how to transition to using environment variables
```

## Solution

### 1. Set the Environment Variables

Use the Firebase CLI to set environment variables:

```bash
# Set individual environment variables
firebase functions:secrets:set SALESFORCE_PRIVATE_KEY
firebase functions:secrets:set SALESFORCE_CONSUMER_KEY
firebase functions:secrets:set SALESFORCE_USERNAME

# Or use the Secrets feature for sensitive data (recommended)
firebase functions:secrets:set SALESFORCE_PRIVATE_KEY
```

When prompted, enter the values for each variable.

For multiline values like private keys:
1. Store the key in a file (e.g., `private_key.txt`)
2. Use the following command:
```bash
firebase functions:secrets:set SALESFORCE_PRIVATE_KEY --data-file private_key.txt
```

### 2. Update your firebase.json

Make sure your `firebase.json` file includes a `runtime` parameter:

```json
{
  "functions": {
    "runtime": "nodejs22",
    "source": "functions"
  }
}
```

### 3. Deploy Your Functions

Deploy your updated functions:

```bash
firebase deploy --only functions
```

## Reading Environment Variables in Code

In your code, replace:

```javascript
const sfConfig = functions.config().salesforce;
const privateKey = sfConfig.private_key;
const consumerKey = sfConfig.consumer_key;
const salesforceUsername = sfConfig.username;
```

With:

```javascript
const privateKey = process.env.SALESFORCE_PRIVATE_KEY;
const consumerKey = process.env.SALESFORCE_CONSUMER_KEY;
const salesforceUsername = process.env.SALESFORCE_USERNAME;
```

## Troubleshooting

- If you encounter permission issues when setting secrets, make sure you're logged in with sufficient permissions:
  ```bash
  firebase login
  ```

- To view all your current environment variables:
  ```bash
  firebase functions:secrets:get
  ```

- For local testing, you can use a `.env` file with the Firebase emulator.

## Documentation

For more information, see the [official Firebase documentation on environment configuration](https://firebase.google.com/docs/functions/config-env). 