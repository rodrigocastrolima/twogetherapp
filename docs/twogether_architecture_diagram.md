# TwogetherApp Architecture Diagram

## Figure 4.1: Three-Tier System Architecture

```mermaid
graph TB
    subgraph Client["Client Tier - Presentation Layer"]
        A["Flutter Web Application<br/>Desktop Admin Interface"]
        B["Flutter Mobile Application<br/>Reseller Interface"]
        C["Shared Widget Library<br/>Responsive Components"]
        D["Future Agent Interface<br/>Autonomous Operations"]
    end
    
    subgraph Backend["Backend Tier - Service Orchestration Layer"]
        subgraph Firebase["Firebase Platform"]
            E["Firebase Authentication<br/>User Login & Token<br/>Management"]
            F["Cloud Firestore<br/>Real-time Document Store<br/>Communication & Workflows"]
            G["Firebase Storage<br/>Document Uploads<br/>Proposals & Verification"]
            H["Cloud Functions<br/>Business Logic<br/>API Orchestration"]
            I["Firebase Messaging<br/>Push Notifications"]
            J["Firebase Analytics<br/>Usage Monitoring"]
        end
    end
    
    subgraph External["External Tier - System Integrations"]
        subgraph Salesforce["Salesforce CRM - System of Record"]
            K["Salesforce REST API<br/>Commercial Data<br/>Management"]
            L["Salesforce Objects<br/>Opportunities, Accounts<br/>Proposals"]
            M["Salesforce Files API<br/>Document Management"]
        end
    end
    
    subgraph Auth["Authentication Layers"]
        P["OAuth 2.0<br/>Admin Access"]
        Q["JWT Proxy Functions<br/>Reseller Access"]
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
    
    %% Salesforce Internal Connections
    K --> L
    K --> M
    
    %% Professional Styling for Thesis
    style A fill:#e3f2fd,stroke:#1976d2,stroke-width:2px,color:#000
    style B fill:#e3f2fd,stroke:#1976d2,stroke-width:2px,color:#000
    style C fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px,color:#000
    style D fill:#f5f5f5,stroke:#616161,stroke-width:2px,stroke-dasharray:5 5,color:#000
    style E fill:#fff8e1,stroke:#f57c00,stroke-width:2px,color:#000
    style F fill:#fff8e1,stroke:#f57c00,stroke-width:2px,color:#000
    style G fill:#fff8e1,stroke:#f57c00,stroke-width:2px,color:#000
    style H fill:#fff8e1,stroke:#f57c00,stroke-width:2px,color:#000
    style I fill:#fff8e1,stroke:#f57c00,stroke-width:2px,color:#000
    style J fill:#fff8e1,stroke:#f57c00,stroke-width:2px,color:#000
    style K fill:#e8f5e8,stroke:#388e3c,stroke-width:2px,color:#000
    style L fill:#e8f5e8,stroke:#388e3c,stroke-width:2px,color:#000
    style M fill:#e8f5e8,stroke:#388e3c,stroke-width:2px,color:#000
    style P fill:#ffebee,stroke:#d32f2f,stroke-width:2px,color:#000
    style Q fill:#ffebee,stroke:#d32f2f,stroke-width:2px,color:#000
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