# Script to get required fields for object creation in Salesforce
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

Write-Host "Successfully obtained token and instance URL." -ForegroundColor Green

# Ask for the object name
Write-Host "Enter the API name of the Salesforce object:" -ForegroundColor Yellow
$objectName = Read-Host

# Get object metadata
Write-Host "Retrieving metadata for $objectName..." -ForegroundColor Cyan

$metadataUrl = "$salesforceInstanceUrl/services/data/v58.0/sobjects/$objectName/describe"

try {
    $headers = @{
        "Authorization" = "Bearer $salesforceToken"
        "Content-Type" = "application/json"
    }
    
    $response = Invoke-WebRequest -Uri $metadataUrl -Headers $headers -Method Get -UseBasicParsing
    $metadata = $response.Content | ConvertFrom-Json
    
    # Generate field requirements analysis
    if ($metadata.fields) {
        # Required fields - not nillable, createable, and not defaulted on create
        $requiredFields = $metadata.fields | Where-Object { 
            $_.createable -eq $true -and 
            $_.nillable -eq $false -and 
            (-not ($_.defaultedOnCreate -eq $true))
        }
        
        # Fields that are createable but optional
        $optionalFields = $metadata.fields | Where-Object { 
            $_.createable -eq $true -and 
            ($_.nillable -eq $true -or $_.defaultedOnCreate -eq $true)
        }
        
        # Fields that have picklist/lookup values
        $picklistFields = $metadata.fields | Where-Object { 
            $_.type -eq 'picklist' -or 
            $_.type -eq 'multipicklist' -or
            $_.type -eq 'reference' 
        }
        
        # Output results
        Write-Host "`n--- Required Fields for Creating $objectName ---" -ForegroundColor Green
        if ($requiredFields.Count -gt 0) {
            $requiredFields | ForEach-Object {
                Write-Host "`nField: $($_.name)" -ForegroundColor Cyan
                Write-Host "Label: $($_.label)"
                Write-Host "Type: $($_.type)"
                
                # If it's a reference field, show what it references
                if ($_.type -eq 'reference' -and $_.referenceTo) {
                    Write-Host "References to: $($_.referenceTo -join ', ')"
                }
                
                # If it's a picklist, show allowed values
                if ($_.type -eq 'picklist' -and $_.picklistValues) {
                    Write-Host "Valid Values:"
                    $_.picklistValues | Where-Object { $_.active -eq $true } | ForEach-Object {
                        Write-Host "  - $($_.value) | Label: $($_.label)"
                    }
                }
            }
        } else {
            Write-Host "No strictly required fields found."
            Write-Host "Note: Some fields might be required by validation rules or triggers."
        }
        
        # Optionally show recommended fields
        Write-Host "`n--- Recommended Fields ---" -ForegroundColor Yellow
        Write-Host "These fields are not strictly required but are often important:" -ForegroundColor Yellow
        
        $recommendedFields = @('Name', 'OwnerId', 'RecordTypeId')
        
        foreach ($fieldName in $recommendedFields) {
            $field = $metadata.fields | Where-Object { $_.name -eq $fieldName }
            if ($field) {
                Write-Host "`nField: $($field.name)" -ForegroundColor Cyan
                Write-Host "Label: $($field.label)"
                Write-Host "Type: $($field.type)"
                Write-Host "Required: $(if ($field.nillable -eq $false -and $field.createable -eq $true) { 'Yes' } else { 'No' })"
            }
        }
        
        # Ask if user wants to export all fields to CSV for reference
        Write-Host "`nWould you like to export all field details to CSV? (y/n)" -ForegroundColor Yellow
        $exportCsv = Read-Host
        
        if ($exportCsv -eq "y") {
            $csvPath = "$objectName-field-requirements.csv"
            $metadata.fields | 
                Select-Object name, label, type, nillable, createable, updateable, defaultedOnCreate, 
                    @{Name='isRequired'; Expression={
                        if ($_.nillable -eq $false -and $_.createable -eq $true -and $_.defaultedOnCreate -ne $true) { 
                            'Required' 
                        } elseif ($_.createable -eq $true) {
                            'Optional'
                        } else {
                            'System Field'
                        }
                    }} |
                Export-Csv -Path $csvPath -NoTypeInformation
            Write-Host "Field requirements exported to $csvPath" -ForegroundColor Green
        }
        
        # Offer to generate a sample JSON for creating a record
        Write-Host "`nWould you like to generate a sample JSON for creating a record? (y/n)" -ForegroundColor Yellow
        $generateJson = Read-Host
        
        if ($generateJson -eq "y") {
            $jsonPath = "$objectName-sample.json"
            $jsonObj = @{}
            
            # Add required fields with placeholder values
            foreach ($field in $requiredFields) {
                $sampleValue = switch ($field.type) {
                    'string' { "Sample $($field.label)" }
                    'textarea' { "Sample text for $($field.label)" }
                    'date' { (Get-Date).ToString("yyyy-MM-dd") }
                    'datetime' { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ") }
                    'boolean' { $true }
                    'double' { 0.0 }
                    'currency' { 0.0 }
                    'int' { 0 }
                    'picklist' { 
                        if ($field.picklistValues -and $field.picklistValues.Count -gt 0) {
                            $field.picklistValues[0].value 
                        } else { 
                            "Unknown" 
                        }
                    }
                    'reference' { "INSERT_VALID_ID_HERE" }
                    default { "PLACEHOLDER_FOR_$($field.type.ToUpper())" }
                }
                $jsonObj[$field.name] = $sampleValue
            }
            
            # Add RecordTypeId if it exists in the object
            $rtField = $metadata.fields | Where-Object { $_.name -eq 'RecordTypeId' }
            if ($rtField) {
                $jsonObj['RecordTypeId'] = "INSERT_RECORD_TYPE_ID_HERE"
            }
            
            # Convert to JSON and write to file
            $jsonObj | ConvertTo-Json -Depth 3 | Out-File -FilePath $jsonPath
            Write-Host "Sample JSON exported to $jsonPath" -ForegroundColor Green
        }
        
    } else {
        Write-Host "No field metadata found for $objectName." -ForegroundColor Red
    }
}
catch {
    Write-Error "Error retrieving object metadata: $_"
    Write-Error $_.Exception.Message
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Error "Response body: $responseBody"
    }
} 