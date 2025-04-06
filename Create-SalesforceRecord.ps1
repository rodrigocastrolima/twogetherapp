# Script to create a new record in Salesforce
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
Write-Host "Enter the API name of the Salesforce object to create:" -ForegroundColor Yellow
$objectName = Read-Host

# Ask if user wants to load from JSON file or input values interactively
Write-Host "`nHow would you like to provide the record data?" -ForegroundColor Yellow
Write-Host "1. Load from JSON file"
Write-Host "2. Input values interactively"
$dataChoice = Read-Host "Enter your choice (1-2)"

$recordData = @{}

if ($dataChoice -eq "1") {
    # Load data from JSON file
    Write-Host "Enter the path to your JSON file:" -ForegroundColor Yellow
    $jsonPath = Read-Host
    
    if (Test-Path $jsonPath) {
        try {
            $jsonContent = Get-Content -Path $jsonPath -Raw
            $recordData = $jsonContent | ConvertFrom-Json -AsHashtable
            
            Write-Host "Successfully loaded JSON data:" -ForegroundColor Green
            $recordData.GetEnumerator() | ForEach-Object {
                Write-Host "$($_.Key): $($_.Value)"
            }
        }
        catch {
            Write-Error "Error loading JSON file: $_"
            exit 1
        }
    }
    else {
        Write-Error "JSON file not found at path: $jsonPath"
        exit 1
    }
}
elseif ($dataChoice -eq "2") {
    # First get metadata to know which fields are required
    Write-Host "`nFetching object metadata to determine required fields..." -ForegroundColor Cyan
    
    $metadataUrl = "$salesforceInstanceUrl/services/data/v58.0/sobjects/$objectName/describe"
    
    try {
        $headers = @{
            "Authorization" = "Bearer $salesforceToken"
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-WebRequest -Uri $metadataUrl -Headers $headers -Method Get -UseBasicParsing
        $metadata = $response.Content | ConvertFrom-Json
        
        # Find required fields
        $requiredFields = $metadata.fields | Where-Object { 
            $_.createable -eq $true -and 
            $_.nillable -eq $false -and 
            ($_.defaultedOnCreate -ne $true) -and
            ($_.name -ne 'Id') # Exclude Id field
        }
        
        # Add recommendedFields that aren't required but important
        $recommendedFields = $metadata.fields | Where-Object { 
            ($_.name -eq 'Name' -or $_.name -eq 'RecordTypeId') -and
            $_.createable -eq $true -and
            ($_.nillable -eq $true)
        }
        
        # Combine fields
        $fieldsToInput = $requiredFields + $recommendedFields
        
        # Sort and deduplicate fields
        $fieldsToInput = $fieldsToInput | Sort-Object -Property name -Unique
        
        # Interactive input for each field
        Write-Host "`nPlease enter values for the following fields:" -ForegroundColor Cyan
        
        foreach ($field in $fieldsToInput) {
            $fieldDescription = "$($field.label) ($($field.name))"
            if ($field.nillable -eq $false) {
                $fieldDescription += " [REQUIRED]"
            }
            
            # Show field type and format information
            $fieldTypeInfo = " [Type: $($field.type)]"
            if ($field.type -eq 'date') {
                $fieldTypeInfo += " [Format: YYYY-MM-DD]"
            }
            elseif ($field.type -eq 'datetime') {
                $fieldTypeInfo += " [Format: YYYY-MM-DDThh:mm:ssZ]"
            }
            
            # Show picklist values if applicable
            if ($field.type -eq 'picklist' -and $field.picklistValues) {
                Write-Host "`nField: $fieldDescription$fieldTypeInfo" -ForegroundColor Yellow
                Write-Host "Valid values for this picklist:" -ForegroundColor Cyan
                $field.picklistValues | Where-Object { $_.active -eq $true } | ForEach-Object {
                    Write-Host "  - $($_.value) | Label: $($_.label)"
                }
                $value = Read-Host "Enter value for $($field.name)"
            }
            elseif ($field.type -eq 'reference' -and $field.referenceTo) {
                Write-Host "`nField: $fieldDescription$fieldTypeInfo" -ForegroundColor Yellow
                Write-Host "References to: $($field.referenceTo -join ', ')" -ForegroundColor Cyan
                $value = Read-Host "Enter valid ID for $($field.name)"
            }
            else {
                Write-Host "`nField: $fieldDescription$fieldTypeInfo" -ForegroundColor Yellow
                $value = Read-Host "Enter value for $($field.name)"
            }
            
            # Convert value to appropriate type
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $typedValue = switch ($field.type) {
                    'boolean' { 
                        if ($value -eq 'true' -or $value -eq 'yes' -or $value -eq '1') { $true } else { $false } 
                    }
                    'double' { [double]$value }
                    'currency' { [double]$value }
                    'int' { [int]$value }
                    default { $value }
                }
                $recordData[$field.name] = $typedValue
            }
        }
    }
    catch {
        Write-Error "Error retrieving metadata: $_"
        exit 1
    }
}
else {
    Write-Error "Invalid choice. Exiting."
    exit 1
}

# Confirm before creating the record
Write-Host "`nAbout to create a record with the following data:" -ForegroundColor Cyan
$recordData.GetEnumerator() | ForEach-Object {
    Write-Host "$($_.Key): $($_.Value)"
}

$confirmation = Read-Host "`nDo you want to proceed? (y/n)"
if ($confirmation -ne "y") {
    Write-Host "Operation cancelled. Exiting."
    exit 0
}

# Create the record
try {
    $createUrl = "$salesforceInstanceUrl/services/data/v58.0/sobjects/$objectName"
    $headers = @{
        "Authorization" = "Bearer $salesforceToken"
        "Content-Type" = "application/json"
    }
    
    # Convert hashtable to JSON
    $jsonBody = $recordData | ConvertTo-Json
    
    Write-Host "`nSending create request to Salesforce..." -ForegroundColor Cyan
    $response = Invoke-WebRequest -Uri $createUrl -Headers $headers -Method Post -Body $jsonBody -UseBasicParsing
    
    $result = $response.Content | ConvertFrom-Json
    
    if ($result.success -eq $true) {
        Write-Host "`nRecord created successfully!" -ForegroundColor Green
        Write-Host "Record ID: $($result.id)"
        
        # Optionally retrieve the newly created record
        Write-Host "`nDo you want to retrieve the full record details? (y/n)" -ForegroundColor Yellow
        $retrieveRecord = Read-Host
        
        if ($retrieveRecord -eq "y") {
            $retrieveUrl = "$salesforceInstanceUrl/services/data/v58.0/sobjects/$objectName/$($result.id)"
            $retrieveResponse = Invoke-WebRequest -Uri $retrieveUrl -Headers $headers -Method Get -UseBasicParsing
            $fullRecord = $retrieveResponse.Content | ConvertFrom-Json
            
            Write-Host "`n--- Full Record Details ---" -ForegroundColor Green
            $fullRecord.PSObject.Properties | ForEach-Object {
                if ($_.Name -ne "attributes") {
                    Write-Host "$($_.Name): $($_.Value)"
                }
            }
        }
    }
    else {
        Write-Error "Failed to create record."
        Write-Host $response.Content
    }
}
catch {
    Write-Error "Error creating record: $_"
    Write-Error $_.Exception.Message
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Error "Response body: $responseBody"
    }
} 