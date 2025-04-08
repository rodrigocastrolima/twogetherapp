# List-SalesforceUsers.ps1
# Script to list Salesforce users and their information
# Usage: ./List-SalesforceUsers.ps1 [-Query <SOQL query>] [-Limit <number>]

param (
    [string]$Query = "",  # Custom SOQL query (optional)
    [int]$Limit = 10      # Limit the number of results
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
    # Define default fields to query if no custom query is provided
    if ([string]::IsNullOrWhiteSpace($Query)) {
        $fields = @(
            "Id", "Username"
        )
        
        # Add custom fields if they exist
        $metadata = Invoke-SalesforceApi -Endpoint "/services/data/v58.0/sobjects/User/describe"
        if ($metadata -and $metadata.fields) {
            $customFields = $metadata.fields | Where-Object { $_.custom -eq $true } | Select-Object -ExpandProperty name
            if ($customFields) {
                $fields += $customFields
            }
        }
        
        $fieldsString = $fields -join ", "
        $Query = "SELECT $fieldsString FROM User WHERE IsActive = true ORDER BY Name LIMIT $Limit"
    }
    
    Write-Host "Executing query: $Query" -ForegroundColor Cyan
    
    # Execute the query
    $encodedQuery = [System.Web.HttpUtility]::UrlEncode($Query)
    $endpoint = "/services/data/v58.0/query/?q=$encodedQuery"
    $response = Invoke-SalesforceApi -Endpoint $endpoint
    
    if (-not $response -or -not $response.records) {
        Write-Host "No users found or error in query." -ForegroundColor Yellow
        exit 0
    }
    
    $users = $response.records
    Write-Host "Found $($users.Count) users." -ForegroundColor Green
    
    # Display the users in a table format
    Write-Host "`nUser Information:" -ForegroundColor Yellow
    
    # Create a formatted table with key information
    $users | ForEach-Object {
        $user = $_
        
        # Create a custom object with the properties we care most about
        $userInfo = [PSCustomObject]@{
            Id = $user.Id
            Name = $user.Name
            Username = $user.Username
            Email = $user.Email
            IsActive = $user.IsActive
            LastLogin = $user.LastLoginDate
        }
        
        # Add any custom fields that exist
        $customProperties = $user.PSObject.Properties | Where-Object { 
            $_.Name -like "*__c" -and $null -ne $_.Value 
        }
        
        foreach ($prop in $customProperties) {
            $userInfo | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
        }
        
        return $userInfo
    } | Format-Table -AutoSize
    
    # Also display detailed information for easy copy-paste
    Write-Host "`nDetailed User Information:" -ForegroundColor Yellow
    
    $users | ForEach-Object {
        $user = $_
        Write-Host "`n----- User: $($user.Name) -----" -ForegroundColor Cyan
        Write-Host "ID: $($user.Id)"
        Write-Host "Username: $($user.Username)"
        Write-Host "Email: $($user.Email)"
        Write-Host "IsActive: $($user.IsActive)"
        
        # Show custom fields
        $customProperties = $user.PSObject.Properties | Where-Object { 
            $_.Name -like "*__c" -and $null -ne $_.Value 
        }
        
        if ($customProperties.Count -gt 0) {
            Write-Host "`nCustom Fields:" -ForegroundColor Magenta
            foreach ($prop in $customProperties) {
                Write-Host "$($prop.Name): $($prop.Value)"
            }
        }
        
        Write-Host "------------------------------"
    }
    
    # Offer to export to CSV
    $exportCsv = Read-Host "Would you like to export the results to CSV? (y/n)"
    if ($exportCsv -eq "y") {
        $csvPath = Join-Path $PSScriptRoot "salesforce_users.csv"
        $users | Export-Csv -Path $csvPath -NoTypeInformation
        Write-Host "Users exported to: $csvPath" -ForegroundColor Green
    }
    
} catch {
    Write-Error "An error occurred while listing Salesforce users: $_"
    exit 1
} 