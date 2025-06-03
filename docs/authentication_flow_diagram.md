# TwogetherApp Authentication Flow

This diagram illustrates the complete authentication and user management flow in TwogetherApp, from admin-controlled user creation to role-based access control.

```mermaid
flowchart TD
    Start([User Attempts Access]) --> CheckAuth{Authenticated?}
    
    %% Not Authenticated Path
    CheckAuth -->|No| LoginPage[Login Page]
    LoginPage --> EnterCredentials[Enter Email/Password]
    EnterCredentials --> FirebaseAuth[Firebase Authentication]
    FirebaseAuth --> AuthSuccess{Auth Success?}
    AuthSuccess -->|No| AuthError[Show Error Message]
    AuthError --> LoginPage
    
    %% Successful Authentication
    AuthSuccess -->|Yes| GetUserData[Fetch User Data from Firestore]
    GetUserData --> CheckUserExists{User Document Exists?}
    CheckUserExists -->|No| CreateUserDoc[Create Basic User Document]
    CreateUserDoc --> CheckFirstLogin
    CheckUserExists -->|Yes| CheckFirstLogin{First Login?}
    
    %% First Login Flow
    CheckFirstLogin -->|Yes| PasswordChangePage[Change Password Page]
    PasswordChangePage --> NewPassword[Enter New Password]
    NewPassword --> ValidatePassword{Password Valid?}
    ValidatePassword -->|No| PasswordError[Show Password Error]
    PasswordError --> NewPassword
    ValidatePassword -->|Yes| UpdatePassword[Update Firebase Password]
    UpdatePassword --> CompleteFirstLogin[Mark First Login Complete]
    CompleteFirstLogin --> CheckRole
    
    %% Regular Login Flow
    CheckFirstLogin -->|No| CheckRole{Check User Role}
    
    %% Role-Based Routing
    CheckRole -->|Admin| SetupAdminSession[Setup Admin Session]
    CheckRole -->|Reseller| CheckSalesforceId{Has Salesforce ID?}
    CheckRole -->|Unknown| AccessDenied[Access Denied]
    
    %% Admin Flow
    SetupAdminSession --> AdminDashboard[Admin Dashboard]
    AdminDashboard --> AdminFeatures[Admin Features Available:<br/>• User Management<br/>• Opportunity Review<br/>• Proposal Management<br/>• System Settings]
    
    %% Reseller Flow with Salesforce Validation
    CheckSalesforceId -->|No| SalesforceError[Error: Missing Salesforce ID]
    CheckSalesforceId -->|Yes| SetupResellerSession[Setup Reseller Session]
    SetupResellerSession --> CreateConversation[Ensure Default Conversation Exists]
    CreateConversation --> ResellerDashboard[Reseller Dashboard]
    ResellerDashboard --> ResellerFeatures[Reseller Features Available:<br/>• View Opportunities<br/>• Submit Proposals<br/>• Chat with Admin<br/>• Profile Settings]
    
    %% User Creation Process (Admin Only)
    subgraph UserCreation["👨‍💼 User Creation Process"]
        AdminCreateUser[Admin Initiates User Creation]
        AdminCreateUser --> ValidateSalesforceId[Validate Salesforce ID]
        ValidateSalesforceId --> SalesforceValid{Valid SF ID?}
        SalesforceValid -->|No| SalesforceValidationError[Show Validation Error]
        SalesforceValid -->|Yes| CallCloudFunction[Call createUserWithFirestore Function]
        CallCloudFunction --> CreateFirebaseUser[Create Firebase Auth User]
        CreateFirebaseUser --> SetTempPassword[Set Temporary Password: 'twogether2025']
        SetTempPassword --> CreateFirestoreDoc[Create Firestore Document]
        CreateFirestoreDoc --> SetFirstLoginFlag[Set isFirstLogin: true]
        SetFirstLoginFlag --> SyncSalesforceData[Sync Additional Salesforce Data]
        SyncSalesforceData --> UserCreated[User Account Created]
        UserCreated --> NotifyNewUser[Notify User of Account Creation]
    end
    
    %% Session Management
    subgraph SessionMgmt["🔐 Session Management"]
        TokenRefresh[Auto Token Refresh]
        SecureStorage[Encrypted Local Storage]
        FirestoreRules[Firestore Security Rules]
        RoleValidation[Role-Based Access Control]
        SessionExpiry[Session Expiry Handling]
    end
    
    %% Error Handling
    SalesforceError --> ContactAdmin[Contact Administrator]
    AccessDenied --> LoginPage
    
    %% Styling
    classDef startEnd fill:#e1f5fe,stroke:#0277bd,stroke-width:2px
    classDef process fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef decision fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef error fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef admin fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef reseller fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef salesforce fill:#fff8e1,stroke:#f57f17,stroke-width:2px
    
    class Start,UserCreated startEnd
    class LoginPage,GetUserData,UpdatePassword,SetupAdminSession,SetupResellerSession,CreateConversation process
    class CheckAuth,AuthSuccess,CheckUserExists,CheckFirstLogin,CheckRole,ValidatePassword,CheckSalesforceId,SalesforceValid decision
    class AuthError,PasswordError,SalesforceError,AccessDenied,ContactAdmin error
    class AdminDashboard,AdminFeatures admin
    class ResellerDashboard,ResellerFeatures reseller
    class ValidateSalesforceId,SyncSalesforceData,SalesforceValidationError salesforce
```

## Key Authentication Features

### 🔑 **Core Security Principles**
- **Admin-Controlled User Creation**: No self-registration allowed
- **Mandatory Salesforce Integration**: Resellers must have valid Salesforce ID
- **First Login Security**: Forced password change with temporary credentials
- **Role-Based Access Control**: Granular permissions via Firestore rules

### 🏗️ **Technical Implementation**
- **Firebase Authentication**: Core identity management
- **Cloud Functions**: Server-side user creation and management
- **Firestore Security Rules**: Document-level access control
- **Flutter Secure Storage**: Encrypted credential persistence

### 🔄 **User Lifecycle**
1. **Creation**: Admin initiates through management interface
2. **Provisioning**: System validates Salesforce ID and creates accounts
3. **First Access**: User changes temporary password
4. **Role Assignment**: System routes based on admin/reseller role
5. **Session Management**: Automatic token refresh and security validation

### 📋 **Compliance & Audit**
- All user creation events logged with admin attribution
- Password change history tracked for security compliance
- Session activity monitored for unauthorized access detection
- Salesforce synchronization maintains data integrity audit trail 