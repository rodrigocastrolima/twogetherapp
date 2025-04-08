# Explore-SalesforceFields.ps1
# Script to explore Salesforce User metadata and generate field mapping recommendations
# Usage: ./Explore-SalesforceFields.ps1 [-Object User] [-OutputFile fieldMapping.json]

param (
    [string]$Object = "User",  # Default to User object
    [string]$OutputFile = ""   # Optional output file
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

# Get the describe metadata for the specified object
function Get-SalesforceObjectMetadata {
    param (
        [string]$ObjectName
    )

    Write-Host "Fetching metadata for object: $ObjectName" -ForegroundColor Cyan
    $endpoint = "/services/data/v58.0/sobjects/$ObjectName/describe"
    return Invoke-SalesforceApi -Endpoint $endpoint
}

# Main script execution
try {
    # Get the object metadata
    $metadata = Get-SalesforceObjectMetadata -ObjectName $Object
    
    if (-not $metadata) {
        Write-Error "Failed to retrieve metadata for $Object object."
        exit 1
    }
    
    # Display basic object info
    Write-Host "Object: $($metadata.label) ($($metadata.name))" -ForegroundColor Green
    Write-Host "Description: $($metadata.description)" -ForegroundColor Green
    Write-Host "Total fields: $($metadata.fields.Count)" -ForegroundColor Green
    Write-Host ""
    
    # Create a table of selected field information
    $fieldTable = $metadata.fields | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.name
            Label = $_.label
            Type = $_.type
            Length = $_.length
            Required = if ($_.nillable) { "Optional" } else { "Required" }
            Filterable = if ($_.filterable) { "Yes" } else { "No" }
            DefaultValue = $_.defaultValue
            Description = $_.description
        }
    }
    
    # Display the fields
    Write-Host "Fields for $Object object:" -ForegroundColor Yellow
    $fieldTable | Format-Table -Property Name, Label, Type, Length, Required, Filterable
    
    # Generate recommended field mapping (Salesforce to Firebase)
    $recommendedMapping = @{}
    
    # Common User fields that are likely useful
    $commonFields = @(
        "Id", "Username", "Name", "FirstName", "LastName", "Email", "Phone",
        "MobilePhone", "IsActive", "Department", "Title", "CompanyName",
        "ManagerId", "UserRoleId", "ProfileId", "LastLoginDate"
    )
    
    foreach ($field in $metadata.fields) {
        if ($commonFields -contains $field.name) {
            # Convert camelCase to snake_case for Firebase fields
            $firebaseField = $field.name.substring(0,1).toLower() + $field.name.substring(1)
            $recommendedMapping[$field.name] = $firebaseField
        }
    }
    
    # Display the recommended mapping
    Write-Host "`nRecommended Salesforce to Firebase Field Mapping:" -ForegroundColor Yellow
    $recommendedMapping.GetEnumerator() | Sort-Object -Property Name | Format-Table -AutoSize
    
    # Generate Dart constant for field mapping
    $dartCode = "static const Map<String, String> DEFAULT_FIELD_MAPPING = {\n"
    foreach ($key in ($recommendedMapping.Keys | Sort-Object)) {
        $dartCode += "  '$key': '$($recommendedMapping[$key])',`n"
    }
    $dartCode += "};"
    
    Write-Host "`nDart Code for Field Mapping:" -ForegroundColor Yellow
    Write-Host $dartCode
    
    # Output to file if specified
    if ($OutputFile) {
        $mappingObject = [PSCustomObject]@{
            objectName = $Object
            mapping = $recommendedMapping
            dartCode = $dartCode
        }
        
        $mappingJson = ConvertTo-Json -InputObject $mappingObject -Depth 10
        $mappingJson | Out-File -FilePath $OutputFile -Encoding utf8
        
        Write-Host "`nField mapping saved to: $OutputFile" -ForegroundColor Green
    }
    
    # Extra: Display Advanced field details for specific fields
    Write-Host "`nDetailed information for key fields:" -ForegroundColor Yellow
    foreach ($fieldName in @("Id", "Name", "Email", "IsActive")) {
        $field = $metadata.fields | Where-Object { $_.name -eq $fieldName }
        if ($field) {
            Write-Host "`nField: $fieldName" -ForegroundColor Cyan
            $field | Format-List -Property name, label, type, length, nillable, updateable, filterable, picklistValues
        }
    }
    
    Write-Host "`nScript completed successfully." -ForegroundColor Green
    
} catch {
    Write-Error "An error occurred while exploring Salesforce fields: $_"
    exit 1
} 

# Add this to the end of the script or create a new script
Write-Host "`nDetailed information for Revendedor_Retail__c field:" -ForegroundColor Yellow
$revendedorField = $metadata.fields | Where-Object { $_.name -eq "Revendedor_Retail__c" }
if ($revendedorField) {
    $revendedorField | Format-List -Property name, label, type, length, nillable, updateable, filterable
    
    # If it's a picklist field, examine the values
    if ($revendedorField.type -eq "picklist" -and $revendedorField.picklistValues) {
        Write-Host "`nPossible values for Revendedor_Retail__c:" -ForegroundColor Cyan
        $revendedorField.picklistValues | Format-Table -Property value, label, defaultValue
    }
} else {
    Write-Host "Field not found" -ForegroundColor Red
}