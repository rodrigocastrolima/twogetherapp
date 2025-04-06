# Script to list all available Salesforce objects
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
Write-Host "Now retrieving list of Salesforce objects..." -ForegroundColor Cyan

# Define the endpoint for listing objects
$sobjectsUrl = "$salesforceInstanceUrl/services/data/v58.0/sobjects/"

# Make the API request to get the list of objects
try {
    $headers = @{
        "Authorization" = "Bearer $salesforceToken"
        "Content-Type" = "application/json"
    }
    
    $response = Invoke-WebRequest -Uri $sobjectsUrl -Headers $headers -Method Get -UseBasicParsing
    
    # Parse the JSON response
    $data = $response.Content | ConvertFrom-Json
    
    # Check if we have a valid response with sobjects
    if ($data.sobjects) {
        # Extract and sort the object names
        $objectNames = $data.sobjects | Select-Object -Property name | Sort-Object -Property name
        
        # Output the results
        Write-Host "`n--- Available Salesforce Objects ---" -ForegroundColor Green
        $objectNames | ForEach-Object { Write-Host "- $($_.name)" }
        Write-Host "-----------------------------------" -ForegroundColor Green
        Write-Host "`nTotal Objects: $($objectNames.Count)" -ForegroundColor Cyan
        
        # Optionally filter out managed package objects
        $standardObjects = $objectNames | Where-Object { $_.name -notmatch "__" } 
        Write-Host "Standard/Custom Objects: $($standardObjects.Count)" -ForegroundColor Cyan
        
        # Ask if user wants to inspect a specific object
        Write-Host "`nWould you like to get metadata for a specific object? (y/n)" -ForegroundColor Yellow
        $inspectObject = Read-Host
        
        if ($inspectObject -eq "y") {
            Write-Host "Enter the API name of the object:" -ForegroundColor Yellow
            $objectName = Read-Host
            
            # Get object metadata
            Write-Host "Retrieving metadata for $objectName..." -ForegroundColor Cyan
            
            $metadataUrl = "$salesforceInstanceUrl/services/data/v58.0/sobjects/$objectName/describe"
            $metadataResponse = Invoke-WebRequest -Uri $metadataUrl -Headers $headers -Method Get -UseBasicParsing
            $metadata = $metadataResponse.Content | ConvertFrom-Json
            
            # Display object details
            Write-Host "`n--- Object Metadata: $objectName ---" -ForegroundColor Green
            Write-Host "Label: $($metadata.label)"
            Write-Host "API Name: $($metadata.name)"
            Write-Host "Custom Object: $($metadata.custom)"
            Write-Host "Createable: $($metadata.createable)"
            Write-Host "Updateable: $($metadata.updateable)"
            Write-Host "Deletable: $($metadata.deletable)"
            
            # Display fields
            Write-Host "`nFields:" -ForegroundColor Cyan
            $metadata.fields | 
                Select-Object name, label, type, custom, nillable, createable, updateable | 
                Format-Table -AutoSize
                
            # Ask if user wants to export field list to CSV
            Write-Host "`nWould you like to export fields to CSV? (y/n)" -ForegroundColor Yellow
            $exportCsv = Read-Host
            
            if ($exportCsv -eq "y") {
                $csvPath = "$objectName-fields.csv"
                $metadata.fields | 
                    Select-Object name, label, type, custom, nillable, createable, updateable | 
                    Export-Csv -Path $csvPath -NoTypeInformation
                Write-Host "Fields exported to $csvPath" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Error "Response didn't contain the expected 'sobjects' property."
        Write-Host $response.Content
    }
}
catch {
    Write-Error "Error retrieving Salesforce objects: $_"
    Write-Error $_.Exception.Message
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Error "Response body: $responseBody"
    }
} 