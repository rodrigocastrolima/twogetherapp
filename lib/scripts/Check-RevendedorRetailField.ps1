# Check-RevendedorRetailField.ps1
# Script to specifically check the Revendedor_Retail__c field for Salesforce users
# Usage: ./Check-RevendedorRetailField.ps1 [-Limit <number>]

param (
    [int]$Limit = 20      # Limit the number of results
)

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

# Main script execution
try {
    Write-Host "Checking 'Revendedor_Retail__c' field in Salesforce..." -ForegroundColor Cyan
    
    # First, get field metadata to understand the field type and properties
    $metadata = Invoke-SalesforceApi -Endpoint "/services/data/v58.0/sobjects/User/describe"
    
    if (-not $metadata -or -not $metadata.fields) {
        Write-Error "Failed to retrieve User object metadata from Salesforce."
        exit 1
    }
    
    # Look for our specific field
    $fieldMetadata = $metadata.fields | Where-Object { $_.name -eq "Revendedor_Retail__c" }
    
    if ($fieldMetadata) {
        Write-Host "`nField 'Revendedor_Retail__c' found in User object:" -ForegroundColor Green
        Write-Host "Label: $($fieldMetadata.label)"
        Write-Host "Type: $($fieldMetadata.type)"
        Write-Host "Length: $($fieldMetadata.length)"
        Write-Host "Required: $($fieldMetadata.nillable)"
        Write-Host "Custom: $($fieldMetadata.custom)"
        
        if ($fieldMetadata.picklistValues -and $fieldMetadata.picklistValues.Count -gt 0) {
            Write-Host "`nPossible values:" -ForegroundColor Magenta
            foreach ($value in $fieldMetadata.picklistValues) {
                $activeStatus = if ($value.active) { "Active" } else { "Inactive" }
                Write-Host "- $($value.value) ($($value.label)) [$activeStatus]"
            }
        }
    } else {
        Write-Host "`nField 'Revendedor_Retail__c' not found in User object." -ForegroundColor Yellow
        
        # Suggest similar fields
        $similarFields = $metadata.fields | Where-Object { 
            $_.name -like "*Revend*" -or 
            $_.name -like "*Retail*" -or 
            $_.label -like "*Revend*" -or 
            $_.label -like "*Retail*" 
        }
        
        if ($similarFields.Count -gt 0) {
            Write-Host "`nSimilar fields found:" -ForegroundColor Cyan
            foreach ($field in $similarFields) {
                Write-Host "- $($field.name) (Label: $($field.label), Type: $($field.type))"
            }
        }
        
        # Exit early since we can't find the field
        exit 0
    }
    
    # Now find users with this field populated
    Write-Host "`nFetching users with 'Revendedor_Retail__c' field populated..." -ForegroundColor Yellow
    
    # Define query to find users with the field
    $query = "SELECT Id, Name, Username, Email, Revendedor_Retail__c FROM User WHERE Revendedor_Retail__c != null LIMIT $Limit"
    $encodedQuery = [System.Web.HttpUtility]::UrlEncode($query)
    $endpoint = "/services/data/v58.0/query/?q=$encodedQuery"
    $response = Invoke-SalesforceApi -Endpoint $endpoint
    
    if (-not $response -or -not $response.records -or $response.records.Count -eq 0) {
        Write-Host "`nNo users found with 'Revendedor_Retail__c' field populated." -ForegroundColor Yellow
        
        # Try to check if the field exists by querying all users
        $query = "SELECT Id, Name, Username, Email FROM User LIMIT 1"
        $encodedQuery = [System.Web.HttpUtility]::UrlEncode($query)
        $endpoint = "/services/data/v58.0/query/?q=$encodedQuery"
        $anyUserResponse = Invoke-SalesforceApi -Endpoint $endpoint
        
        if ($anyUserResponse -and $anyUserResponse.records -and $anyUserResponse.records.Count -gt 0) {
            $userId = $anyUserResponse.records[0].Id
            
            # Try to get a specific user with all fields to see if Revendedor_Retail__c is present
            $specificUserEndpoint = "/services/data/v58.0/sobjects/User/$userId"
            $userDetail = Invoke-SalesforceApi -Endpoint $specificUserEndpoint
            
            if ($userDetail -and $userDetail.PSObject.Properties.Name -contains "Revendedor_Retail__c") {
                Write-Host "Field exists but no users have it populated." -ForegroundColor Yellow
            } else {
                Write-Host "Field may not be accessible or doesn't exist for all users." -ForegroundColor Yellow
            }
        }
        
        exit 0
    }
    
    $users = $response.records
    
    # Display users with the field populated
    Write-Host "`nFound $($users.Count) users with 'Revendedor_Retail__c' populated:" -ForegroundColor Green
    
    # Analyze the values to determine what type of data it contains
    $values = $users | Select-Object -ExpandProperty Revendedor_Retail__c -Unique
    
    # Check if values look like booleans
    $booleanLike = $true
    foreach ($value in $values) {
        if ($value -ne $true -and $value -ne $false -and $value -ne "true" -and $value -ne "false") {
            $booleanLike = $false
            break
        }
    }
    
    # Check if values look like IDs
    $idLike = $true
    foreach ($value in $values) {
        if ($value -notmatch '^[a-zA-Z0-9]{15,18}$') {
            $idLike = $false
            break
        }
    }
    
    Write-Host "`nValue Analysis:" -ForegroundColor Cyan
    Write-Host "Unique values: $($values.Count)"
    Write-Host "Boolean-like: $booleanLike"
    Write-Host "ID-like: $idLike"
    
    Write-Host "`nSample Users:" -ForegroundColor Yellow
    $users | ForEach-Object {
        $user = $_
        Write-Host "`n----- User: $($user.Name) -----" -ForegroundColor Cyan
        Write-Host "ID: $($user.Id)"
        Write-Host "Username: $($user.Username)"
        Write-Host "Email: $($user.Email)"
        Write-Host "Revendedor_Retail__c: $($user.Revendedor_Retail__c)"
        
        # If it looks like an ID, try to look up what it references
        if ($idLike) {
            $revendedorId = $user.Revendedor_Retail__c
            
            # Try to query what kind of object this ID belongs to
            try {
                $idPrefix = $revendedorId.Substring(0, 3)
                
                # Query the object with this prefix
                $globalDescribeEndpoint = "/services/data/v58.0/sobjects/"
                $globalDescribe = Invoke-SalesforceApi -Endpoint $globalDescribeEndpoint
                
                if ($globalDescribe -and $globalDescribe.sobjects) {
                    $matchingObject = $globalDescribe.sobjects | Where-Object { $_.keyPrefix -eq $idPrefix }
                    
                    if ($matchingObject) {
                        Write-Host "  ↳ References: $($matchingObject.name) object"
                        
                        # Try to query this object to get more information
                        $objectQueryEndpoint = "/services/data/v58.0/sobjects/$($matchingObject.name)/$revendedorId"
                        $referencedObject = Invoke-SalesforceApi -Endpoint $objectQueryEndpoint
                        
                        if ($referencedObject) {
                            Write-Host "  ↳ Referenced Object Name: $($referencedObject.Name)" -ForegroundColor Magenta
                        }
                    }
                }
            } catch {
                # Silently handle errors in lookup, this is just an extra feature
            }
        }
        
        Write-Host "------------------------------"
    }
    
    # Offer to sync users to Firebase
    Write-Host "`nNext Steps:" -ForegroundColor Green
    Write-Host "1. You can sync these users to Firebase with the 'Revendedor_Retail__c' field using Sync-SalesforceUserToFirebase.ps1"
    Write-Host "2. Add 'revendedorRetail' to your field mapping in the Flutter app's SalesforceUserSyncService"
    
    # Offer to export to CSV
    $exportCsv = Read-Host "Would you like to export the results to CSV? (y/n)"
    if ($exportCsv -eq "y") {
        $csvPath = Join-Path $PSScriptRoot "salesforce_revendedor_retail_users.csv"
        $users | Export-Csv -Path $csvPath -NoTypeInformation
        Write-Host "Users exported to: $csvPath" -ForegroundColor Green
    }
    
} catch {
    Write-Error "An error occurred: $_"
    exit 1
} 