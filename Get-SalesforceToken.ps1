# Script to fetch Salesforce Access Token and Instance URL from Firebase Function
# and store them in the calling PowerShell scope variables ($salesforceToken, $salesforceInstanceUrl).

# Configuration
$functionUrl = "https://us-central1-twogetherapp-65678.cloudfunctions.net/getSalesforceAccessToken"
$instanceUrlFromConfig = "https://ldfgrupo.my.salesforce.com" # Fallback if function doesn't return it

# It's generally safe to just overwrite variables in the parent scope,
# so removing the Remove-Variable calls.

Write-Host "Attempting to call Firebase Function: $functionUrl ..." -ForegroundColor Cyan

try {
    # Call the function
    $response = Invoke-WebRequest -Uri $functionUrl -Method POST -Headers @{"Content-Type"="application/json"} -Body '{"data": {}}' -UseBasicParsing

    # Check HTTP status code (optional but good practice)
    if ($response.StatusCode -ne 200) {
        Write-Error "Function call failed with HTTP Status Code: $($response.StatusCode)"
        Write-Error "Response Content: $($response.Content)"
        return # Stop script execution
    }

    # Parse the JSON response content
    # Firebase callable functions wrap the actual return value in a 'result' property
    $jsonResponse = $response.Content | ConvertFrom-Json

    # Check if the expected 'result' structure exists and has the token/url
    if ($jsonResponse -and $jsonResponse.PSObject.Properties.Name -contains 'result' `
        -and $jsonResponse.result -and $jsonResponse.result.PSObject.Properties.Name -contains 'access_token' `
        -and $jsonResponse.result.PSObject.Properties.Name -contains 'instance_url') {

        # Extract values
        $accessToken = $jsonResponse.result.access_token
        $instanceUrl = $jsonResponse.result.instance_url

        # Validate that we got non-empty values
        if ([string]::IsNullOrWhiteSpace($accessToken) -or [string]::IsNullOrWhiteSpace($instanceUrl)) {
             Write-Error "Function response was successful, but access_token or instance_url was empty or null."
             Write-Error "Response Content: $($response.Content)"
             return
        }

        # Store in the parent/calling scope variables using Set-Variable
        Set-Variable -Scope 1 -Name 'salesforceToken' -Value $accessToken -Force
        Set-Variable -Scope 1 -Name 'salesforceInstanceUrl' -Value $instanceUrl -Force

        # Retrieve the set variables to display confirmation (accessing them directly now works)
        $tokenFromScope = Get-Variable -Name 'salesforceToken' -Scope 1 -ValueOnly
        $instanceUrlFromScope = Get-Variable -Name 'salesforceInstanceUrl' -Scope 1 -ValueOnly

        Write-Host "Successfully obtained token and instance URL." -ForegroundColor Green
        Write-Host "Instance URL: $instanceUrlFromScope"
        Write-Host "Access Token: $($tokenFromScope.Substring(0, [System.Math]::Min($tokenFromScope.Length, 10)))...." # Show first few chars safely
        Write-Host "\nVariables `$salesforceToken` and `$salesforceInstanceUrl` are now set for this session." -ForegroundColor Yellow

    } else {
        # Handle cases where the 'result' structure or nested properties are missing
        Write-Error "Function call seemed successful (HTTP 200), but the response format was unexpected."
        Write-Error "Expected format: {'result': {'access_token': '...', 'instance_url': '...'}}"
        Write-Error "Actual Response Content: $($response.Content)"
        return
    }

} catch {
    Write-Error "An error occurred while trying to get the Salesforce token:"
    Write-Error "Error Message: $($_.Exception.Message)"
    # You might want to log the full response content on error too
    if ($response) {
        Write-Error "Response Content (if available): $($response.Content)"
    }
}