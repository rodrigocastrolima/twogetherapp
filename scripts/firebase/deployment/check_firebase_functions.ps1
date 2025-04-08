# Script to check the status of Firebase Functions deployment
param (
    [switch]$Verbose = $false,
    [switch]$FixIssues = $false
)

# Set TLS to acceptable version
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Define color output functions
function Write-ColorOutput($ForegroundColor) {
    $previousForegroundColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) { Write-Output $args } else { $input | Write-Output }
    $host.UI.RawUI.ForegroundColor = $previousForegroundColor
}

function Log-Info($message) { Write-ColorOutput Blue "[INFO] $message" }
function Log-Success($message) { Write-ColorOutput Green "[SUCCESS] $message" }
function Log-Warning($message) { Write-ColorOutput Yellow "[WARNING] $message" }
function Log-Error($message) { Write-ColorOutput Red "[ERROR] $message" }
function Log-Verbose($message) { if ($Verbose) { Write-ColorOutput Cyan "[VERBOSE] $message" } }

# Display banner
Write-Host @"
===========================================================
       Firebase Functions Deployment Status Checker
===========================================================
This script checks if your Firebase Functions are properly 
deployed and configured for the user creation process.
"@

# Required functions for the user creation process
$requiredFunctions = @(
    "ping",
    "createUser",
    "setUserEnabled",
    "syncUserWithSalesforce"
)

$issues = @()
$functionsList = @()

# Check if Firebase CLI is installed
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

# Check if user is logged in to Firebase
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

# Check for firebase.json file
Log-Info "Checking for firebase.json file..."
if (Test-Path "firebase.json") {
    Log-Success "firebase.json found."
    Log-Verbose "Contents of firebase.json:"
    if ($Verbose) {
        Get-Content "firebase.json" | ForEach-Object { Log-Verbose "  $_" }
    }
}
else {
    Log-Error "firebase.json not found in the current directory."
    $issues += "Missing firebase.json file in the project root."
}

# Check if functions directory exists
Log-Info "Checking for functions directory..."
if (Test-Path "functions") {
    Log-Success "Functions directory found."
    
    # Check for package.json in functions directory
    if (Test-Path "functions/package.json") {
        Log-Success "functions/package.json found."
        Log-Verbose "Checking package.json dependencies..."
        
        try {
            $packageJson = Get-Content "functions/package.json" -Raw | ConvertFrom-Json
            
            # Check for firebase-functions dependency
            if ($packageJson.dependencies.'firebase-functions') {
                Log-Success "firebase-functions dependency found: $($packageJson.dependencies.'firebase-functions')"
            }
            else {
                Log-Warning "firebase-functions dependency not found in package.json"
                $issues += "Missing firebase-functions dependency in functions/package.json"
            }
            
            # Check for firebase-admin dependency
            if ($packageJson.dependencies.'firebase-admin') {
                Log-Success "firebase-admin dependency found: $($packageJson.dependencies.'firebase-admin')"
            }
            else {
                Log-Warning "firebase-admin dependency not found in package.json"
                $issues += "Missing firebase-admin dependency in functions/package.json"
            }
        }
        catch {
            Log-Error "Failed to parse functions/package.json: $_"
            $issues += "Invalid functions/package.json format"
        }
    }
    else {
        Log-Error "functions/package.json not found."
        $issues += "Missing package.json in functions directory"
    }
    
    # Check for src or lib directory in functions
    if (Test-Path "functions/src") {
        Log-Success "functions/src directory found (TypeScript project)."
        
        # Check for createUser function implementation
        $createUserFiles = Get-ChildItem -Path "functions/src" -Recurse -File | Where-Object { $_.Name -match ".*\.ts" } | Select-String -Pattern "createUser" | Select-Object -ExpandProperty Path
        
        if ($createUserFiles.Count -gt 0) {
            Log-Success "Found potential createUser implementation in:"
            $createUserFiles | ForEach-Object { Log-Success "  $_" }
        }
        else {
            Log-Warning "Could not find createUser implementation in functions/src"
            $issues += "Missing createUser implementation in source files"
        }
    }
    elseif (Test-Path "functions/lib") {
        Log-Success "functions/lib directory found (may be compiled JavaScript)."
    }
    elseif (Test-Path "functions/index.js") {
        Log-Success "functions/index.js found (JavaScript project)."
        
        # Check for createUser function implementation
        $content = Get-Content "functions/index.js" -Raw
        if ($content -match "createUser") {
            Log-Success "Found potential createUser implementation in functions/index.js"
        }
        else {
            Log-Warning "Could not find createUser implementation in functions/index.js"
            $issues += "Missing createUser implementation in functions/index.js"
        }
    }
    else {
        Log-Error "Could not find function implementation directory (src, lib, or index.js)"
        $issues += "Missing function implementation files"
    }
}
else {
    Log-Error "Functions directory not found."
    $issues += "Missing functions directory in the project root."
}

# Check deployed functions
Log-Info "Checking deployed Firebase Functions..."
try {
    $functionsListOutput = firebase functions:list --json
    $functionsData = $functionsListOutput | ConvertFrom-Json
    
    if ($functionsData.Count -eq 0) {
        Log-Error "No Firebase Functions are deployed."
        $issues += "No functions are deployed to Firebase"
    }
    else {
        Log-Success "Found $($functionsData.Count) deployed Firebase Functions."
        
        $functionsList = $functionsData | ForEach-Object { $_.name -replace ".*\/functions\/", "" }
        
        Log-Info "Deployed functions:"
        $functionsList | ForEach-Object { Log-Info "  $_" }
        
        # Check for required functions
        foreach ($requiredFunction in $requiredFunctions) {
            if ($functionsList -contains $requiredFunction) {
                Log-Success "Required function '$requiredFunction' is deployed."
            }
            else {
                Log-Error "Required function '$requiredFunction' is NOT deployed."
                $issues += "Required function '$requiredFunction' is not deployed"
            }
        }
    }
}
catch {
    Log-Error "Failed to list Firebase Functions: $_"
    $issues += "Unable to list deployed functions"
}

# Check if Firebase Emulator is running
Log-Info "Checking if Firebase Emulator is running..."
try {
    $emulatorStatus = firebase emulators:exec "echo 'Checking emulator status'" --only functions 2>&1
    if ($emulatorStatus -match "All emulators started") {
        Log-Success "Firebase Emulator is running."
    }
    else {
        Log-Warning "Firebase Emulator is not running. This might be intentional."
        if ($Verbose) {
            Log-Info "You can start the emulator with:"
            Write-Host "    firebase emulators:start --only functions"
        }
    }
}
catch {
    Log-Verbose "Error checking emulator status: $_"
    Log-Warning "Could not determine Firebase Emulator status."
}

# Summary of issues
if ($issues.Count -gt 0) {
    Log-Error "Found $($issues.Count) issues that need to be addressed:"
    $issues | ForEach-Object { Log-Error "  - $_" }
    
    if ($FixIssues) {
        Log-Info "Attempting to fix issues..."
        
        # Check if we need to deploy functions
        $needsDeployment = $false
        foreach ($requiredFunction in $requiredFunctions) {
            if ($functionsList -notcontains $requiredFunction) {
                $needsDeployment = $true
                break
            }
        }
        
        if ($needsDeployment) {
            Log-Info "Deploying Firebase Functions..."
            try {
                # First build if TypeScript project
                if (Test-Path "functions/src") {
                    Log-Info "Building TypeScript functions..."
                    Set-Location functions
                    npm run build
                    Set-Location ..
                }
                
                # Deploy functions
                firebase deploy --only functions
                Log-Success "Firebase Functions deployed successfully."
            }
            catch {
                Log-Error "Failed to deploy Firebase Functions: $_"
            }
        }
    }
    else {
        Log-Info "To fix these issues, try the following steps:"
        
        if ($issues -contains "Missing firebase.json file in the project root.") {
            Log-Info "  - Initialize Firebase in your project: firebase init"
        }
        
        if ($issues -contains "Missing functions directory in the project root." -or 
            $issues -contains "Missing package.json in functions directory") {
            Log-Info "  - Initialize Firebase Functions: firebase init functions"
        }
        
        if ($issues -contains "Missing firebase-functions dependency in functions/package.json" -or 
            $issues -contains "Missing firebase-admin dependency in functions/package.json") {
            Log-Info "  - Install required dependencies:"
            Log-Info "    cd functions"
            Log-Info "    npm install firebase-functions firebase-admin --save"
        }
        
        if ($issues -contains "Missing createUser implementation in source files" -or 
            $issues -contains "Missing createUser implementation in functions/index.js") {
            Log-Info "  - Implement the createUser function in your functions code"
        }
        
        if ($issues -contains "No functions are deployed to Firebase" -or 
            $issues -contains "Required function 'createUser' is not deployed" -or 
            $issues -contains "Required function 'ping' is not deployed") {
            Log-Info "  - Deploy your functions to Firebase:"
            Log-Info "    cd functions"
            Log-Info "    npm run build (if TypeScript project)"
            Log-Info "    firebase deploy --only functions"
        }
        
        Log-Info "Run this script with -FixIssues switch to attempt automatic fixes:"
        Log-Info "  ./check_firebase_functions.ps1 -FixIssues"
    }
}
else {
    Log-Success "No issues found. Firebase Functions appear to be properly deployed and configured."
    Log-Info "You can now proceed with testing the user creation process using:"
    Log-Info "  1. PowerShell script: ./test_user_creation.ps1"
    Log-Info "  2. Node.js script: node test_firebase_functions.js"
}

# Final note
Log-Info "For more verbose output, run this script with the -Verbose switch:"
Log-Info "  ./check_firebase_functions.ps1 -Verbose" 