# Script to fetch Salesforce field API names for a given SObject.
# It directly authenticates with Salesforce using JWT Bearer Flow.

param(
    [Parameter(Mandatory=$true)]
    [string]$ObjectName # Salesforce API Name of the object (e.g., Account, Proposta__c)
)

# --- Hardcoded Salesforce Credentials (REMOVE AFTER USE) ---
$privateKeyPem = @"
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDI5faWzetIZTsj
74D39O/H+uVKmV/yJFrbfG2wFAPFMFhB/C4pA7wQHTx+NPk+I3HOd48ZCj/sy5tp
RqaVYD76U+lZ/HYS8G5ziyuPmWnHaAgUM3N+eo4cgRn1CYEyxSwZtS9y8ZMqZT6X
CWXwlc8wW/OWIzazz6HajQf0ZmPM0hLEa85eLcUe6msLMT/FGdk3fw9va3Sa9Uvy
f+TtolRiIpF9kKedoqLoJ7vR69WoTxF83rqNdI3n5M0UDRLQn+0LmT9IEday8wCh
XxgD5mvcK1/GhZppYeDB5BJfuEF/UNgZuFEDZ7qbiS4zZd3d0gR6t3wVqJ7/ZAy0
TeyRhfQ7AgMBAAECggEADJf2/0tlSv3v2SWz1fvxnTSFc7dtpAZAiq7pSVuOshc3
vtsus+HI6IiMpocAvEVRr55ENLzHds17ifvt0WbLcHHRmG7Jolkoqjhvd3y6M2Io
HTU2w/KtrDV6d14sTlfh4CBliMddug9+I4WycV/lDMkEkOmye08f6gQ+9o28mP8b
bYkQXPIAZW5OZr8fls3zZzEbbnZmTVfoZKbUlmBqrgPDMZirEXwMQ/R4wjjvfBPi
ol7AFOfONg5L5Sj2rzjUTyvvI7TRmjCyBHYOMzDzFAp4PLPkvcgxx3RBtEUNA1D6
PekWZ1N67cCsVKtleiiZs/r5tR1uD49as7mTQcwZ4QKBgQD3zLAz+0tpiIH6B0rm
pRCihClHA0QLIwzD1dJaS8p52hWGEt6oXITeoKgdSPC5drP7nqY6de880GyL2wT1
2vV1PjEd5J8ybmjTZNzTOqQZICKD+S+yItlxLK3eS/0Mjh5DOm3xxdcBZYllMmjQ
j2kms0Vop+7g6HFoS9M0qZyQmQKBgQDPi++mVP4MShfNDGLdSWw5o15zOQg5wKi9
T3L6oax9NoSTKCdM1WMy9wh3wDonVEX5i0+5URZZAVNsAODrQgDGLKRAiCTYx4Da
N3dCqTrPnpRsMEfXZmWRYOJh6B5UTqr2XRSDkeitBw7FTlhOCGaGXLScMPrCfydp
+u74Evcr8wKBgQDDWzCy2nN6kK7/wc4QBaQWq6CrJmz3ZruCjMjYfRX0eLUtTSUS
kFYD+Z5v7/gwDuAYB9w/DIj+Zcadf57qgKOwucYZLgs/xAGKXuMk9/80+7uaVdJ/
WrAYZEPyk++8fTJoh+DzkahOppDqIhK2EcmxQ/X9ax+NWlNGCTlKNEmFSQKBgBmJ
nnNZAemBNGyGmaOg5TAyaezDl7+DdT/WBs/QFOlTS/zPdAaAOzSKMQCLJpywQevy
uFyVHarV/u3LLeHEvVOlKpDGL8J8yd4P9Ry+tf3WBW1Kg4x9jQHWagSiCxlUlLS7
v0pxKbAgrjCY80Smw/bEcXTGkhRckPz5Y24i50cBAoGAH2rR6CrP8VrbASBznlZR
nG6OdGobipwixhd/Tsfk2btnoMzd3JDjBZ+lV+Euk8ly/yH/nlj2qqpUPIwxeP/b
OuQiu2bYNtJbNLczJy7Kpty6Gs8Xd5nMiLQ/pwd/gSw7Bu8q5h6Xwl2++kDm78BW
b6q2Af1snitBZO0xbv6mOtA=
-----END PRIVATE KEY-----
"@
$consumerKey = "3MVG9T46ZAw5GTfWlGzpUr1bL14rAr48fglmDfgf4oWyIBerrrJBQz21SWPWmYoRGJqBzULovmWZ2ROgCyixB"
$salesforceUsername = "integration@twogetherretail.com"

$tokenEndpoint = "https://login.salesforce.com/services/oauth2/token"
$salesforceApiVersion = "v59.0" # Use a recent API version

# --- Global Variables for Token/URL ---
$Global:salesforceToken = $null
$Global:salesforceInstanceUrl = $null

# --- Helper function for Base64 URL encoding ---
function ConvertTo-Base64UrlString {
    param([byte[]]$bytes)
    $base64 = [System.Convert]::ToBase64String($bytes)
    return $base64.TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

# --- Step 1: Authenticate directly with Salesforce using JWT ---
Write-Host "Attempting direct Salesforce authentication using JWT..." -ForegroundColor Cyan

try {
    # 1.1 Create JWT Header
    $header = @{ alg = "RS256"; typ = "JWT" } | ConvertTo-Json -Compress
    $encodedHeader = ConvertTo-Base64UrlString -bytes ([System.Text.Encoding]::UTF8.GetBytes($header))

    # 1.2 Create JWT Claim Set (Payload)
    $issuedAt = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $expirationTime = $issuedAt + (3 * 60) # 3 minutes validity
    $claimSet = @{
        iss = $consumerKey
        sub = $salesforceUsername
        aud = $tokenEndpoint # Audience is often the token endpoint for JWT Bearer
        exp = $expirationTime
    } | ConvertTo-Json -Compress
    $encodedClaimSet = ConvertTo-Base64UrlString -bytes ([System.Text.Encoding]::UTF8.GetBytes($claimSet))

    # 1.3 Prepare data for signing
    $unsignedToken = "$encodedHeader.$encodedClaimSet"
    $bytesToSign = [System.Text.Encoding]::UTF8.GetBytes($unsignedToken)

    # 1.4 Load Private Key and Sign
    # Remove header/footer and whitespace, then decode from Base64
    $keyContent = $privateKeyPem -replace "-----(BEGIN|END) PRIVATE KEY-----" -replace "\s"
    $keyBytes = [System.Convert]::FromBase64String($keyContent)

    # Attempt to use CNG (Cryptography Next Generation) which might support PKCS#8
    try {
        Write-Verbose "Attempting to import key using CNGKey..."
        $cngKey = [System.Security.Cryptography.CngKey]::Import($keyBytes, [System.Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob)
        $rsaCng = New-Object System.Security.Cryptography.RSACng($cngKey)

        # Sign the data using RSA-SHA256 with Pkcs1 padding
        Write-Verbose "Signing data using RSACng..."
        $signatureBytes = $rsaCng.SignData($bytesToSign, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $encodedSignature = ConvertTo-Base64UrlString -bytes $signatureBytes
        Write-Verbose "CNG Key import and signing successful."
    } catch {
        Write-Error "Failed to import/sign using CNG: $($_.Exception.Message)"
        Write-Error "This PowerShell version might not support importing PKCS#8 keys directly. Consider using PowerShell 7+ or converting the key manually."
        # Optional: Add more detailed fallback or error logging here if needed
        # For example, checking the .NET version: [System.Environment]::Version
        exit 1
    }

    # 1.5 Assemble the final JWT
    $jwtAssertion = "$unsignedToken.$encodedSignature"

    # 1.6 Request the Access Token
    Write-Host "Requesting Access Token from $tokenEndpoint..." -ForegroundColor Cyan
    $postParams = @{
        grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer"
        assertion = $jwtAssertion
    }

    $tokenResponse = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $postParams

    # 1.7 Process Token Response
    if ($tokenResponse -and $tokenResponse.access_token -and $tokenResponse.instance_url) {
        $Global:salesforceToken = $tokenResponse.access_token
        $Global:salesforceInstanceUrl = $tokenResponse.instance_url
        Write-Host "Successfully obtained token and instance URL via direct JWT auth." -ForegroundColor Green
    } else {
        Write-Error "Direct Salesforce JWT authentication failed or response format was unexpected."
        Write-Error "Response: $($tokenResponse | ConvertTo-Json -Depth 5)" # Log response
        exit 1
    }

} catch {
    Write-Error "An error occurred during direct Salesforce JWT authentication:"
    Write-Error "Error Message: $($_.Exception.Message)"
    # Check if the error response is available from Invoke-RestMethod
    if ($_.Exception.Response) {
        $errorResponseStream = $_.Exception.Response.GetResponseStream()
        $streamReader = New-Object System.IO.StreamReader($errorResponseStream)
        $errorBody = $streamReader.ReadToEnd()
        $streamReader.Close()
        Write-Error "API Error Status Code: $($_.Exception.Response.StatusCode)"
        Write-Error "API Error Response Body: $errorBody"
    } else {
        Write-Error "Full Exception: $($_.Exception)"
    }
    exit 1
}

# --- Step 2: Call Salesforce Describe API (remains the same) ---
Write-Host "\nFetching field descriptions for object '$ObjectName' from Salesforce..." -ForegroundColor Cyan

$describeUrl = "$($Global:salesforceInstanceUrl)/services/data/$salesforceApiVersion/sobjects/$ObjectName/describe"
$headers = @{
    "Authorization" = "Bearer $($Global:salesforceToken)"
    "Content-Type" = "application/json"
}

try {
    $describeResponse = Invoke-RestMethod -Uri $describeUrl -Method Get -Headers $headers

    if ($describeResponse -and $describeResponse.fields) {
        Write-Host "\nSuccessfully fetched fields for '$ObjectName'. API Names:" -ForegroundColor Green
        $fieldNames = $describeResponse.fields | Select-Object -ExpandProperty name
        $fieldNames
        Write-Host "\nFound $($fieldNames.Count) fields." -ForegroundColor Yellow
    } else {
        Write-Error "Salesforce Describe API call seemed successful, but the response format was unexpected or contained no fields."
        Write-Error "URL Called: $describeUrl"
        exit 1
    }
} catch {
    Write-Error "An error occurred while calling the Salesforce Describe API for object '$ObjectName':"
    Write-Error "URL Called: $describeUrl"
    if ($_.Exception.Response) {
        $errorResponseStream = $_.Exception.Response.GetResponseStream()
        $streamReader = New-Object System.IO.StreamReader($errorResponseStream)
        $errorBody = $streamReader.ReadToEnd()
        $streamReader.Close()
        Write-Error "API Error Status Code: $($_.Exception.Response.StatusCode)"
        Write-Error "API Error Response Body: $errorBody"
    } else {
        Write-Error "Error Message: $($_.Exception.Message)"
    }
    exit 1
}

Write-Host "\nScript finished." -ForegroundColor Green 