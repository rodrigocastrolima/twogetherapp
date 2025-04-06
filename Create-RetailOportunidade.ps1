# Script to create a new Retail Oportunidade record in Salesforce
# First, get the Salesforce token using the existing script
$Global:salesforceToken = $null
$Global:salesforceInstanceUrl = $null

# Execute the token script
Write-Host "Getting Salesforce authentication token..." -ForegroundColor Cyan
. .\Get-SalesforceToken.ps1

# Verify we have the token
if (-not $Global:salesforceToken) {
    Write-Error "Failed to obtain Salesforce token. Script will exit."
    exit 1
}

Write-Host "Successfully obtained token and instance URL." -ForegroundColor Green

# Hardcoded object name for this specific script
$objectName = "Oportunidade__c"

# Get record type ID for Retail
Write-Host "Retrieving Record Type ID for Retail..." -ForegroundColor Cyan
try {
    # Build SOQL query to get record types for this object
    $query = "SELECT Id, Name, DeveloperName FROM RecordType WHERE SobjectType = 'Oportunidade__c' AND DeveloperName = 'Retail'"
    $encodedQuery = [Uri]::EscapeDataString($query)
    $queryUrl = "$Global:salesforceInstanceUrl/services/data/v58.0/query/?q=$encodedQuery"

    $headers = @{
        "Authorization" = "Bearer $Global:salesforceToken"
        "Content-Type" = "application/json"
    }
    
    $response = Invoke-WebRequest -Uri $queryUrl -Headers $headers -Method Get -UseBasicParsing
    $data = $response.Content | ConvertFrom-Json
    
    if ($data.records -and $data.records.Count -gt 0) {
        $retailRecordTypeId = $data.records[0].Id
        Write-Host "Found Retail Record Type ID: $retailRecordTypeId" -ForegroundColor Green
    } else {
        Write-Error "No Retail Record Type found for Oportunidade__c"
        exit 1
    }
}
catch {
    Write-Error "Error retrieving Record Type ID: $_"
    exit 1
}

# Get SPECIFIC integration user ID (for OwnerId) - Twogether Retail App
Write-Host "Finding Twogether Retail App Integration User..." -ForegroundColor Cyan
try {
    # Query for the specific Integration User by ID or username
    $specificUserId = "005MI00000T7DFxYAN"  # ID provided by user
    $specificUsername = "integration@twogetherretail.com"  # Username provided by user
    
    $userQuery = "SELECT Id, Name, Username FROM User WHERE Id = '$specificUserId' OR Username = '$specificUsername' LIMIT 1"
    $encodedUserQuery = [Uri]::EscapeDataString($userQuery)
    $userQueryUrl = "$Global:salesforceInstanceUrl/services/data/v58.0/query/?q=$encodedUserQuery"
    
    $userResponse = Invoke-WebRequest -Uri $userQueryUrl -Headers $headers -Method Get -UseBasicParsing
    $userData = $userResponse.Content | ConvertFrom-Json
    
    if ($userData.records -and $userData.records.Count -gt 0) {
        $integrationUserId = $userData.records[0].Id
        Write-Host "Found Twogether Retail App Integration User: $integrationUserId ($($userData.records[0].Name))" -ForegroundColor Green
    } else {
        Write-Error "Could not find the Twogether Retail App integration user. This user is required for creating opportunities."
        exit 1
    }
}
catch {
    Write-Error "Error retrieving Integration User ID: $_"
    exit 1
}

# Get metadata for Oportunidade__c
Write-Host "Retrieving metadata for $objectName..." -ForegroundColor Cyan
$metadataUrl = "$Global:salesforceInstanceUrl/services/data/v58.0/sobjects/$objectName/describe"

try {
    $headers = @{
        "Authorization" = "Bearer $Global:salesforceToken"
        "Content-Type" = "application/json"
    }
    
    $response = Invoke-WebRequest -Uri $metadataUrl -Headers $headers -Method Get -UseBasicParsing
    $metadata = $response.Content | ConvertFrom-Json
}
catch {
    Write-Error "Error retrieving metadata: $_"
    exit 1
}

# Set current date in ISO format (YYYY-MM-DD)
$currentDate = (Get-Date).ToString("yyyy-MM-dd")

# Initialize record data with RecordTypeId and mandatory fields
$recordData = @{
    "RecordTypeId" = $retailRecordTypeId
    "OwnerId" = $integrationUserId  # Set the correct integration user as the owner
    "Data_de_Cria_o_da_Oportunidade__c" = $currentDate
    "Data_da_ltima_actualiza_o_de_Fase__c" = $currentDate
}

Write-Host "`n=== CREATING NEW RETAIL OPORTUNIDADE ===`n" -ForegroundColor Green

# SECTION: Informação da Oportunidade
Write-Host "--- Informação da Oportunidade ---" -ForegroundColor Yellow

# Name (Oportunidade) field
Write-Host "`nField: Oportunidade (Name) [REQUIRED] [Type: string]" -ForegroundColor Cyan
$oportunidadeName = Read-Host "Enter value for Oportunidade"
if (-not [string]::IsNullOrWhiteSpace($oportunidadeName)) {
    $recordData["Name"] = $oportunidadeName
} else {
    Write-Error "Oportunidade name is required. Exiting."
    exit 1
}

# Show automatic date of creation 
Write-Host "`nField: Data de Criação da Oportunidade (Data_de_Cria_o_da_Oportunidade__c) [AUTOMATIC]" -ForegroundColor Cyan
Write-Host "Using current date: $currentDate (Automatic)" -ForegroundColor Green

# NIF field
Write-Host "`nField: NIF (NIF__c) [REQUIRED] [Type: string]" -ForegroundColor Cyan
$nif = Read-Host "Enter value for NIF"
if (-not [string]::IsNullOrWhiteSpace($nif)) {
    $recordData["NIF__c"] = $nif
} else {
    Write-Error "NIF is required. Exiting."
    exit 1
}

# Fase field with picklist
$faseField = $metadata.fields | Where-Object { $_.name -eq "Fase__c" }
if ($faseField -and $faseField.picklistValues) {
    Write-Host "`nField: Fase (Fase__c) [REQUIRED] [Type: picklist]" -ForegroundColor Cyan
    Write-Host "Valid values:" -ForegroundColor Cyan
    $faseField.picklistValues | Where-Object { $_.active -eq $true } | ForEach-Object {
        Write-Host "  - $($_.value) | Label: $($_.label)"
    }
    $fase = Read-Host "Enter EXACT value for Fase (copy from list above)"
    if (-not [string]::IsNullOrWhiteSpace($fase)) {
        $recordData["Fase__c"] = $fase
    } else {
        Write-Error "Fase is required. Exiting."
        exit 1
    }
}

# Tipo de Oportunidade field with picklist
$tipoField = $metadata.fields | Where-Object { $_.name -eq "Tipo_de_Oportunidade__c" }
if ($tipoField -and $tipoField.picklistValues) {
    Write-Host "`nField: Tipo de Oportunidade (Tipo_de_Oportunidade__c) [REQUIRED] [Type: picklist]" -ForegroundColor Cyan
    Write-Host "Valid values:" -ForegroundColor Cyan
    $tipoField.picklistValues | Where-Object { $_.active -eq $true } | ForEach-Object {
        Write-Host "  - $($_.value) | Label: $($_.label)"
    }
    $tipo = Read-Host "Enter EXACT value for Tipo de Oportunidade (copy from list above)"
    if (-not [string]::IsNullOrWhiteSpace($tipo)) {
        $recordData["Tipo_de_Oportunidade__c"] = $tipo
    } else {
        Write-Error "Tipo de Oportunidade is required. Exiting."
        exit 1
    }
}

# SECTION: Twogether Retail
Write-Host "`n--- Twogether Retail ---" -ForegroundColor Yellow

# Segmento de Cliente field with picklist
$segmentoField = $metadata.fields | Where-Object { $_.name -eq "Segmento_de_Cliente__c" }
if ($segmentoField -and $segmentoField.picklistValues) {
    Write-Host "`nField: Segmento de Cliente (Segmento_de_Cliente__c) [REQUIRED] [Type: picklist]" -ForegroundColor Cyan
    Write-Host "Valid values:" -ForegroundColor Cyan
    $segmentoField.picklistValues | Where-Object { $_.active -eq $true } | ForEach-Object {
        Write-Host "  - $($_.value) | Label: $($_.label)"
    }
    $segmento = Read-Host "Enter EXACT value for Segmento de Cliente (copy from list above)"
    if (-not [string]::IsNullOrWhiteSpace($segmento)) {
        $recordData["Segmento_de_Cliente__c"] = $segmento
    } else {
        Write-Error "Segmento de Cliente is required. Exiting."
        exit 1
    }
}

# Solução field with picklist
$solucaoField = $metadata.fields | Where-Object { $_.name -eq "Solu_o__c" }
if ($solucaoField -and $solucaoField.picklistValues) {
    Write-Host "`nField: Solução (Solu_o__c) [REQUIRED] [Type: picklist]" -ForegroundColor Cyan
    Write-Host "Valid values:" -ForegroundColor Cyan
    $solucaoField.picklistValues | Where-Object { $_.active -eq $true } | ForEach-Object {
        Write-Host "  - $($_.value) | Label: $($_.label)"
    }
    $solucao = Read-Host "Enter EXACT value for Solução (copy from list above)"
    if (-not [string]::IsNullOrWhiteSpace($solucao)) {
        $recordData["Solu_o__c"] = $solucao
    } else {
        Write-Error "Solução is required. Exiting."
        exit 1
    }
}

# Agente Retail field
Write-Host "`nField: Agente Retail (Agente_Retail__c) [REQUIRED] [Type: reference]" -ForegroundColor Cyan
Write-Host "References to: User" -ForegroundColor Cyan
Write-Host "Would you like to see a list of recent active users? (y/n)" -ForegroundColor Yellow
$showUsers = Read-Host
                
if ($showUsers -eq "y") {
    $userQuery = "SELECT Id, Name, Username FROM User WHERE IsActive = true ORDER BY LastLoginDate DESC LIMIT 10"
    $encodedUserQuery = [Uri]::EscapeDataString($userQuery)
    $userQueryUrl = "$Global:salesforceInstanceUrl/services/data/v58.0/query/?q=$encodedUserQuery"
                    
    $userResponse = Invoke-WebRequest -Uri $userQueryUrl -Headers $headers -Method Get -UseBasicParsing
    $userData = $userResponse.Content | ConvertFrom-Json
                    
    Write-Host "Recent active users:" -ForegroundColor Cyan
    $userData.records | ForEach-Object {
        Write-Host "  - $($_.Name) | ID: $($_.Id) | Username: $($_.Username)"
    }
}
            
$agenteRetailId = Read-Host "Enter EXACT User ID for Agente Retail (from the list above)"
if (-not [string]::IsNullOrWhiteSpace($agenteRetailId)) {
    $recordData["Agente_Retail__c"] = $agenteRetailId
} else {
    Write-Error "Agente Retail is required. Exiting."
    exit 1
}

# SECTION: Fases
Write-Host "`n--- Fases ---" -ForegroundColor Yellow

# Data de Previsão de Fecho field
Write-Host "`nField: Data de Previsão de Fecho (Data_de_Previs_o_de_Fecho__c) [REQUIRED] [Type: date] [Format: YYYY-MM-DD]" -ForegroundColor Cyan
$previsaoFecho = Read-Host "Enter date for Data de Previsão de Fecho (YYYY-MM-DD)"
if (-not [string]::IsNullOrWhiteSpace($previsaoFecho)) {
    $recordData["Data_de_Previs_o_de_Fecho__c"] = $previsaoFecho
} else {
    Write-Error "Data de Previsão de Fecho is required. Exiting."
    exit 1
}

# Show automatic date of last phase update
Write-Host "`nField: Data da última actualização de Fase (Data_da_ltima_actualiza_o_de_Fase__c) [AUTOMATIC]" -ForegroundColor Cyan
Write-Host "Using current date: $currentDate (Automatic)" -ForegroundColor Green

# Confirm before creating the record
Write-Host "`nAbout to create Oportunidade__c record with the following data:" -ForegroundColor Cyan
$recordData.GetEnumerator() | Sort-Object -Property Key | ForEach-Object {
    Write-Host "$($_.Key): $($_.Value)"
}

$confirmation = Read-Host "`nDo you want to proceed? (y/n)"
if ($confirmation -ne "y") {
    Write-Host "Operation cancelled. Exiting."
    exit 0
}

# Create the record
try {
    $createUrl = "$Global:salesforceInstanceUrl/services/data/v58.0/sobjects/$objectName"
    $headers = @{
        "Authorization" = "Bearer $Global:salesforceToken"
        "Content-Type" = "application/json"
    }
    
    # Convert hashtable to JSON
    $jsonBody = $recordData | ConvertTo-Json
    
    Write-Host "`nSending create request to Salesforce..." -ForegroundColor Cyan
    $response = Invoke-WebRequest -Uri $createUrl -Headers $headers -Method Post -Body $jsonBody -UseBasicParsing
    
    $result = $response.Content | ConvertFrom-Json
    
    if ($result.success -eq $true) {
        Write-Host "`nOportunidade record created successfully!" -ForegroundColor Green
        Write-Host "Record ID: $($result.id)"
        
        # Optionally retrieve the newly created record
        Write-Host "`nDo you want to retrieve the full record details? (y/n)" -ForegroundColor Yellow
        $retrieveRecord = Read-Host
        
        if ($retrieveRecord -eq "y") {
            $retrieveUrl = "$Global:salesforceInstanceUrl/services/data/v58.0/sobjects/$objectName/$($result.id)"
            $retrieveResponse = Invoke-WebRequest -Uri $retrieveUrl -Headers $headers -Method Get -UseBasicParsing
            $fullRecord = $retrieveResponse.Content | ConvertFrom-Json
            
            Write-Host "`n--- Full Record Details ---" -ForegroundColor Green
            $fullRecord.PSObject.Properties | Where-Object { $_.Name -ne "attributes" } | Sort-Object -Property Name | ForEach-Object {
                Write-Host "$($_.Name): $($_.Value)"
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
        
        # Try to parse error JSON for more details
        try {
            $errorJson = $responseBody | ConvertFrom-Json
            foreach ($error in $errorJson) {
                Write-Host "`nError detail: $($error.message)" -ForegroundColor Red
                Write-Host "Error code: $($error.errorCode)" -ForegroundColor Red
                Write-Host "Fields: $($error.fields -join ', ')" -ForegroundColor Red
            }
        } catch {
            # Unable to parse error JSON, just show raw response
        }
    }
} 