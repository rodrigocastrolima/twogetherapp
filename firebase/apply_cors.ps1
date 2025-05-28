# Apply CORS Configuration to Firebase Storage
# This script applies the CORS configuration to allow web access to files

# Set the project and bucket name
$projectId = "twogetherapp-65678"
$bucketName = "$projectId.firebasestorage.app"

Write-Host "Applying CORS configuration to Firebase Storage bucket: $bucketName" -ForegroundColor Cyan

# Check if gsutil is installed (part of Google Cloud SDK)
try {
    $gsutilVersion = gsutil version
    Write-Host "Found gsutil: $gsutilVersion" -ForegroundColor Green
}
catch {
    Write-Host "Error: gsutil not found. Please install the Google Cloud SDK." -ForegroundColor Red
    Write-Host "Download from: https://cloud.google.com/sdk/docs/install" -ForegroundColor Yellow
    exit 1
}

# Apply the CORS configuration
Write-Host "Applying CORS configuration from cors.json..." -ForegroundColor Cyan
gsutil cors set firebase/cors.json gs://$bucketName

if ($LASTEXITCODE -eq 0) {
    Write-Host "CORS configuration applied successfully!" -ForegroundColor Green
    Write-Host "Web applications should now be able to access files in the Firebase Storage bucket." -ForegroundColor Green
    
    # Display instructions for testing
    Write-Host "`nTo verify this worked, you can use the following steps:" -ForegroundColor Yellow
    Write-Host "1. Refresh your web application" -ForegroundColor Yellow
    Write-Host "2. Check if images load correctly" -ForegroundColor Yellow
    Write-Host "3. If issues persist, clear browser cache and try again" -ForegroundColor Yellow
} else {
    Write-Host "Failed to apply CORS configuration." -ForegroundColor Red
    Write-Host "Please check that you have the correct permissions on the Firebase project." -ForegroundColor Red
} 