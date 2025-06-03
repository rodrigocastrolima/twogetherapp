# TwogetherApp Authentication Flow

This diagram illustrates the complete authentication and user management flow in TwogetherApp, from admin-controlled user creation to role-based access control.

```mermaid
flowchart TD
    A[User Access] --> B{Authenticated?}
    B -->|No| C[Login Page]
    C --> D[Enter Credentials]
    D --> E[Firebase Auth]
    E --> F{First Login?}
    
    F -->|Yes| G[Change Password]
    G --> H[Mark Complete]
    H --> I{Check Role}
    
    F -->|No| I{Check Role}
    
    I -->|Admin| J[Admin Dashboard]
    I -->|Reseller| K{Has Salesforce ID?}
    I -->|Unknown| L[Access Denied]
    
    K -->|Yes| M[Reseller Dashboard]
    K -->|No| N[Contact Admin]
    
    %% User Creation (Simplified)
    subgraph UC[User Creation]
        O[Admin Creates User]
        P[Validate Salesforce ID]
        Q[Create Account]
        R[Set Temp Password]
    end
    
    O --> P --> Q --> R
    
    %% Styling - Professional Grayscale
    style A fill:#f8f9fa,stroke:#495057,stroke-width:2px
    style J fill:#e9ecef,stroke:#495057,stroke-width:2px
    style M fill:#e9ecef,stroke:#495057,stroke-width:2px
    style UC fill:#dee2e6,stroke:#495057,stroke-width:2px
    style L fill:#ced4da,stroke:#343a40,stroke-width:2px
    style N fill:#ced4da,stroke:#343a40,stroke-width:2px
    
    style B fill:#f1f3f4,stroke:#6c757d,stroke-width:1px
    style F fill:#f1f3f4,stroke:#6c757d,stroke-width:1px
    style I fill:#f1f3f4,stroke:#6c757d,stroke-width:1px
    style K fill:#f1f3f4,stroke:#6c757d,stroke-width:1px
    
    style C fill:#ffffff,stroke:#212529,stroke-width:1px
    style D fill:#ffffff,stroke:#212529,stroke-width:1px
    style E fill:#ffffff,stroke:#212529,stroke-width:1px
    style G fill:#ffffff,stroke:#212529,stroke-width:1px
    style H fill:#ffffff,stroke:#212529,stroke-width:1px
    style O fill:#ffffff,stroke:#212529,stroke-width:1px
    style P fill:#ffffff,stroke:#212529,stroke-width:1px
    style Q fill:#ffffff,stroke:#212529,stroke-width:1px
    style R fill:#ffffff,stroke:#212529,stroke-width:1px
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