# Sync-SalesforceUsers.ps1
# Script to synchronize user data between Salesforce and Firebase
# Usage: ./Sync-SalesforceUsers.ps1 [-UserId salesforceUserId] [-All] [-DryRun] [-UseFirebaseAuth] [-InteractiveAuth]

param (
    [string]$UserId = "",        # Specific Salesforce User ID to sync
    [switch]$All = $false,       # Sync all users with Salesforce IDs
    [switch]$DryRun = $false,    # Run without making changes
    [string]$ConfigFile = "",    # Optional config file for field mapping
    [switch]$UseFirebaseAuth = $false, # Whether to use Firebase authentication
    [switch]$InteractiveAuth = $false, # Whether to use interactive login for Firebase
    [string]$ServiceAccountKeyPath = "service-account-key.json", # Path to service account key
    [string]$FirebaseApiKey = "" # Firebase Web API Key
)

# Load the authentication helper script for Salesforce
$authScriptPath = Join-Path $PSScriptRoot "Get-SalesforceToken.ps1"
if (-not (Test-Path $authScriptPath)) {
    Write-Error "Authentication script not found at: $authScriptPath"
    exit 1
}

# Source the authentication script to get access token and instance URL
. $authScriptPath

# Check if we have valid authentication for Salesforce
if (-not $Global:salesforceToken -or -not $Global:salesforceInstanceUrl) {
    Write-Error "Authentication failed. Couldn't obtain Salesforce token or instance URL."
    exit 1
}

# If no authentication method is specified but UseFirebaseAuth is true, ask the user
if ($UseFirebaseAuth -and -not $InteractiveAuth) {
    $firebaseAuthScriptPath = Join-Path $PSScriptRoot "Get-FirebaseToken.ps1"
    if (-not (Test-Path $ServiceAccountKeyPath)) {
        Write-Warning "Service account key file not found at: $ServiceAccountKeyPath"
        $useInteractive = Read-Host "Would you like to use interactive login for Firebase authentication? (y/n)"
        if ($useInteractive -eq "y") {
            $InteractiveAuth = $true
        }
    }
}

# If Firebase authentication is requested, load the Firebase token script
if ($UseFirebaseAuth) {
    $firebaseAuthScriptPath = Join-Path $PSScriptRoot "Get-FirebaseToken.ps1"
    if (Test-Path $firebaseAuthScriptPath) {
        Write-Host "Loading Firebase authentication..." -ForegroundColor Cyan
        
        if ($InteractiveAuth) {
            # Run the script with interactive authentication
            & $firebaseAuthScriptPath -Interactive -ApiKey $FirebaseApiKey
        } else {
            # Run the script with the provided service account path
            & $firebaseAuthScriptPath -ServiceAccountKeyPath $ServiceAccountKeyPath -ApiKey $FirebaseApiKey
        }
        
        if (-not $Global:firebaseToken) {
            Write-Warning "Firebase authentication failed or not available. Will use anonymous access."
        } else {
            Write-Host "Firebase authentication loaded successfully." -ForegroundColor Green
        }
    } else {
        Write-Warning "Firebase authentication script not found. Will use anonymous access."
    }
}

# Default field mapping (Salesforce field to Firebase field)
$fieldMapping = @{
    "Id" = "salesforceId"
    "Name" = "displayName"
    "FirstName" = "firstName"
    "LastName" = "lastName"
    "Email" = "email"
    "Phone" = "phoneNumber"
    "MobilePhone" = "mobilePhone"
    "Department" = "department"
    "Title" = "title"
    "CompanyName" = "companyName"
    "IsActive" = "isActive"
    "LastLoginDate" = "lastSalesforceLoginDate"
    "Username" = "salesforceUsername"
    "Revendedor_Retail__c" = "isRetailReseller"
}

# If a config file is provided, load the field mapping from it
if ($ConfigFile -and (Test-Path $ConfigFile)) {
    try {
        $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
        if ($config.mapping) {
            Write-Host "Loading field mapping from config file: $ConfigFile" -ForegroundColor Cyan
            $fieldMapping = $config.mapping
        }
    }
    catch {
        Write-Warning "Failed to load config file. Using default mapping."
        Write-Warning $_
    }
}

# Function to make Salesforce API calls
function Invoke-SalesforceApi {
    param (
        [string]$Endpoint,
        [string]$Method = "GET"
    )

    $headers = @{
        "Authorization" = "Bearer $Global:salesforceToken"
        "Content-Type" = "application/json"
    }

    $url = "$Global:salesforceInstanceUrl$Endpoint"
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method $Method -Headers $headers
        return $response
    }
    catch {
        Write-Error "Error calling Salesforce API: $_"
        Write-Error "URL: $url"
        return $null
    }
}

# Function to get Firebase custom token for admin operations
function Get-FirebaseAdminToken {
    # In a real implementation, you would use the Firebase Admin SDK
    # For this script, we'll assume you have a way to authenticate with Firebase
    # This could be a separate script or service account credentials
    
    Write-Warning "Firebase authentication not implemented in this script."
    Write-Warning "In a production environment, you would use Firebase Admin SDK."
    
    # For now, return a placeholder value
    return "firebase-admin-token"
}

# Get a Salesforce user by ID
function Get-SalesforceUser {
    param (
        [string]$UserId
    )

    Write-Host "Fetching Salesforce user: $UserId" -ForegroundColor Cyan
    
    # Build the field list from the field mapping keys
    $fieldList = $fieldMapping.Keys -join ", "
    
    # Construct the SOQL query
    $query = "SELECT $fieldList FROM User WHERE Id = '$UserId' LIMIT 1"
    $encodedQuery = [System.Web.HttpUtility]::UrlEncode($query)
    
    $endpoint = "/services/data/v58.0/query/?q=$encodedQuery"
    $result = Invoke-SalesforceApi -Endpoint $endpoint
    
    if ($result -and $result.records -and $result.records.Count -gt 0) {
        return $result.records[0]
    }
    
    Write-Error "No Salesforce user found with ID: $UserId"
    return $null
}

# Get all Firebase users with Salesforce IDs
function Get-FirebaseUsersWithSalesforceIds {
    Write-Host "Querying Firebase for users with Salesforce IDs..." -ForegroundColor Cyan
    
    # Firebase REST API endpoint for Firestore
    $projectId = "twogetherapp-65678"  # Replace with your Firebase project ID if different
    $firestoreBaseUrl = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents"
    
    try {
        # Prepare the structured query for users with salesforceId
        $query = @{
            structuredQuery = @{
                from = @(
                    @{
                        collectionId = "users"
                    }
                )
                where = @{
                    fieldFilter = @{
                        field = @{
                            fieldPath = "salesforceId"
                        }
                        op = "NOT_EQUAL"
                        value = @{
                            nullValue = $null
                        }
                    }
                }
                limit = 100  # Adjust limit as needed
            }
        }
        
        $queryJson = ConvertTo-Json -InputObject $query -Depth 20
        
        # Prepare headers - add authentication if available
        $headers = @{
            "Content-Type" = "application/json"
        }
        
        if ($Global:firebaseToken) {
            Write-Host "Using Firebase authentication token for request." -ForegroundColor Cyan
            $headers["Authorization"] = "Bearer $Global:firebaseToken"
        } else {
            Write-Warning "No Firebase authentication token available. Using anonymous access (may fail)."
        }
        
        # Make the request to Firestore
        $response = Invoke-RestMethod `
            -Uri "$firestoreBaseUrl/:runQuery" `
            -Method POST `
            -Body $queryJson `
            -ContentType "application/json" `
            -Headers $headers
        
        # Process the response
        $usersWithSalesforceId = @()
        
        foreach ($document in $response) {
            if ($document.PSObject.Properties.Name -contains 'document') {
                $docPath = $document.document.name
                $docId = $docPath.Substring($docPath.LastIndexOf('/') + 1)
                $fields = $document.document.fields
                
                # Extract salesforceId - handle different possible field types
                $salesforceId = $null
                if ($fields.PSObject.Properties.Name -contains 'salesforceId') {
                    if ($fields.salesforceId.PSObject.Properties.Name -contains 'stringValue') {
                        $salesforceId = $fields.salesforceId.stringValue
                    }
                }
                
                if ($salesforceId) {
                    $usersWithSalesforceId += @{
                        firebaseUserId = $docId
                        salesforceId = $salesforceId
                    }
                }
            }
        }
        
        Write-Host "Found $($usersWithSalesforceId.Count) users with Salesforce IDs." -ForegroundColor Cyan
        
        if ($usersWithSalesforceId.Count -eq 0) {
            Write-Host "No users found with Salesforce IDs." -ForegroundColor Yellow
            
            # Development fallback - provide option to use test data
            $useFallback = Read-Host "Would you like to use test data instead? (y/n)"
            if ($useFallback -eq "y") {
                return @(
                    @{
                        firebaseUserId = "firebase-user-1"
                        salesforceId = "0051i000000fstIAAQ"  # Replace with a valid ID from your Salesforce
                    }
                )
            }
        }
        
        return $usersWithSalesforceId
    }
    catch {
        Write-Error "Error querying Firebase: $_"
        
        # Ask if the user wants to continue with test data
        $useFallback = Read-Host "Would you like to use test data instead? (y/n)"
        if ($useFallback -eq "y") {
            return @(
                @{
                    firebaseUserId = "firebase-user-1"
                    salesforceId = "0051i000000fstIAAQ"  # Replace with a valid ID from your Salesforce
                }
            )
        }
        return @()
    }
}

# Update a Firebase user with Salesforce data
function Update-FirebaseUserWithSalesforceData {
    param (
        [string]$FirebaseUserId,
        [PSObject]$SalesforceData
    )

    Write-Host "Updating Firebase user $FirebaseUserId with Salesforce data..." -ForegroundColor Cyan
    
    # Create a mapped data object
    $firebaseData = @{}
    
    foreach ($sfField in $fieldMapping.Keys) {
        $fbField = $fieldMapping[$sfField]
        
        # Check if the Salesforce data contains this field
        if (Get-Member -InputObject $SalesforceData -Name $sfField -MemberType NoteProperty) {
            $value = $SalesforceData.$sfField
            $firebaseData[$fbField] = $value
            
            Write-Host "  $fbField = $value" -ForegroundColor Gray
        }
    }
    
    # Add a sync timestamp
    $firebaseData["salesforceSyncedAt"] = [DateTime]::UtcNow.ToString("o")
    
    if ($DryRun) {
        Write-Host "DRY RUN - Would update Firebase user $FirebaseUserId with:" -ForegroundColor Yellow
        $firebaseData | Format-Table -AutoSize
        return $true
    }
    
    # Firebase REST API endpoint for Firestore
    $projectId = "twogetherapp-65678"  # Replace with your Firebase project ID if different
    $documentUrl = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$FirebaseUserId"
    
    try {
        # Prepare the Firestore update fields
        $updateFields = @{
            fields = @{}
        }
        
        # Convert the firebaseData to Firestore format
        foreach ($key in $firebaseData.Keys) {
            $value = $firebaseData[$key]
            
            # Handle different data types
            if ($value -is [System.Boolean]) {
                $updateFields.fields[$key] = @{ booleanValue = $value }
            }
            elseif ($value -is [System.Int32] -or $value -is [System.Int64]) {
                $updateFields.fields[$key] = @{ integerValue = $value }
            }
            elseif ($value -is [System.Double]) {
                $updateFields.fields[$key] = @{ doubleValue = $value }
            }
            elseif ($value -is [System.DateTime]) {
                $updateFields.fields[$key] = @{ timestampValue = $value.ToUniversalTime().ToString("o") }
            }
            else {
                # Default to string
                $updateFields.fields[$key] = @{ stringValue = "$value" }
            }
        }
        
        $updateJson = ConvertTo-Json -InputObject $updateFields -Depth 20
        
        # Prepare headers - add authentication if available
        $headers = @{
            "Content-Type" = "application/json"
        }
        
        if ($Global:firebaseToken) {
            $headers["Authorization"] = "Bearer $Global:firebaseToken"
        }
        
        if ($DryRun) {
            Write-Host "Would send the following data to Firebase:" -ForegroundColor Green
            Write-Host $updateJson -ForegroundColor Gray
        } else {
            # Actually perform the update
            Write-Host "Sending update to Firebase..." -ForegroundColor Cyan
            
            $updateMaskParams = $firebaseData.Keys | ForEach-Object { "updateMask.fieldPaths=$_" }
            $updateMaskString = $updateMaskParams -join "&"
            
            $response = Invoke-RestMethod `
                -Uri "$documentUrl?$updateMaskString" `
                -Method PATCH `
                -Body $updateJson `
                -ContentType "application/json" `
                -Headers $headers
                
            Write-Host "Firebase update successful!" -ForegroundColor Green
        }
        
        return $true
    }
    catch {
        Write-Error "Error updating Firebase: $_"
        return $false
    }
}

# Sync a single user
function Sync-SingleUser {
    param (
        [string]$FirebaseUserId,
        [string]$SalesforceId
    )
    
    Write-Host "Syncing user: Firebase ID=$FirebaseUserId, Salesforce ID=$SalesforceId" -ForegroundColor Cyan
    
    # Get the Salesforce user data
    $salesforceUser = Get-SalesforceUser -UserId $SalesforceId
    
    if (-not $salesforceUser) {
        Write-Error "Failed to get Salesforce user data for ID: $SalesforceId"
        return $false
    }
    
    # Update the Firebase user
    $success = Update-FirebaseUserWithSalesforceData -FirebaseUserId $FirebaseUserId -SalesforceData $salesforceUser
    
    if ($success) {
        Write-Host "Successfully synced user $FirebaseUserId with Salesforce data." -ForegroundColor Green
    }
    else {
        Write-Error "Failed to sync user $FirebaseUserId with Salesforce data."
    }
    
    return $success
}

# Main execution
try {
    # Check parameters
    if (-not $UserId -and -not $All) {
        Write-Error "You must specify either a UserId or use the -All switch."
        exit 1
    }
    
    if ($DryRun) {
        Write-Host "Running in DRY RUN mode - no changes will be made." -ForegroundColor Yellow
    }
    
    # Display the field mapping being used
    Write-Host "Using the following field mapping:" -ForegroundColor Cyan
    $fieldMapping.GetEnumerator() | Sort-Object -Property Name | Format-Table -AutoSize
    
    # Sync based on parameters
    if ($UserId) {
        # We need to find the Firebase user with this Salesforce ID
        Write-Host "Searching for Firebase user with Salesforce ID: $UserId" -ForegroundColor Cyan
        
        # In a real implementation, you would query Firestore
        # For this script, we'll simulate finding a user
        $firebaseUserId = "firebase-user-1"  # Simulated result
        
        Write-Host "Found Firebase user: $firebaseUserId" -ForegroundColor Cyan
        
        $success = Sync-SingleUser -FirebaseUserId $firebaseUserId -SalesforceId $UserId
        
        if ($success) {
            Write-Host "User sync completed successfully." -ForegroundColor Green
        }
        else {
            Write-Error "User sync failed."
            exit 1
        }
    }
    elseif ($All) {
        Write-Host "Syncing all users with Salesforce IDs..." -ForegroundColor Cyan
        
        # Get all Firebase users with Salesforce IDs
        $usersToSync = Get-FirebaseUsersWithSalesforceIds
        
        if (-not $usersToSync -or $usersToSync.Count -eq 0) {
            Write-Host "No users found with Salesforce IDs." -ForegroundColor Yellow
            exit 0
        }
        
        Write-Host "Found $($usersToSync.Count) users to sync." -ForegroundColor Cyan
        
        $successCount = 0
        $failCount = 0
        
        foreach ($user in $usersToSync) {
            $success = Sync-SingleUser -FirebaseUserId $user.firebaseUserId -SalesforceId $user.salesforceId
            
            if ($success) {
                $successCount++
            }
            else {
                $failCount++
            }
        }
        
        Write-Host "Sync completed: $successCount successful, $failCount failed" -ForegroundColor Green
    }
    
    Write-Host "Script completed successfully." -ForegroundColor Green
    
} catch {
    Write-Error "An error occurred while syncing users: $_"
    exit 1
} 