# TwogetherApp Scripts

This directory contains various scripts used for development, testing, deployment, and integration with external services.

## Directory Structure

- **firebase/** - Scripts related to Firebase operations
  - **testing/** - Scripts for testing Firebase Cloud Functions
  - **deployment/** - Scripts for deploying and verifying Firebase resources

- **salesforce/** - Scripts for Salesforce integration and testing

- **utilities/** - General utility scripts and helpers

## Script Naming Conventions

- Node.js scripts: `.js` or `.cjs` (CommonJS modules)
- PowerShell scripts: `.ps1`
- Dart scripts: `.dart`

## Prerequisites

Most scripts require:
- Node.js 18+ for JavaScript/TypeScript scripts
- PowerShell 5.1+ for PowerShell scripts
- Firebase CLI installed and authenticated
- Service account key stored at `./service-account-key.json`

## Common Usage Patterns

### Testing Firebase Functions

```bash
# Test basic connectivity
node scripts/firebase/testing/test_ping.cjs

# Test user creation
node scripts/firebase/testing/test_create_user.cjs
```

### Salesforce Integration

```bash
# Create a user with Salesforce integration
node scripts/salesforce/salesforce_user_creation.cjs
```

## Deployment Verification

```powershell
# Check if Firebase Functions are properly deployed
./scripts/firebase/deployment/check_firebase_functions.ps1
```

## Notes

- Scripts in this directory are for development and testing
- Production scripts used by the Flutter app are in `lib/scripts/`
- Some scripts may require additional dependencies - see individual script documentation 