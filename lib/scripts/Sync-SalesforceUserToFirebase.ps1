# Sync-SalesforceUserToFirebase.ps1
# Script to sync Salesforce user data to Firebase
# Usage: 
#   Single user:   ./Sync-SalesforceUserToFirebase.ps1 -SalesforceId <ID> [-FirebaseId <Firebase UID>] [-DryRun]
#   All users:     ./Sync-SalesforceUserToFirebase.ps1 -All [-DryRun]
#   Specific field: ./Sync-SalesforceUserToFirebase.ps1 -All -FieldsOnly "Revendedor_Retail__c" [-DryRun]

param (
    [Parameter(Mandatory=$false)]
    [string]$SalesforceId,           # Salesforce User ID (for single user sync)
    
    [Parameter(Mandatory=$false)]
    [string]$FirebaseId,             # Optional Firebase User ID (if known)
    
    [Parameter(Mandatory=$false)]
    [switch]$All,                    # Sync all users with salesforceId
    
    [Parameter(Mandatory=$false)]
    [string[]]$FieldsOnly,           # Only sync specific fields (optional)
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,                 # If set, don't actually update Firebase
    
    [Parameter(Mandatory=$false)]
    [string]$FirebaseProject = "twogetherapp-65678",  # Firebase project ID
    
    [Parameter(Mandatory=$false)]
    [string]$FirestoreCollection = "users",  # Firestore collection name
    
    [Parameter(Mandatory=$false)]
    [int]$Limit = 50                 # Limit the number of users to process in batch mode
)

# Validate parameters
if (-not $SalesforceId -and -not $All) {
    Write-Error "Either -SalesforceId or -All parameter must be specified"
    exit 1
}

if ($SalesforceId -and $All) {
    Write-Error "Cannot specify both -SalesforceId and -All parameters"
    exit 1
}

# Load the authentication helper script
$authScriptPath = Join-Path $PSScriptRoot "Get-SalesforceToken.ps1"
if (-not (Test-Path $authScriptPath)) {
    Write-Error "Authentication script not found at: $authScriptPath"
    exit 1
}

# Source the authentication script to get access token and instance URL
. $authScriptPath

# Check if we have valid authentication
if (-not $Global:salesforceToken -or -not $Global:salesforceInstanceUrl) {
    Write-Error "Authentication failed. Couldn't obtain Salesforce token or instance URL."
    exit 1
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

# Define a mapping of Salesforce fields to Firebase fields
$fieldMapping = @{
    "displayName" = "Name"
    "name" = "Name"
    "firstName" = "FirstName"
    "lastName" = "LastName"
    "email" = "Email"
    "phoneNumber" = "Phone"
    "mobilePhone" = "MobilePhone"
    "department" = "Department"
    "title" = "Title"
    "company" = "CompanyName"
    "salesforceId" = "Id"
    "isActive" = "IsActive"
    "revendedorRetail" = "Revendedor_Retail__c"  # Important mapping for revendedor
    "funcaoRetail" = "Fun_o_Retail__c" 
    "iban" = "IBAN__c"
}

# Check for Firebase CLI
$firebaseCLI = $null
try {
    $firebaseCLI = Get-Command firebase -ErrorAction SilentlyContinue
} catch {}

if (-not $firebaseCLI) {
    Write-Host "Firebase CLI not found. Please install it with npm: npm install -g firebase-tools" -ForegroundColor Yellow
    if (-not $DryRun) {
        Write-Error "Firebase CLI is required for actual synchronization. Use -DryRun to preview changes."
        exit 1
    }
}

# Function to get a Salesforce user by ID
function Get-SalesforceUser {
    param (
        [string]$Id
    )
    
    try {
        # Define fields to fetch
        $fieldsToFetch = if ($FieldsOnly -and $FieldsOnly.Count -gt 0) {
            # Always include Id
            $FieldsOnly + @("Id") | Select-Object -Unique
        } else {
            # Map Firebase field names to Salesforce field names
            $fieldMapping.Values
        }
        
        # Ensure no duplicates
        $fieldsToFetch = $fieldsToFetch | Select-Object -Unique
        
        # Create field list for query
        $fieldList = $fieldsToFetch -join ", "
        
        # Create SOQL query
        $query = "SELECT $fieldList FROM User WHERE Id = '$Id' LIMIT 1"
        
        Write-Verbose "Executing Salesforce query: $query"
        
        # URL encode the query
        $encodedQuery = [System.Web.HttpUtility]::UrlEncode($query)
        
        # Execute the query
        $endpoint = "/services/data/v58.0/query/?q=$encodedQuery"
        $response = Invoke-SalesforceApi -Endpoint $endpoint
        
        if (-not $response -or -not $response.records -or $response.records.Count -eq 0) {
            Write-Warning "No Salesforce user found with ID: $Id"
            return $null
        }
        
        # Handle query errors
        if ($response.PSObject.Properties.Name -contains "errors" -and $response.errors.Count -gt 0) {
            Write-Warning "Error in Salesforce query: $($response.errors[0].message)"
            
            # Try a more basic query with fewer fields
            Write-Host "Retrying with basic fields..." -ForegroundColor Yellow
            $basicQuery = "SELECT Id, Name, Email FROM User WHERE Id = '$Id' LIMIT 1"
            $encodedBasicQuery = [System.Web.HttpUtility]::UrlEncode($basicQuery)
            $basicEndpoint = "/services/data/v58.0/query/?q=$encodedBasicQuery"
            $basicResponse = Invoke-SalesforceApi -Endpoint $basicEndpoint
            
            if ($basicResponse -and $basicResponse.records -and $basicResponse.records.Count -gt 0) {
                return $basicResponse.records[0]
            } else {
                return $null
            }
        }
        
        return $response.records[0]
    } catch {
        Write-Error "Error retrieving Salesforce user: $_"
        return $null
    }
}

# Function to get Firebase users with Salesforce IDs
function Get-FirebaseUsersWithSalesforceIds {
    param (
        [int]$Limit = 50
    )
    
    try {
        # Ensure Firebase CLI is logged in
        $loginCheck = & firebase projects:list --json
        $loginCheckObj = $loginCheck | ConvertFrom-Json
        
        if (-not $loginCheckObj -or $loginCheckObj.status -ne "success") {
            Write-Host "Firebase login required..." -ForegroundColor Yellow
            & firebase login
        }
        
        # Query Firestore for users with salesforceId
        Write-Host "Querying Firestore for users with salesforceId..." -ForegroundColor Cyan
        
        $queryCommand = "firebase firestore:query $FirestoreCollection --where='salesforceId' --op='!=' --value='' --limit=$Limit --project=$FirebaseProject --json"
        Write-Verbose "Executing: $queryCommand"
        
        $usersData = Invoke-Expression $queryCommand | ConvertFrom-Json
        
        if (-not $usersData -or -not $usersData.__collections -or -not $usersData.__collections.$FirestoreCollection) {
            Write-Warning "No users found with salesforceId in Firebase"
            return @()
        }
        
        $users = $usersData.__collections.$FirestoreCollection
        
        return $users | ForEach-Object {
            [PSCustomObject]@{
                FirebaseId = $_.__name
                SalesforceId = $_.salesforceId
                DisplayName = $_.displayName
                Email = $_.email
            }
        }
    } catch {
        Write-Error "Error retrieving Firebase users: $_"
        return @()
    }
}

# Function to update a Firebase user with Salesforce data
function Update-FirebaseUser {
    param (
        [string]$FirebaseId,
        [PSObject]$SalesforceData,
        [switch]$DryRun = $false
    )
    
    try {
        # Map Salesforce data to Firebase format
        $firebaseData = @{}
        
        # Map fields based on our mapping
        foreach ($item in $fieldMapping.GetEnumerator()) {
            $firebaseField = $item.Key
            $salesforceField = $item.Value
            
            # If we're only updating specific fields, check if this field is included
            if ($FieldsOnly -and $FieldsOnly.Count -gt 0 -and $salesforceField -notin $FieldsOnly -and $salesforceField -ne "Id") {
                continue
            }
            
            # Get the Salesforce value if it exists
            if ($SalesforceData.PSObject.Properties.Name -contains $salesforceField -and $null -ne $SalesforceData.$salesforceField) {
                $firebaseData[$firebaseField] = $SalesforceData.$salesforceField
            }
        }
        
        # Add timestamp for the sync
        $firebaseData["salesforceSyncedAt"] = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        
        # Convert to JSON
        $firebaseDataJson = $firebaseData | ConvertTo-Json -Depth 10
        
        # Display the update data
        Write-Host "Data to update for user $FirebaseId (Firebase):" -ForegroundColor Cyan
        Write-Host $firebaseDataJson
        
        # Skip actual update if in dry run mode
        if ($DryRun) {
            Write-Host "DRY RUN - No changes made to Firebase" -ForegroundColor Yellow
            return $true
        }
        
        # Save data to a temporary file
        $tempFile = [System.IO.Path]::GetTempFileName()
        $firebaseDataJson | Out-File -FilePath $tempFile -Encoding utf8
        
        # Update Firestore
        $updateCommand = "firebase firestore:update '$FirestoreCollection/$FirebaseId' --project=$FirebaseProject '$tempFile'"
        Write-Verbose "Executing: $updateCommand"
        
        & firebase firestore:update "$FirestoreCollection/$FirebaseId" --project=$FirebaseProject $tempFile
        $updateSuccess = $LASTEXITCODE -eq 0
        
        # Clean up temp file
        Remove-Item -Path $tempFile -Force
        
        if ($updateSuccess) {
            Write-Host "Successfully updated Firestore document '$FirestoreCollection/$FirebaseId'" -ForegroundColor Green
            return $true
        } else {
            Write-Error "Failed to update Firestore document"
            return $false
        }
    } catch {
        Write-Error "Error updating Firebase user: $_"
        return $false
    }
}

# Function to sync a single user
function Sync-SingleUser {
    param (
        [string]$SalesforceId,
        [string]$FirebaseId = "",
        [switch]$DryRun = $false
    )
    
    try {
        # Get Salesforce user data
        Write-Host "Fetching Salesforce user data for ID: $SalesforceId" -ForegroundColor Yellow
        $salesforceUser = Get-SalesforceUser -Id $SalesforceId
        
        if (-not $salesforceUser) {
            Write-Error "No user found in Salesforce with ID: $SalesforceId"
            return $false
        }
        
        # Display Salesforce user data
        Write-Host "`nSalesforce User Information:" -ForegroundColor Green
        Write-Host "ID: $($salesforceUser.Id)"
        
        if ($salesforceUser.PSObject.Properties.Name -contains "Name") {
            Write-Host "Name: $($salesforceUser.Name)"
        }
        
        if ($salesforceUser.PSObject.Properties.Name -contains "Email") {
            Write-Host "Email: $($salesforceUser.Email)"
        }
        
        if ($salesforceUser.PSObject.Properties.Name -contains "IsActive") {
            Write-Host "IsActive: $($salesforceUser.IsActive)"
        }
        
        # Show custom fields
        $customProperties = $salesforceUser.PSObject.Properties | Where-Object { 
            $_.Name -like "*__c" -and $null -ne $_.Value 
        }
        
        if ($customProperties.Count -gt 0) {
            Write-Host "`nCustom Fields:" -ForegroundColor Magenta
            foreach ($prop in $customProperties) {
                Write-Host "$($prop.Name): $($prop.Value)"
            }
        }
        
        # If Firebase ID is not provided, try to find a matching user
        if ([string]::IsNullOrWhiteSpace($FirebaseId)) {
            Write-Host "`nNo Firebase user ID provided. Attempting to find a matching user..." -ForegroundColor Yellow
            
            # Use Firebase CLI to find matching user
            $query = "firebase firestore:query $FirestoreCollection --where='salesforceId' --op='==' --value='$SalesforceId' --limit=1 --project=$FirebaseProject --json"
            $searchResult = Invoke-Expression $query | ConvertFrom-Json
            
            if ($searchResult -and $searchResult.__collections -and $searchResult.__collections.$FirestoreCollection -and $searchResult.__collections.$FirestoreCollection.Count -gt 0) {
                $matchedUser = $searchResult.__collections.$FirestoreCollection[0]
                $FirebaseId = $matchedUser.__name
                Write-Host "Found matching Firebase user with ID: $FirebaseId" -ForegroundColor Green
            } else {
                Write-Error "No matching Firebase user found with salesforceId: $SalesforceId"
                Write-Host "Please specify a Firebase user ID with the -FirebaseId parameter" -ForegroundColor Yellow
                return $false
            }
        }
        
        # Update Firebase user with Salesforce data
        return Update-FirebaseUser -FirebaseId $FirebaseId -SalesforceData $salesforceUser -DryRun:$DryRun
    } catch {
        Write-Error "Error syncing user: $_"
        return $false
    }
}

# Function to sync all users
function Sync-AllUsers {
    param (
        [switch]$DryRun = $false
    )
    
    try {
        # Get Firebase users with Salesforce IDs
        $users = Get-FirebaseUsersWithSalesforceIds -Limit $Limit
        
        if ($users.Count -eq 0) {
            Write-Warning "No users found with salesforceId in Firebase"
            return
        }
        
        Write-Host "Found $($users.Count) users with salesforceId in Firebase" -ForegroundColor Green
        
        # Display users
        $users | Format-Table -AutoSize
        
        # Confirm synchronization
        if (-not $DryRun) {
            $confirmation = Read-Host "Do you want to sync these users with Salesforce? (y/n)"
            if ($confirmation -ne "y") {
                Write-Host "Synchronization cancelled by user" -ForegroundColor Yellow
                return
            }
        }
        
        # Process each user
        $successCount = 0
        $failCount = 0
        
        foreach ($user in $users) {
            Write-Host "`nProcessing user: $($user.DisplayName) ($($user.FirebaseId))" -ForegroundColor Cyan
            
            $success = Sync-SingleUser -SalesforceId $user.SalesforceId -FirebaseId $user.FirebaseId -DryRun:$DryRun
            
            if ($success) {
                $successCount++
            } else {
                $failCount++
            }
        }
        
        # Display summary
        Write-Host "`nSynchronization Summary:" -ForegroundColor Green
        Write-Host "Total users: $($users.Count)"
        Write-Host "Successful: $successCount"
        Write-Host "Failed: $failCount"
        
        if ($DryRun) {
            Write-Host "`nDRY RUN - No changes were made to Firebase" -ForegroundColor Yellow
        }
    } catch {
        Write-Error "Error syncing all users: $_"
    }
}

# Main script execution
try {
    # Configure Verbose output if needed
    if ($PSBoundParameters['Verbose']) {
        $VerbosePreference = 'Continue'
    }
    
    # Display script mode
    if ($All) {
        Write-Host "Running in BATCH mode - Processing multiple users" -ForegroundColor Cyan
        
        if ($FieldsOnly) {
            Write-Host "Only syncing the following fields: $($FieldsOnly -join ', ')" -ForegroundColor Cyan
        }
        
        if ($DryRun) {
            Write-Host "DRY RUN enabled - No changes will be made to Firebase" -ForegroundColor Yellow
        }
        
        # Sync all users
        Sync-AllUsers -DryRun:$DryRun
    } else {
        Write-Host "Running in SINGLE USER mode - Processing Salesforce ID: $SalesforceId" -ForegroundColor Cyan
        
        if ($FieldsOnly) {
            Write-Host "Only syncing the following fields: $($FieldsOnly -join ', ')" -ForegroundColor Cyan
        }
        
        if ($DryRun) {
            Write-Host "DRY RUN enabled - No changes will be made to Firebase" -ForegroundColor Yellow
        }
        
        # Sync single user
        $success = Sync-SingleUser -SalesforceId $SalesforceId -FirebaseId $FirebaseId -DryRun:$DryRun
        
        if (-not $success) {
            Write-Error "Failed to sync user with Salesforce ID: $SalesforceId"
            exit 1
        }
    }
    
    Write-Host "`nScript completed successfully" -ForegroundColor Green
} catch {
    Write-Error "An unhandled error occurred: $_"
    exit 1
} 