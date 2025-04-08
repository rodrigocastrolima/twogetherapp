# Salesforce Integration for User Management

This document describes how the Salesforce integration works for synchronizing user data between Salesforce and the TwogetherApp.

## Overview

The integration allows administrators to:

1. Explore Salesforce User metadata to understand available fields
2. Create new users with automatic Salesforce data synchronization by providing a Salesforce ID
3. Synchronize existing users with Salesforce data
4. Automatically keep user data in sync with periodic updates from Salesforce

## Components

The integration consists of several components:

### 1. PowerShell Scripts for Salesforce Integration

**Location:** `lib/scripts/`

A set of PowerShell scripts for administrators to explore and manipulate Salesforce data:

- **Get-SalesforceToken.ps1**: Helper script for Salesforce authentication that utilizes the Firebase function token generation.
- **Explore-SalesforceFields.ps1**: Explores Salesforce User metadata and generates field mapping recommendations.
- **Sync-SalesforceUsers.ps1**: Synchronizes user data between Salesforce and Firebase.

Usage examples:
```powershell
# Explore Salesforce User fields and generate mapping
./Explore-SalesforceFields.ps1 -OutputFile fieldMapping.json

# Sync a specific user by Salesforce ID
./Sync-SalesforceUsers.ps1 -UserId "001XXXXXXXXXXXX"

# Sync all users with a dry run (no changes)
./Sync-SalesforceUsers.ps1 -All -DryRun
```

### 2. Salesforce User Sync Service

**Location:** `lib/features/salesforce/data/services/salesforce_user_sync_service.dart`

A service class that handles the synchronization of user data between Salesforce and Firebase. Key features:

- Get Salesforce user data by ID
- Sync Salesforce data to a Firebase user
- Find users that need synchronization
- Bulk synchronization of multiple users
- Configurable field mapping

### 3. User Creation Integration

**Location:**
- `lib/features/user_management/presentation/widgets/create_user_form.dart`
- `lib/features/user_management/presentation/pages/user_management_page.dart`

Enhanced user creation flow that allows administrators to:
- Create new users with a name field (now required for better UX)
- Specify a Salesforce User ID during creation
- Automatically fetch and synchronize user data from Salesforce upon creation

### 4. Firebase Cloud Functions

**Location:** `functions/src/index.ts`

Firebase Cloud Functions that support the Salesforce integration:

- `getSalesforceAccessToken`: Generates a Salesforce access token using JWT authentication

## Field Mapping

By default, the following fields are synchronized from Salesforce to Firebase:

| Salesforce Field | Firebase Field   | Description                       |
|------------------|------------------|-----------------------------------|
| Id               | salesforceId     | Salesforce User ID                |
| Name             | displayName      | User's full name                  |
| Email            | email            | User's email address              |
| IsActive         | isActive         | Whether the user is active        |
| Phone            | phoneNumber      | User's primary phone              |
| MobilePhone      | mobilePhone      | User's mobile phone               |
| Department       | department       | User's department                 |
| Title            | title            | User's job title                  |
| CompanyName      | companyName      | User's company name               |
| ManagerId        | managerId        | ID of the user's manager          |
| UserRoleId       | userRoleId       | ID of the user's role             |
| ProfileId        | profileId        | ID of the user's profile          |
| Username         | salesforceUsername | Salesforce username             |
| FirstName        | firstName        | User's first name                 |
| LastName         | lastName         | User's last name                  |
| LastLoginDate    | lastSalesforceLoginDate | Last login to Salesforce   |

You can customize the field mapping by:
1. Using the `Explore-SalesforceFields.ps1` script to generate a recommended mapping
2. Editing the `DEFAULT_FIELD_MAPPING` constant in the `SalesforceUserSyncService` class
3. Creating a configuration file for the `Sync-SalesforceUsers.ps1` script

## How to Use

### Creating a New User with Salesforce ID

1. Navigate to the User Management page
2. Click "New Reseller" to open the create user dialog
3. Fill in the required fields (Email, Display Name, Password)
4. Enter the Salesforce User ID in the "Salesforce ID" field
5. Click "Create User"
6. The system will automatically fetch data from Salesforce and update the user record

### Exploring Salesforce Fields (Admin)

1. Make sure you have PowerShell installed
2. Run the Explore-SalesforceFields.ps1 script:
   ```powershell
   cd lib/scripts
   ./Explore-SalesforceFields.ps1
   ```
3. Review the output to see available fields and recommended mappings
4. Optionally save the mappings to a file:
   ```powershell
   ./Explore-SalesforceFields.ps1 -OutputFile salesforce_mapping.json
   ```

### Syncing Users with PowerShell (Admin)

1. To sync a specific user:
   ```powershell
   cd lib/scripts
   ./Sync-SalesforceUsers.ps1 -UserId "001XXXXXXXXXXXX"
   ```

2. To sync all users:
   ```powershell
   ./Sync-SalesforceUsers.ps1 -All
   ```

3. To perform a dry run (no changes):
   ```powershell
   ./Sync-SalesforceUsers.ps1 -All -DryRun
   ```

## Troubleshooting

### Common Issues

1. **Connection Errors**: Ensure your Salesforce credentials are valid and the Firebase function for token generation is deployed and working.

2. **Missing Fields**: If expected fields are not synchronizing:
   - Check that the field exists in Salesforce (use the `Explore-SalesforceFields.ps1` script)
   - Verify the field is included in the mapping
   - Check API permissions for the field

3. **Sync Failures**: Check logs for details on specific sync failures. Common causes include:
   - Invalid Salesforce IDs
   - Permission issues
   - Network connectivity problems

### Logs

Sync operations log details to the console in debug mode. Check these logs for information about successful and failed operations.

## Future Enhancements

Potential enhancements for the Salesforce integration include:

1. Two-way synchronization (Firebase → Salesforce)
2. Support for custom fields and objects
3. Automated synchronization via Cloud Functions
4. More granular field mapping configuration
5. UI for managing synchronization settings 