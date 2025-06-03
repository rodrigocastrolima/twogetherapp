# TwogetherApp Architecture Diagram

## Figure 4.1: Three-Tier System Architecture

```mermaid
graph TB
    subgraph "Client Tier - Presentation Layer"
        A[Flutter Web Application<br/>Desktop Admin Interface]
        B[Flutter Mobile Application<br/>Reseller Interface]
        C[Shared Widget Library<br/>Responsive Components]
        D[Future Agent Interface<br/>Autonomous Operations]
    end
    
    subgraph "Backend Tier - Service Orchestration Layer"
        subgraph "Firebase Platform"
            E[Firebase Authentication<br/>User Login & Token Management]
            F[Cloud Firestore<br/>Real-time Document Store<br/>Communication & Workflows]
            G[Firebase Storage<br/>Document Uploads<br/>Proposals & Verification]
            H[Cloud Functions<br/>Business Logic<br/>API Orchestration]
            I[Firebase Messaging<br/>Push Notifications]
            J[Firebase Analytics<br/>Usage Monitoring]
        end
    end
    
    subgraph "External Tier - System Integrations"
        subgraph "Salesforce CRM - System of Record"
            K[Salesforce REST API<br/>Commercial Data Management]
            L[Salesforce Objects<br/>Opportunities, Accounts, Proposals]
            M[Salesforce Files API<br/>Document Management]
        end
        
        N[Third-party Analytics<br/>Business Intelligence]
    end
    
    subgraph "Authentication Layers"
        P[OAuth 2.0<br/>Admin Access]
        Q[JWT Proxy Functions<br/>Reseller Access]
    end
    
    %% Client to Backend Connections
    A --> E
    A --> F
    A --> G
    A --> H
    B --> E
    B --> F
    B --> G
    B --> H
    C --> A
    C --> B
    D -.-> H
    
    %% Backend Internal Connections
    E --> F
    H --> I
    H --> J
    
    %% Backend to External Connections
    H --> P
    H --> Q
    P --> K
    Q --> K
    H --> M
    %% Salesforce Internal
    K --> L
    K --> M
    
    %% Analytics Flow
    F --> N
    J --> N
    
    %% Styling
    style A fill:#e1f5fe
    style B fill:#e1f5fe
    style C fill:#f3e5f5
    style D fill:#f9f9f9,stroke:#ccc,stroke-dasharray: 5 5
    style E fill:#fff3e0
    style F fill:#fff3e0
    style G fill:#fff3e0
    style H fill:#fff3e0
    style I fill:#fff3e0
    style J fill:#fff3e0
    style K fill:#e8f5e8
    style L fill:#e8f5e8
    style M fill:#e8f5e8
    style P fill:#ffebee
    style Q fill:#ffebee
    
    classDef clientTier fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef backendTier fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef externalTier fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef authLayer fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef future fill:#f9f9f9,stroke:#757575,stroke-width:2px,stroke-dasharray: 5 5
```

## Architecture Principles Implementation

### 1. Single Source of Truth
- **Salesforce CRM** maintains primary ownership of all commercial data
- **Cloud Firestore** provides local caching and real-time user operations
- **Cloud Functions** orchestrate data synchronization and conflict resolution

### 2. Mobile-First Responsive Architecture
- **Flutter Framework** enables unified codebase for web and mobile platforms
- **Shared Widget Library** ensures UI consistency across all interfaces
- **Responsive Design** adapts to reseller smartphones and admin desktops

### 3. Role-Based Access Control
- **Firebase Authentication** with custom claims for role management
- **OAuth 2.0** provides full admin access to Salesforce data
- **JWT Proxy Functions** enable filtered reseller access through Cloud Functions

### 4. Microservices Architecture
- **Domain-specific Cloud Functions** handle isolated business logic
- **Event-driven triggers** respond to user actions and backend events
- **Independent scalability** for each service component

### 5. API-First Integration
- **RESTful API communication** with standardized contracts
- **Decoupled service boundaries** enable platform extensions
- **Future-ready design** supports autonomous agent integration

## Data Flow Patterns

### Admin Workflow
1. Admin authenticates via **Firebase Auth** with **OAuth 2.0** to Salesforce
2. Admin actions trigger **Cloud Functions** with full CRM access
3. Data synchronizes bidirectionally between **Firestore** and **Salesforce**
4. Real-time updates propagate to all connected clients

### Reseller Workflow
1. Reseller authenticates via **Firebase Auth** with role validation
2. Reseller requests trigger **JWT-based Cloud Functions**
3. Functions access **Salesforce** with service account credentials
4. Filtered data returns to reseller interface via **Firestore** caching

### Communication Flow
1. Messages stored in **Cloud Firestore** with real-time synchronization
2. **Firebase Messaging** delivers push notifications
3. **Cloud Functions** handle notification logic and routing
4. **Analytics** track engagement and system usage

## Future Extension Points

The architecture explicitly supports future autonomous agent integration through:
- **Standardized API contracts** for programmatic access
- **Event-driven Cloud Functions** for automated workflow triggers
- **Flexible authentication** supporting service-to-service communication
- **Modular design** enabling independent agent service deployment 