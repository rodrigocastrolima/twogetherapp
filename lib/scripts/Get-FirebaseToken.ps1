# Get-FirebaseToken.ps1
# Script to obtain a Firebase ID token for accessing Firestore
# Usage: ./Get-FirebaseToken.ps1 [-ServiceAccountKeyPath path/to/serviceAccount.json] [-Interactive]

param (
    [string]$ServiceAccountKeyPath = "service-account-key.json",  # Path to Firebase service account key file
    [switch]$Interactive = $false,  # Whether to use interactive login instead of service account
    [string]$ApiKey = "",  # Firebase Web API Key (can be provided directly)
    [string]$ProjectId = "twogetherapp-65678"  # Firebase Project ID
)

# Function to perform interactive login
function Get-FirebaseIdTokenInteractive {
    param (
        [string]$ApiKey
    )
    
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        Write-Host "Firebase Web API Key is required for interactive login." -ForegroundColor Yellow
        $ApiKey = Read-Host "Enter your Firebase Web API Key (found in Project Settings > General)"
    }
    
    Write-Host "Performing interactive login to Firebase..." -ForegroundColor Cyan
    
    # Get admin credentials
    $email = Read-Host "Enter admin email"
    $securePassword = Read-Host "Enter password" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)  # Clear from memory
    
    # Sign in with email/password
    $signInUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$ApiKey"
    
    $signInBody = @{
        email = $email
        password = $password
        returnSecureToken = $true
    } | ConvertTo-Json
    
    try {
        Write-Host "Authenticating with Firebase..." -ForegroundColor Cyan
        $response = Invoke-RestMethod -Uri $signInUrl -Method POST -Body $signInBody -ContentType "application/json"
        
        if ($response.idToken) {
            Write-Host "Successfully logged in as $email" -ForegroundColor Green
            return $response.idToken
        } else {
            Write-Error "Failed to obtain ID token from login response."
            return $null
        }
    }
    catch {
        Write-Error "Authentication failed: $_"
        
        # More specific error handling
        if ($_.Exception.Response.StatusCode -eq 400) {
            Write-Host "Possible causes: Invalid email/password, user doesn't exist, or user is disabled." -ForegroundColor Yellow
        }
        
        return $null
    }
}

# Main script execution
try {
    if ($Interactive) {
        # Use interactive login
        $Global:firebaseToken = Get-FirebaseIdTokenInteractive -ApiKey $ApiKey
        
        if ($Global:firebaseToken) {
            Write-Host "Successfully obtained Firebase ID token via interactive login." -ForegroundColor Green
            Write-Host "Token is available in the `$firebaseToken variable" -ForegroundColor Green
            Write-Host "Token expiration: 1 hour from now" -ForegroundColor Yellow
            return
        } else {
            Write-Error "Failed to obtain Firebase ID token via interactive login."
            exit 1
        }
    }
    
    # If we get here, we're using service account authentication
    
    # Check if service account key file exists
    if (-not (Test-Path $ServiceAccountKeyPath)) {
        Write-Error "Service account key file not found at: $ServiceAccountKeyPath"
        
        # Offer interactive login as alternative
        $useInteractive = Read-Host "Would you like to try interactive login instead? (y/n)"
        if ($useInteractive -eq "y") {
            $Global:firebaseToken = Get-FirebaseIdTokenInteractive -ApiKey $ApiKey
            
            if ($Global:firebaseToken) {
                Write-Host "Successfully obtained Firebase ID token via interactive login." -ForegroundColor Green
                Write-Host "Token is available in the `$firebaseToken variable" -ForegroundColor Green
                Write-Host "Token expiration: 1 hour from now" -ForegroundColor Yellow
                return
            } else {
                Write-Error "Failed to obtain Firebase ID token via interactive login."
                exit 1
            }
        } else {
            Write-Host "You can download your service account key from the Firebase console:" -ForegroundColor Yellow
            Write-Host "1. Go to Project Settings > Service Accounts" -ForegroundColor Yellow
            Write-Host "2. Click 'Generate new private key'" -ForegroundColor Yellow
            Write-Host "3. Save the JSON file and provide the path to this script" -ForegroundColor Yellow
            exit 1
        }
    }

    # Load the service account key
    try {
        $serviceAccount = Get-Content -Path $ServiceAccountKeyPath -Raw | ConvertFrom-Json
        
        # Validate the service account has the necessary fields
        if (-not $serviceAccount.client_email -or -not $serviceAccount.private_key) {
            Write-Error "Invalid service account key file. Missing required fields."
            
            # Offer interactive login as alternative
            $useInteractive = Read-Host "Would you like to try interactive login instead? (y/n)"
            if ($useInteractive -eq "y") {
                $Global:firebaseToken = Get-FirebaseIdTokenInteractive -ApiKey $ApiKey
                
                if ($Global:firebaseToken) {
                    Write-Host "Successfully obtained Firebase ID token via interactive login." -ForegroundColor Green
                    Write-Host "Token is available in the `$firebaseToken variable" -ForegroundColor Green
                    Write-Host "Token expiration: 1 hour from now" -ForegroundColor Yellow
                    return
                } else {
                    Write-Error "Failed to obtain Firebase ID token via interactive login."
                    exit 1
                }
            } else {
                exit 1
            }
        }
        
        Write-Host "Loaded service account for: $($serviceAccount.client_email)" -ForegroundColor Cyan
    } catch {
        Write-Error "Error loading service account key: $_"
        
        # Offer interactive login as alternative
        $useInteractive = Read-Host "Would you like to try interactive login instead? (y/n)"
        if ($useInteractive -eq "y") {
            $Global:firebaseToken = Get-FirebaseIdTokenInteractive -ApiKey $ApiKey
            
            if ($Global:firebaseToken) {
                Write-Host "Successfully obtained Firebase ID token via interactive login." -ForegroundColor Green
                Write-Host "Token is available in the `$firebaseToken variable" -ForegroundColor Green
                Write-Host "Token expiration: 1 hour from now" -ForegroundColor Yellow
                return
            } else {
                Write-Error "Failed to obtain Firebase ID token via interactive login."
                exit 1
            }
        } else {
            exit 1
        }
    }

    # Function to create a JWT for Firebase authentication
    function New-FirebaseJwt {
        param (
            [PSObject]$ServiceAccount
        )
        
        # Import the JWT module (install if not present)
        if (-not (Get-Module -ListAvailable -Name JWT)) {
            Write-Host "JWT PowerShell module not found. Attempting to install..." -ForegroundColor Yellow
            Install-Module -Name JWT -Scope CurrentUser -Force
        }
        
        Import-Module JWT
        
        # Prepare JWT header and payload
        $header = @{
            alg = "RS256"
            typ = "JWT"
            kid = $ServiceAccount.private_key_id
        }
        
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $expiry = $now + 3600 # 1 hour
        
        $payload = @{
            iss = $ServiceAccount.client_email
            sub = $ServiceAccount.client_email
            aud = "https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit"
            iat = $now
            exp = $expiry
            uid = "firebase-auth-script"
        }
        
        # Create the JWT
        $jwt = New-JWT -Header $header -Payload $payload -PrivateKey $ServiceAccount.private_key
        
        return $jwt
    }

    # Function to exchange JWT for Firebase ID token
    function Get-FirebaseIdToken {
        param (
            [string]$Jwt,
            [string]$ProjectId,
            [string]$ApiKey
        )
        
        if ([string]::IsNullOrWhiteSpace($ApiKey)) {
            Write-Host "Firebase Web API Key not found in service account file." -ForegroundColor Yellow
            $ApiKey = Read-Host "Enter your Firebase Web API Key (found in Project Settings > General)"
        }
        
        $url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=$ApiKey"
        
        $body = @{
            token = $Jwt
            returnSecureToken = $true
        } | ConvertTo-Json
        
        try {
            $response = Invoke-RestMethod -Uri $url -Method POST -Body $body -ContentType "application/json"
            return $response.idToken
        }
        catch {
            Write-Error "Error getting Firebase ID token: $_"
            return $null
        }
    }

    # Get the API key (this is a public API key, not a secret)
    $apiKeyToUse = $ApiKey
    if ([string]::IsNullOrWhiteSpace($apiKeyToUse)) {
        $apiKeyToUse = $serviceAccount.api_key
    }
    
    if ([string]::IsNullOrWhiteSpace($apiKeyToUse)) {
        Write-Host "You can find your Web API Key in the Firebase console under Project Settings > General" -ForegroundColor Yellow
        $apiKeyToUse = Read-Host "Enter your Firebase Web API Key"
    }
    
    # Create JWT
    $jwt = New-FirebaseJwt -ServiceAccount $serviceAccount
    
    # Exchange JWT for ID token
    $idToken = Get-FirebaseIdToken -Jwt $jwt -ProjectId $ProjectId -ApiKey $apiKeyToUse
    
    if ($idToken) {
        Write-Host "Successfully obtained Firebase ID token." -ForegroundColor Green
        
        # Store in a global variable for use in other scripts
        $Global:firebaseToken = $idToken
        
        Write-Host "Token is available in the `$firebaseToken variable" -ForegroundColor Green
        Write-Host "Token expiration: 1 hour from now" -ForegroundColor Yellow
    }
    else {
        Write-Error "Failed to obtain Firebase ID token from service account."
        
        # Offer interactive login as fallback
        $useInteractive = Read-Host "Would you like to try interactive login instead? (y/n)"
        if ($useInteractive -eq "y") {
            $Global:firebaseToken = Get-FirebaseIdTokenInteractive -ApiKey $apiKeyToUse
            
            if ($Global:firebaseToken) {
                Write-Host "Successfully obtained Firebase ID token via interactive login." -ForegroundColor Green
                Write-Host "Token is available in the `$firebaseToken variable" -ForegroundColor Green
                Write-Host "Token expiration: 1 hour from now" -ForegroundColor Yellow
            } else {
                Write-Error "Failed to obtain Firebase ID token via interactive login."
                exit 1
            }
        } else {
            exit 1
        }
    }
}
catch {
    Write-Error "An error occurred: $_"
} 