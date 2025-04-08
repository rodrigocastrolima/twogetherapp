# Script to guide users through obtaining a Firebase service account key
param (
    [string]$OutputPath = "./service-account-key.json"
)

# Set TLS to acceptable version
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-ColorOutput($ForegroundColor) {
    # Save the current color
    $previousForegroundColor = $host.UI.RawUI.ForegroundColor

    # Set the new color
    $host.UI.RawUI.ForegroundColor = $ForegroundColor

    # Write the message
    if ($args) {
        Write-Output $args
    }
    else {
        $input | Write-Output
    }

    # Restore the previous color
    $host.UI.RawUI.ForegroundColor = $previousForegroundColor
}

function Log-Info($message) {
    Write-ColorOutput Blue "[INFO] $message"
}

function Log-Success($message) {
    Write-ColorOutput Green "[SUCCESS] $message"
}

function Log-Warning($message) {
    Write-ColorOutput Yellow "[WARNING] $message"
}

function Log-Error($message) {
    Write-ColorOutput Red "[ERROR] $message"
}

# Display banner
Write-Host @"
===========================================================
     Firebase Service Account Key Generator Assistant
===========================================================
This script will guide you through obtaining a Firebase
service account key, which is necessary for testing Firebase
Cloud Functions using the Node.js test script.
"@

Log-Info "Checking if Firebase CLI is installed..."
try {
    $firebaseVersion = firebase --version
    Log-Success "Firebase CLI found: $firebaseVersion"
}
catch {
    Log-Error "Firebase CLI not found. Please install it using npm:"
    Write-Host "    npm install -g firebase-tools"
    Log-Info "After installing, run 'firebase login' to authenticate."
    exit 1
}

Log-Info "Checking if you're logged in to Firebase..."
try {
    $loginStatus = firebase login:list
    if ($loginStatus -match "No authorized accounts") {
        Log-Error "You are not logged in to Firebase. Please login first:"
        Write-Host "    firebase login"
        exit 1
    }
    Log-Success "You are logged in to Firebase."
}
catch {
    Log-Error "Failed to check Firebase login status: $_"
    exit 1
}

# Display instructions
Log-Info "To get a service account key, follow these steps:"
Write-Host @"

1. Go to the Firebase Console: https://console.firebase.google.com/
2. Select your project
3. Navigate to Project Settings (gear icon) > Service accounts
4. Click on "Generate new private key" button
5. Save the downloaded JSON file
6. Move the file to: $OutputPath

"@

# Ask if user wants to open the Firebase Console
$openConsole = Read-Host "Would you like to open the Firebase Console? (y/n)"
if ($openConsole -eq "y") {
    Start-Process "https://console.firebase.google.com/"
}

Log-Info "Waiting for service account key file..."
$confirmed = $false
while (-not $confirmed) {
    $fileExists = Test-Path $OutputPath
    if (-not $fileExists) {
        $response = Read-Host "Service account key file not found at: $OutputPath. Have you downloaded it yet? (y/n)"
        if ($response -eq "y") {
            $keyPath = Read-Host "Please enter the path to the downloaded service account key file"
            if (Test-Path $keyPath) {
                Copy-Item $keyPath -Destination $OutputPath
                Log-Success "Service account key copied to $OutputPath"
                $confirmed = $true
            }
            else {
                Log-Error "File not found at: $keyPath"
            }
        }
        else {
            Log-Info "Please download the service account key from the Firebase Console."
            Start-Sleep -Seconds 5
        }
    }
    else {
        Log-Success "Service account key found at: $OutputPath"
        $confirmed = $true
    }
}

# Validate JSON format
try {
    Get-Content $OutputPath | ConvertFrom-Json | Out-Null
    Log-Success "Service account key is valid JSON."
}
catch {
    Log-Error "The service account key file is not valid JSON. Please download a new key."
    exit 1
}

# Final instructions
Log-Success "Setup complete! You now have a valid service account key."
Log-Info "You can now run the test script using:"
Write-Host "    node test_firebase_functions.js"

Log-Warning "IMPORTANT: Keep your service account key secure and never commit it to version control."
Log-Info "You may want to add 'service-account-key.json' to your .gitignore file." 