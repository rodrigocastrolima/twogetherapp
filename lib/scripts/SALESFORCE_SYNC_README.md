# Salesforce User Synchronization Scripts

This directory contains PowerShell scripts for synchronizing user data between Salesforce and Firebase.

## Prerequisites

1. **PowerShell 5.1 or later** - These scripts are designed to run in PowerShell
2. **JWT Module** - For Firebase authentication (will be installed automatically if missing)
3. **Firebase Authentication** - Either a service account key file OR admin credentials for interactive login

## Script Overview

### 1. Get-SalesforceToken.ps1

Obtains a Salesforce access token using JWT authentication. This script is automatically called by the main sync script.

### 2. Get-FirebaseToken.ps1

Obtains a Firebase ID token for authenticated access to Firestore. Supports two authentication methods:
- Service account authentication (requires a service account key file)
- Interactive login (requires admin email/password)

### 3. Explore-SalesforceFields.ps1

Explores the Salesforce User object's metadata and generates field mapping recommendations.

### 4. Sync-SalesforceUsers.ps1

The main script for synchronizing user data from Salesforce to Firebase. It:
- Queries Firebase for users with Salesforce IDs
- Retrieves the corresponding user data from Salesforce
- Maps Salesforce fields to Firebase fields
- Updates the Firebase user documents

## Setup

### Firebase Authentication Options

#### Option 1: Service Account Key (for automated scenarios)

1. **Download Service Account Key**:
   - Go to the [Firebase Console](https://console.firebase.google.com/)
   - Navigate to Project Settings > Service Accounts
   - Click "Generate New Private Key"
   - Save the JSON file to your scripts directory as `service-account-key.json`

2. **Add Web API Key to Service Account File** (optional):
   - Find your Firebase Web API key in Project Settings > General
   - Add a field to your service account JSON file: `"api_key": "YOUR_API_KEY"`

#### Option 2: Interactive Login (for human operators)

1. **Web API Key**:
   - Find your Firebase Web API Key in the Firebase Console under Project Settings > General
   - You'll need to provide this when prompted or via the `-FirebaseApiKey` parameter

2. **Admin Credentials**:
   - You'll need an email/password for a Firebase user with admin privileges
   - The script will prompt you for these credentials during execution

## Usage Examples

### Exploring Salesforce Fields

```powershell
# Basic exploration
./Explore-SalesforceFields.ps1

# Save mapping to a file
./Explore-SalesforceFields.ps1 -OutputFile salesforce_mapping.json

# Explore a different Salesforce object
./Explore-SalesforceFields.ps1 -Object Contact
```

### Synchronizing Users (Dry Run Mode)

```powershell
# Sync all users (dry run)
./Sync-SalesforceUsers.ps1 -All -DryRun

# Sync with Firebase authentication using service account
./Sync-SalesforceUsers.ps1 -All -DryRun -UseFirebaseAuth -ServiceAccountKeyPath "path/to/service-account-key.json"

# Sync with Firebase authentication using interactive login
./Sync-SalesforceUsers.ps1 -All -DryRun -UseFirebaseAuth -InteractiveAuth -FirebaseApiKey "YOUR_API_KEY"

# Sync a specific user
./Sync-SalesforceUsers.ps1 -UserId "0051i000000xxxxx" -DryRun
```

### Performing Actual Synchronization

```powershell
# Sync all users with Firebase authentication (interactive login)
./Sync-SalesforceUsers.ps1 -All -UseFirebaseAuth -InteractiveAuth

# Sync with custom field mapping
./Sync-SalesforceUsers.ps1 -All -ConfigFile "salesforce_mapping.json" -UseFirebaseAuth -InteractiveAuth
```

### Custom Field Mapping

You can create a custom field mapping file in JSON format:

```json
{
  "mapping": {
    "Id": "salesforceId",
    "Name": "displayName",
    "Email": "email",
    "Revendedor_Retail__c": "isRetailReseller",
    "CustomField__c": "customFieldName"
  }
}
```

Then use it with:

```powershell
./Sync-SalesforceUsers.ps1 -All -ConfigFile "custom_mapping.json"
```

## Troubleshooting

### Authentication Issues

If you encounter authentication issues:

1. **Salesforce Authentication**:
   - Check that your Salesforce credentials are correct
   - Ensure the Firebase function for token generation is deployed
   - Test the token script directly: `./Get-SalesforceToken.ps1`

2. **Firebase Authentication**:
   - **Service Account**: Make sure your service account key file is valid and contains the necessary permissions
   - **Interactive Login**: Ensure you're using a valid admin email/password and Web API Key
   - Test the token script directly: 
     - `./Get-FirebaseToken.ps1 -ServiceAccountKeyPath "path/to/key.json"` (service account)
     - `./Get-FirebaseToken.ps1 -Interactive -ApiKey "YOUR_API_KEY"` (interactive)

### No Users Found

If no users are found in Firebase:

1. Check that users in your Firebase database have the `salesforceId` field
2. Try running with `./Sync-SalesforceUsers.ps1 -All -DryRun` and answer "y" to use test data
3. If using test data works, check your Firestore database structure

### API Errors

If you receive API errors:

1. **Salesforce**:
   - Check that your SOQL queries are correct
   - Verify you have access to the fields you're querying

2. **Firebase**:
   - Check that your authentication method has the necessary permissions
   - Verify your project ID is correct
   - For 403 errors, make sure you're using authenticated access with `-UseFirebaseAuth -InteractiveAuth`

## Advanced: Adding Custom Fields

To add custom Salesforce fields to your sync:

1. First explore the field to understand its structure:
   ```powershell
   ./Explore-SalesforceFields.ps1
   ```

2. Look for your custom field in the output (e.g., `Revendedor_Retail__c`)

3. Add the field to the default mapping in the script or create a custom mapping file

4. Test with dry run:
   ```powershell
   ./Sync-SalesforceUsers.ps1 -All -DryRun -UseFirebaseAuth -InteractiveAuth
   ``` 