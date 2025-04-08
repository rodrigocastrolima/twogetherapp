# Salesforce Integration Scripts

This directory contains PowerShell scripts for integrating Salesforce data with Firebase.

## Prerequisites

1. PowerShell 5.1 or higher
2. Firebase CLI installed (if updating Firebase): `npm install -g firebase-tools`
3. Access to the Salesforce API through the Firebase Function

## Available Scripts

### 1. Get-SalesforceToken.ps1

Authentication helper script - obtains a Salesforce access token via a Firebase Function.

```powershell
# Run directly to get a token (rarely needed directly)
./Get-SalesforceToken.ps1
```

### 2. List-SalesforceUsers.ps1

Lists Salesforce users and their information, including custom fields.

```powershell
# List 10 users (default)
./List-SalesforceUsers.ps1

# List 50 users
./List-SalesforceUsers.ps1 -Limit 50

# Use a custom SOQL query
./List-SalesforceUsers.ps1 -Query "SELECT Id, Name, Email, Revendedor_Retail__c FROM User WHERE IsActive = true LIMIT 20"
```

### 3. Check-RevendedorRetailField.ps1

Specifically checks the `Revendedor_Retail__c` field in the Salesforce User object.

```powershell
# Check 20 users with the field populated (default)
./Check-RevendedorRetailField.ps1

# Check more users
./Check-RevendedorRetailField.ps1 -Limit 50
```

This script will:
- Retrieve metadata about the field to understand its type
- Find users that have this field populated
- Analyze the values to determine if they're booleans, IDs, etc.
- If they appear to be IDs, attempt to find what object they reference

### 4. Sync-SalesforceUserToFirebase.ps1

Syncs data for a specific Salesforce user to Firebase.

```powershell
# Preview what would be synced (dry run)
./Sync-SalesforceUserToFirebase.ps1 -SalesforceId "005xxxxxxxxxxxx" -DryRun

# Sync to a specific Firebase user
./Sync-SalesforceUserToFirebase.ps1 -SalesforceId "005xxxxxxxxxxxx" -FirebaseId "firebase-user-id"

# Attempt to find a matching user in Firebase
./Sync-SalesforceUserToFirebase.ps1 -SalesforceId "005xxxxxxxxxxxx"
```

This script:
- Fetches user data from Salesforce
- Maps fields based on a predefined mapping
- Searches for a matching user in Firebase (if FirebaseId not provided)
- Updates the Firebase user document with Salesforce data

## Common Workflow

1. First, list Salesforce users to find users of interest:
   ```powershell
   ./List-SalesforceUsers.ps1
   ```

2. Check the `Revendedor_Retail__c` field specifically:
   ```powershell
   ./Check-RevendedorRetailField.ps1
   ```

3. Sync a specific user to Firebase (preview first):
   ```powershell
   ./Sync-SalesforceUserToFirebase.ps1 -SalesforceId "005xxxxxxxxxxxx" -DryRun
   ```

4. Perform the actual sync:
   ```powershell
   ./Sync-SalesforceUserToFirebase.ps1 -SalesforceId "005xxxxxxxxxxxx" -FirebaseId "firebase-user-id"
   ```

## Troubleshooting

- **Authentication Issues**: Make sure the Firebase function is accessible and returning a valid token
- **Field Not Found**: Check field spelling and ensure it's accessible through the API
- **Firebase CLI Not Found**: Install the Firebase CLI with `npm install -g firebase-tools` and login with `firebase login` 