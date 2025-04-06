# Script to list Record Types for a specific Salesforce object
# First, get the Salesforce token using the existing script
$salesforceToken = $null
$salesforceInstanceUrl = $null

# Execute the token script
Write-Host "Getting Salesforce authentication token..." -ForegroundColor Cyan
. .\Get-SalesforceToken.ps1

# Verify we have the token
if (-not $salesforceToken) {
    Write-Error "Failed to obtain Salesforce token. Script will exit."
    exit 1
}

Write-Host "Successfully obtained Salesforce token." -ForegroundColor Green

# Ask for the object name
Write-Host "Enter the API name of the Salesforce object:" -ForegroundColor Yellow
$objectName = Read-Host

# Query for RecordType records related to this object
Write-Host "Retrieving Record Types for $objectName..." -ForegroundColor Cyan

# Build SOQL query to get record types for this object
$query = "SELECT Id, Name, DeveloperName, Description, IsActive FROM RecordType WHERE SobjectType = '$objectName' ORDER BY Name"

# URL encode the query - using .NET's [Uri]::EscapeDataString method which is built-in
$encodedQuery = [Uri]::EscapeDataString($query)
$queryUrl = "$salesforceInstanceUrl/services/data/v58.0/query/?q=$encodedQuery"

try {
    $headers = @{
        "Authorization" = "Bearer $salesforceToken"
        "Content-Type" = "application/json"
    }
    
    $response = Invoke-WebRequest -Uri $queryUrl -Headers $headers -Method Get -UseBasicParsing
    
    # Parse the JSON response
    $data = $response.Content | ConvertFrom-Json
    
    # Output the results
    if ($data.records -and $data.records.Count -gt 0) {
        Write-Host "`n--- Record Types for $objectName ---" -ForegroundColor Green
        $data.records | ForEach-Object {
            Write-Host "`nName: $($_.Name)" -ForegroundColor Cyan
            Write-Host "Developer Name: $($_.DeveloperName)"
            Write-Host "ID: $($_.Id)"
            Write-Host "Description: $($_.Description)"
            Write-Host "Active: $($_.IsActive)"
        }
        Write-Host "`nTotal Record Types: $($data.records.Count)" -ForegroundColor Green
        
        # Ask if user wants to export record types to CSV
        Write-Host "`nWould you like to export record types to CSV? (y/n)" -ForegroundColor Yellow
        $exportCsv = Read-Host
        
        if ($exportCsv -eq "y") {
            $csvPath = "$objectName-recordtypes.csv"
            $data.records | 
                Select-Object Id, Name, DeveloperName, Description, IsActive | 
                Export-Csv -Path $csvPath -NoTypeInformation
            Write-Host "Record Types exported to $csvPath" -ForegroundColor Green
        }
    }
    else {
        Write-Host "`nNo Record Types found for $objectName" -ForegroundColor Yellow
    }
}
catch {
    Write-Error "Error retrieving Record Types: $_"
    Write-Error $_.Exception.Message
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Error "Response body: $responseBody"
    }
} 