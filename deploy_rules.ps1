# Deploy Firestore Security Rules
# This script deploys the security rules to Firebase

Write-Host "Deploying Firestore security rules..." -ForegroundColor Cyan

# Ensure Firebase CLI is available
try {
    $firebaseVersion = firebase --version
    Write-Host "Using Firebase CLI version: $firebaseVersion" -ForegroundColor Green
}
catch {
    Write-Host "Firebase CLI not found. Please install it using npm install -g firebase-tools" -ForegroundColor Red
    exit 1
}

# Deploy the rules
Write-Host "Deploying security rules from firestore.rules..." -ForegroundColor Cyan
firebase deploy --only firestore:rules

if ($LASTEXITCODE -eq 0) {
    Write-Host "Security rules deployed successfully!" -ForegroundColor Green
    Write-Host "The serviceSubmissions collection should now be accessible for authenticated users." -ForegroundColor Green
}
else {
    Write-Host "Failed to deploy security rules. Please check the error message above." -ForegroundColor Red
} 