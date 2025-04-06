# Script to execute custom SOQL queries against Salesforce
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

# Function to execute a SOQL query
function Invoke-SOQL {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Query,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxRecords = 2000
    )
    
    # URL encode the query
    $encodedQuery = [Uri]::EscapeDataString($Query)
    $queryUrl = "$salesforceInstanceUrl/services/data/v58.0/query/?q=$encodedQuery"
    
    try {
        $headers = @{
            "Authorization" = "Bearer $salesforceToken"
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-WebRequest -Uri $queryUrl -Headers $headers -Method Get -UseBasicParsing
        $data = $response.Content | ConvertFrom-Json
        
        # Handle pagination if needed
        $allRecords = $data.records
        $nextRecordsUrl = $data.nextRecordsUrl
        
        # If we have more records to fetch and haven't hit our max yet
        while ($nextRecordsUrl -and $allRecords.Count -lt $MaxRecords) {
            $nextUrl = "$salesforceInstanceUrl$nextRecordsUrl"
            $response = Invoke-WebRequest -Uri $nextUrl -Headers $headers -Method Get -UseBasicParsing
            $data = $response.Content | ConvertFrom-Json
            $allRecords += $data.records
            $nextRecordsUrl = $data.nextRecordsUrl
        }
        
        return $allRecords
    }
    catch {
        Write-Error "Error executing SOQL query: $_"
        Write-Error $_.Exception.Message
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd()
            Write-Error "Response body: $responseBody"
        }
        return $null
    }
}

# Initialize query mode
$mode = "manual"

# Provide some example queries
$exampleQueries = @{
    "Account List" = "SELECT Id, Name, Type, Industry FROM Account ORDER BY Name LIMIT 10"
    "Contacts by Account" = "SELECT Id, FirstName, LastName, Email, Account.Name FROM Contact WHERE AccountId != null ORDER BY Account.Name LIMIT 20"
    "Opportunities" = "SELECT Id, Name, StageName, CloseDate, Amount FROM Opportunity ORDER BY CloseDate DESC LIMIT 10"
    "Tasks" = "SELECT Id, Subject, Status, ActivityDate, WhatId, What.Name FROM Task ORDER BY ActivityDate DESC LIMIT 10"
    "Users" = "SELECT Id, Name, Username, IsActive, ProfileId, Profile.Name FROM User ORDER BY Name LIMIT 10"
}

Write-Host "`nHow would you like to query Salesforce?" -ForegroundColor Yellow
Write-Host "1. Choose from examples"
Write-Host "2. Enter custom SOQL query"
Write-Host "3. Exit"

$choice = Read-Host "Enter your choice (1-3)"

switch ($choice) {
    "1" {
        $mode = "examples"
        Write-Host "`nSelect an example query:" -ForegroundColor Yellow
        $menuIndex = 1
        $exampleKeys = @($exampleQueries.Keys)
        
        foreach ($key in $exampleKeys) {
            Write-Host "$menuIndex. $key"
            $menuIndex++
        }
        
        $exampleChoice = Read-Host "Enter your choice (1-$($exampleKeys.Count))"
        $exampleChoice = [int]$exampleChoice - 1
        
        if ($exampleChoice -ge 0 -and $exampleChoice -lt $exampleKeys.Count) {
            $queryToExecute = $exampleQueries[$exampleKeys[$exampleChoice]]
            Write-Host "`nExecuting query: " -ForegroundColor Cyan
            Write-Host $queryToExecute
        }
        else {
            Write-Error "Invalid selection. Exiting."
            exit 1
        }
    }
    "2" {
        $mode = "custom"
        Write-Host "`nEnter your SOQL query:" -ForegroundColor Yellow
        $queryToExecute = Read-Host
    }
    "3" {
        Write-Host "Exiting script."
        exit 0
    }
    default {
        Write-Error "Invalid choice. Exiting."
        exit 1
    }
}

# Execute the query
Write-Host "`nExecuting SOQL query..." -ForegroundColor Cyan
$results = Invoke-SOQL -Query $queryToExecute

if ($results -and $results.Count -gt 0) {
    Write-Host "`nQuery returned $($results.Count) records." -ForegroundColor Green
    
    # Get all unique properties from the results
    $allProperties = @()
    foreach ($record in $results) {
        $allProperties += $record.PSObject.Properties.Name
    }
    $uniqueProperties = $allProperties | Sort-Object -Unique
    
    # Remove common metadata properties to clean up output
    $uniqueProperties = $uniqueProperties | Where-Object { $_ -ne "attributes" }
    
    # Display results in a table format
    $results | Select-Object -Property $uniqueProperties | Format-Table -AutoSize
    
    # Ask if user wants to export to CSV
    Write-Host "`nWould you like to export results to CSV? (y/n)" -ForegroundColor Yellow
    $exportCsv = Read-Host
    
    if ($exportCsv -eq "y") {
        $dateString = Get-Date -Format "yyyyMMdd_HHmmss"
        $csvPath = "SalesforceQuery_$dateString.csv"
        $results | 
            Select-Object -Property $uniqueProperties | 
            Export-Csv -Path $csvPath -NoTypeInformation
        Write-Host "Results exported to $csvPath" -ForegroundColor Green
    }
}
else {
    Write-Host "`nNo results found for your query." -ForegroundColor Yellow
} 