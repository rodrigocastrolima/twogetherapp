# Salesforce Dual Authentication Architecture Diagram

## Overview

This diagram illustrates the dual authentication model implemented in TwogetherApp for Salesforce CRM integration. The architecture separates administrative operations from reseller access through two distinct authentication flows, ensuring both operational flexibility and strict data governance.

## Authentication Flows

### Admin Authentication Flow (OAuth 2.0 PKCE)
1. **User Login**: Admin initiates login through TwogetherApp frontend
2. **OAuth Initiation**: Flutter app uses `flutter_web_auth_2` package to start OAuth flow
3. **PKCE Challenge**: Web auth client sends PKCE challenge to Salesforce OAuth endpoint
4. **Authorization Code**: Salesforce returns authorization code after user consent
5. **Token Exchange**: Code + verifier exchanged for access and refresh tokens
6. **Secure Storage**: Tokens stored securely in application session
7. **Direct API Access**: Admin can make direct calls to Salesforce REST API
8. **Full CRM Access**: Complete access to all Salesforce data and operations

### Reseller Authentication Flow (JWT Bearer)
1. **User Login**: Reseller authenticates through Firebase Authentication
2. **Authenticated Request**: Frontend makes authenticated request to Cloud Functions
3. **Credential Loading**: Cloud Function loads RSA private key and consumer credentials from environment variables
4. **JWT Generation**: Creates JWT with required claims (iss, sub, aud, exp)
5. **JWT Signing**: Signs token using RS256 algorithm with private key
6. **Bearer Token Request**: Exchanges JWT for Salesforce access token
7. **Scoped Access**: Cloud Function receives scoped access token
8. **SOQL Queries**: Executes filtered queries based on reseller permissions
9. **Filtered Data**: Returns only data accessible to the specific reseller
10. **Response**: Cloud Function sends filtered response back to frontend

## Integration Patterns

### SOQL Queries
- Opportunity filtering by reseller ID
- Commission aggregation for specific proposals
- Status-based filtering for actionable items

### jsforce Library
- Connection management and pooling
- CRUD operations on Salesforce objects
- File upload and download operations

### ContentDocument API
- File storage in Salesforce
- ContentDocumentLink relationship management
- Document metadata management

## Security Boundaries

### Admin Scope
- Full API access to all Salesforce operations
- All CRUD operations on any record
- User management and system configuration
- Complete file management capabilities

### Reseller Scope
- Access limited to own records only
- Primarily read-only access with limited write operations
- Filtered queries based on Salesforce ID
- Limited file access for assigned proposals only

## Technical Components

### Firebase Components
- **Firebase Authentication**: Identity verification for resellers
- **Cloud Functions**: Server-side JWT generation and API proxying
- **Environment Variables**: Secure storage of RSA keys and credentials

### Salesforce Components
- **OAuth 2.0 Endpoint**: Interactive authentication for admins
- **Token Endpoint**: Token exchange for both authentication flows
- **REST API**: Data access and manipulation
- **CRM Data**: Opportunities, accounts, proposals, and files

### Security Features
- RSA-256 JWT signing
- Environment variable credential storage
- Token scoping and expiration
- Role-based access control
- PKCE for enhanced OAuth security

## Benefits

1. **Separation of Concerns**: Clear distinction between admin and reseller capabilities
2. **Security**: Different authentication methods appropriate for each use case
3. **Scalability**: Server-side token management for reseller operations
4. **Compliance**: Strict data access controls and audit trails
5. **Performance**: Efficient token management and connection pooling 