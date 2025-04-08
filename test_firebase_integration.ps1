# Script to check Flutter app's integration with Firebase
param (
    [switch]$FixIssues = $false,
    [switch]$Verbose = $false
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
      Flutter Firebase Integration Test Toolkit
===========================================================
This script checks if your Flutter app is properly 
configured to integrate with Firebase for user creation.
"@

# Required Firebase packages for Flutter
$requiredPackages = @(
    "firebase_core",
    "firebase_auth",
    "cloud_firestore",
    "cloud_functions"
)

$issues = @()

# Function to check if a directory exists
function Test-DirectoryExists($path, $description) {
    Log-Info "Checking for $description at $path..."
    if (Test-Path $path -PathType Container) {
        Log-Success "$description found."
        return $true
    } else {
        Log-Error "$description not found at $path."
        $script:issues += "Missing $description at $path"
        return $false
    }
}

# Function to check if Flutter is installed
function Test-FlutterInstalled() {
    Log-Info "Checking if Flutter is installed..."
    try {
        $flutterVersion = flutter --version
        $flutterVersionLine = ($flutterVersion -split "`n")[0]
        Log-Success "Flutter found: $flutterVersionLine"
        return $true
    } catch {
        Log-Error "Flutter not found in PATH. Please install Flutter or add it to your PATH."
        $script:issues += "Flutter not installed or not in PATH"
        return $false
    }
}

# Function to check if a package is in pubspec.yaml
function Test-PackageInPubspec($packageName) {
    $pubspecContent = Get-Content "pubspec.yaml" -Raw
    if ($pubspecContent -match "\s+$packageName\s*:") {
        return $true
    }
    return $false
}

# Function to extract package version from pubspec.yaml
function Get-PackageVersion($packageName) {
    $pubspecContent = Get-Content "pubspec.yaml" -Raw
    if ($pubspecContent -match "\s+$packageName\s*:\s*\^?([0-9\.]+)") {
        return $matches[1]
    }
    return $null
}

# Check Flutter installation
$flutterInstalled = Test-FlutterInstalled

# Check for Flutter project
if (-not (Test-Path "pubspec.yaml")) {
    Log-Error "pubspec.yaml not found. This doesn't appear to be a Flutter project."
    $issues += "Not a Flutter project (missing pubspec.yaml)"
    exit 1
}

# Check project structure
Log-Info "Checking Flutter project structure..."
$libExists = Test-DirectoryExists "lib" "lib directory"
$androidExists = Test-DirectoryExists "android" "android directory"
$iosExists = Test-DirectoryExists "ios" "iOS directory"
$webExists = Test-DirectoryExists "web" "web directory"

# Check pubspec.yaml for required packages
Log-Info "Checking pubspec.yaml for required Firebase packages..."
$missingPackages = @()
foreach ($package in $requiredPackages) {
    if (Test-PackageInPubspec $package) {
        $version = Get-PackageVersion $package
        Log-Success "Package $package found (version: $version)."
    } else {
        Log-Warning "Package $package not found in pubspec.yaml"
        $missingPackages += $package
        $issues += "Missing Firebase package: $package"
    }
}

# Check for Firebase configuration files
Log-Info "Checking for Firebase configuration files..."

# Check Android Firebase config
if ($androidExists) {
    $androidConfigExists = Test-Path "android/app/google-services.json"
    if ($androidConfigExists) {
        Log-Success "Android Firebase config (google-services.json) found."
        if ($Verbose) {
            try {
                $configContent = Get-Content "android/app/google-services.json" -Raw | ConvertFrom-Json
                Log-Verbose "Firebase project ID: $($configContent.project_info.project_id)"
                Log-Verbose "Firebase storage bucket: $($configContent.project_info.storage_bucket)"
            } catch {
                Log-Warning "Could not parse google-services.json: $_"
            }
        }
    } else {
        Log-Error "Android Firebase config (google-services.json) not found."
        $issues += "Missing Android Firebase configuration (google-services.json)"
    }
    
    # Check android/build.gradle for Firebase dependencies
    $androidBuildGradleExists = Test-Path "android/build.gradle"
    if ($androidBuildGradleExists) {
        $buildGradleContent = Get-Content "android/build.gradle" -Raw
        if ($buildGradleContent -match "com\.google\.gms:google-services") {
            Log-Success "Google Services plugin found in Android build.gradle."
        } else {
            Log-Warning "Google Services plugin not found in Android build.gradle."
            $issues += "Missing Google Services plugin in Android build.gradle"
        }
    }
    
    # Check app/build.gradle for Firebase plugin application
    $appBuildGradleExists = Test-Path "android/app/build.gradle"
    if ($appBuildGradleExists) {
        $appBuildGradleContent = Get-Content "android/app/build.gradle" -Raw
        if ($appBuildGradleContent -match "apply plugin: 'com\.google\.gms\.google-services'") {
            Log-Success "Google Services plugin applied in Android app build.gradle."
        } else {
            Log-Warning "Google Services plugin not applied in Android app build.gradle."
            $issues += "Google Services plugin not applied in Android app/build.gradle"
        }
    }
}

# Check iOS Firebase config
if ($iosExists) {
    $iosConfigExists = Test-Path "ios/Runner/GoogleService-Info.plist"
    if ($iosConfigExists) {
        Log-Success "iOS Firebase config (GoogleService-Info.plist) found."
    } else {
        Log-Error "iOS Firebase config (GoogleService-Info.plist) not found."
        $issues += "Missing iOS Firebase configuration (GoogleService-Info.plist)"
    }
    
    # Check Podfile for Firebase pods
    $podfileExists = Test-Path "ios/Podfile"
    if ($podfileExists) {
        $podfileContent = Get-Content "ios/Podfile" -Raw
        if ($podfileContent -match "platform :ios") {
            Log-Success "iOS Podfile found with platform configuration."
        } else {
            Log-Warning "iOS Podfile might be missing platform configuration."
            $issues += "iOS Podfile missing or incomplete platform configuration"
        }
    }
}

# Check web Firebase config
if ($webExists) {
    $webFirebaseConfig = Test-Path "web/firebase-config.js" -or (Test-Path "web/index.html" -and (Get-Content "web/index.html" -Raw) -match "firebase")
    if ($webFirebaseConfig) {
        Log-Success "Web Firebase configuration found."
    } else {
        Log-Warning "Web Firebase configuration not found."
        $issues += "Missing Web Firebase configuration"
    }
}

# Check for firebase_options.dart file
Log-Info "Checking for Firebase options configuration..."
$firebaseOptionsExists = Test-Path "lib/firebase_options.dart"
if ($firebaseOptionsExists) {
    Log-Success "firebase_options.dart found."
    Log-Verbose "Checking Firebase options implementation..."
    
    $firebaseOptionsContent = Get-Content "lib/firebase_options.dart" -Raw
    if ($firebaseOptionsContent -match "class DefaultFirebaseOptions") {
        Log-Success "DefaultFirebaseOptions class found in firebase_options.dart."
        
        # Extract project information
        if ($firebaseOptionsContent -match "apiKey: '([^']+)'") {
            Log-Verbose "Firebase API Key found."
        }
        
        if ($firebaseOptionsContent -match "appId: '([^']+)'") {
            Log-Verbose "Firebase App ID found."
        }
        
        if ($firebaseOptionsContent -match "projectId: '([^']+)'") {
            $projectId = $matches[1]
            Log-Verbose "Firebase Project ID: $projectId"
        }
    } else {
        Log-Warning "DefaultFirebaseOptions class not found in firebase_options.dart."
        $issues += "Incomplete firebase_options.dart implementation"
    }
} else {
    Log-Error "firebase_options.dart not found. Firebase initialization will fail."
    $issues += "Missing firebase_options.dart file"
}

# Check Firebase initialization in the app
Log-Info "Checking Firebase initialization in Flutter app..."
$mainFileExists = Test-Path "lib/main.dart"
if ($mainFileExists) {
    $mainContent = Get-Content "lib/main.dart" -Raw
    
    if ($mainContent -match "firebase_core" -and $mainContent -match "Firebase.initializeApp") {
        Log-Success "Firebase initialization found in main.dart."
        
        if ($mainContent -match "DefaultFirebaseOptions") {
            Log-Success "DefaultFirebaseOptions being used for Firebase initialization."
        } else {
            Log-Warning "DefaultFirebaseOptions not being used for Firebase initialization."
            $issues += "Firebase initialization not using DefaultFirebaseOptions"
        }
    } else {
        Log-Warning "Firebase initialization not found in main.dart."
        $issues += "Missing Firebase initialization in main.dart"
    }
} else {
    Log-Error "main.dart not found."
    $issues += "Missing main.dart file"
}

# Check for Cloud Functions implementation
Log-Info "Checking for Cloud Functions implementation in the app..."
$functionsImplementation = Get-ChildItem -Path "lib" -Recurse -File | Where-Object { $_.Extension -eq ".dart" } | 
                          Select-String -Pattern "FirebaseFunctions|httpsCallable" -List |
                          Select-Object -ExpandProperty Path

if ($functionsImplementation.Count -gt 0) {
    Log-Success "Found Cloud Functions implementation in Flutter code:"
    $functionsImplementation | ForEach-Object {
        $relativePath = $_ -replace [regex]::Escape((Get-Location)), ""
        Log-Success "  $relativePath"
        
        if ($Verbose) {
            $content = Get-Content $_ -Raw
            if ($content -match "httpsCallable\(['\"]createUser['\"]") {
                Log-Success "  - Found createUser function call."
            }
            if ($content -match "httpsCallable\(['\"]ping['\"]") {
                Log-Success "  - Found ping function call."
            }
            if ($content -match "httpsCallable\(['\"]setUserEnabled['\"]") {
                Log-Success "  - Found setUserEnabled function call."
            }
            if ($content -match "httpsCallable\(['\"]syncUserWithSalesforce['\"]") {
                Log-Success "  - Found syncUserWithSalesforce function call."
            }
        }
    }
} else {
    Log-Warning "Could not find Cloud Functions implementation in Flutter code."
    $issues += "Missing Cloud Functions implementation in Flutter code"
}

# Check for Salesforce integration in Flutter code
Log-Info "Checking for Salesforce integration in Flutter code..."
$salesforceImplementation = Get-ChildItem -Path "lib" -Recurse -File | Where-Object { $_.Extension -eq ".dart" } | 
                           Select-String -Pattern "Salesforce|salesforce" -List |
                           Select-Object -ExpandProperty Path

if ($salesforceImplementation.Count -gt 0) {
    Log-Success "Found potential Salesforce integration in Flutter code:"
    $salesforceImplementation | ForEach-Object {
        $relativePath = $_ -replace [regex]::Escape((Get-Location)), ""
        Log-Success "  $relativePath"
    }
} else {
    Log-Warning "Could not find Salesforce integration in Flutter code."
    $issues += "Missing Salesforce integration in Flutter code"
}

# Summary of issues
if ($issues.Count -gt 0) {
    Log-Error "Found $($issues.Count) issues that need to be addressed:"
    $issues | ForEach-Object { Log-Error "  - $_" }
    
    if ($FixIssues) {
        Log-Info "Attempting to fix issues..."
        
        # Fix missing packages
        if ($missingPackages.Count -gt 0) {
            Log-Info "Adding missing Firebase packages..."
            $packagesArgList = $missingPackages -join " "
            try {
                flutter pub add $packagesArgList
                Log-Success "Added missing packages: $packagesArgList"
            } catch {
                Log-Error "Failed to add packages: $_"
            }
        }
        
        # If firebase_options.dart is missing, suggest running flutterfire configure
        if (-not $firebaseOptionsExists) {
            Log-Info "Checking if FlutterFire CLI is installed..."
            try {
                $flutterFireVersion = flutterfire --version
                Log-Success "FlutterFire CLI found: $flutterFireVersion"
                
                Log-Info "You should run 'flutterfire configure' to set up Firebase properly."
                $runConfigure = Read-Host "Do you want to run 'flutterfire configure' now? (y/n)"
                if ($runConfigure -eq "y") {
                    flutterfire configure
                }
            } catch {
                Log-Error "FlutterFire CLI not found. Install it with: 'dart pub global activate flutterfire_cli'"
                $installFlutterFire = Read-Host "Do you want to install FlutterFire CLI now? (y/n)"
                if ($installFlutterFire -eq "y") {
                    dart pub global activate flutterfire_cli
                    Log-Success "FlutterFire CLI installed. You should now run 'flutterfire configure'."
                }
            }
        }
    } else {
        Log-Info "To fix these issues, try the following steps:"
        
        if ($missingPackages.Count -gt 0) {
            $packagesArgList = $missingPackages -join " "
            Log-Info "  - Add missing Firebase packages: flutter pub add $packagesArgList"
        }
        
        if ($issues -contains "Missing firebase_options.dart file") {
            Log-Info "  - Install FlutterFire CLI: dart pub global activate flutterfire_cli"
            Log-Info "  - Configure Firebase: flutterfire configure"
        }
        
        if ($issues -contains "Missing Firebase initialization in main.dart") {
            Log-Info "  - Add Firebase initialization to main.dart:
    import 'package:firebase_core/firebase_core.dart';
    import 'firebase_options.dart';
    
    void main() async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      runApp(MyApp());
    }
"
        }
        
        if ($issues -contains "Missing Android Firebase configuration (google-services.json)") {
            Log-Info "  - Download google-services.json from Firebase Console and place it in android/app/"
        }
        
        if ($issues -contains "Missing iOS Firebase configuration (GoogleService-Info.plist)") {
            Log-Info "  - Download GoogleService-Info.plist from Firebase Console and place it in ios/Runner/"
        }
        
        Log-Info "Run this script with -FixIssues switch to attempt automatic fixes:"
        Log-Info "  ./test_firebase_integration.ps1 -FixIssues"
    }
} else {
    Log-Success "No issues found. Flutter app appears to be properly configured for Firebase integration."
    Log-Info "You can now proceed with testing the user creation process in your Flutter app."
}

# Final note
Log-Info "For more verbose output, run this script with the -Verbose switch:"
Log-Info "  ./test_firebase_integration.ps1 -Verbose" 