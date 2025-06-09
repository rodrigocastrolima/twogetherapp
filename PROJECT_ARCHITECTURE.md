## STEP 1 — Feature & Module Catalogue

### Auth
*   **Directory / main file(s):** `lib/features/auth/`, `lib/features/auth/data/repositories/firebase_auth_repository.dart`, `lib/features/auth/data/services/firebase_functions_service.dart`
*   **One-sentence purpose:** Manages user authentication (sign-in, sign-out, registration, session management) and stores user profile information including roles.
*   **Key external services used:** Firebase Authentication, Cloud Firestore (for user profiles/roles), Firebase Cloud Functions (for privileged operations like user creation/deletion).

### User Management
*   **Directory / main file(s):** `lib/features/user_management/`, `lib/features/user_management/presentation/pages/user_management_page.dart`, `lib/features/user_management/presentation/providers/user_creation_provider.dart`
*   **One-sentence purpose:** Allows administrators to list, view details of, and create new users, integrating with both Firebase for authentication/user data and Salesforce for initial user data retrieval and linking.
*   **Key external services used:** Firebase Authentication, Cloud Firestore, Firebase Cloud Functions, Salesforce API.

### Salesforce Integration
*   **Directory / main file(s):** `lib/features/salesforce/`, `lib/features/salesforce/data/services/salesforce_connection_service.dart`, `lib/features/salesforce/data/services/salesforce_user_sync_service.dart`
*   **One-sentence purpose:** Manages connection, authentication (OAuth), and data exchange with the Salesforce API, primarily for retrieving user information and other Salesforce records, and syncing relevant data to Firebase.
*   **Key external services used:** Salesforce REST API (v58.0), uses an underlying OAuth service for authentication.

### Proposal Management (CPE)
*   **Directory / main file(s):** `lib/features/proposal/`, `lib/features/proposal/presentation/pages/admin_salesforce_proposal_detail_page.dart`, `lib/features/proposal/presentation/pages/proposal_creation_page.dart`, `lib/features/proposal/presentation/pages/admin_cpe_proposta_detail_page.dart`
*   **One-sentence purpose:** Manages Customer Premises Equipment (CPE) proposals with complex approval workflows, document management, and integration with Salesforce SObjects for proposal lifecycle management from creation to acceptance with automated document uploads.
*   **Key external services used:** Firebase Cloud Functions, Salesforce REST API (Proposta_CPE__c SObject), Firebase Storage (for proposal documents), Cloud Firestore (for proposal state management).

### Provider/Partner Management
*   **Directory / main file(s):** `lib/features/providers/`, `lib/features/providers/presentation/pages/admin_provider_list_page.dart`, `lib/features/providers/presentation/pages/reseller_provider_list_page.dart`, `lib/features/providers/presentation/pages/create_provider_page.dart`, `lib/features/providers/presentation/pages/admin_provider_files_page.dart`
*   **One-sentence purpose:** Enables management of energy provider partnerships with role-based access allowing administrators to create and manage providers while resellers can view provider information and access shared files and documentation.
*   **Key external services used:** Cloud Firestore (for provider data and file metadata), Firebase Storage (for provider documents and files), Firebase Authentication (for role-based access control).

### Service Submissions
*   **Directory / main file(s):** `lib/features/services/`, `lib/features/services/data/repositories/service_submission_repository.dart`
*   **One-sentence purpose:** Enables users (resellers) to submit service requests/proposals, including metadata and file attachments, which are stored in Firestore and Firebase Storage respectively.
*   **Key external services used:** Cloud Firestore (for submission metadata), Firebase Storage (for attachments).

### Notification System
*   **Directory / main file(s):** `lib/features/notifications/`, `lib/features/notifications/data/repositories/notification_repository.dart`, `lib/features/notifications/presentation/providers/notification_provider.dart`, `lib/features/notifications/presentation/widgets/notification_overlay_manager.dart`, `functions/src/notifications.ts`
*   **One-sentence purpose:** Provides comprehensive push notification system with Firebase Cloud Messaging integration, real-time notification overlay management, user-specific unread tracking, and automated notifications for proposal status changes and chat messages.
*   **Key external services used:** Firebase Cloud Messaging (for push notifications), Cloud Firestore (for notification persistence), Firebase Cloud Functions (for automated notification triggers), Flutter Local Notifications (for foreground display).

### Commission & Revenue Analytics
*   **Directory / main file(s):** `functions/src/commissionFunctions.ts`, `functions/src/getResellerDashboardStats.ts`, `lib/features/profile/presentation/controllers/profile_controller.dart`
*   **One-sentence purpose:** Calculates and tracks reseller commissions and revenue with real-time dashboard analytics, integrating Salesforce opportunity data with Firebase for performance metrics and financial reporting.
*   **Key external services used:** Firebase Cloud Functions (for commission calculations), Salesforce REST API (for opportunity and revenue data), Cloud Firestore (for analytics storage and caching).

### Settings & Profile
*   **Directory / main file(s):** `lib/features/settings/presentation/pages/settings_page.dart`, `lib/features/settings/presentation/pages/profile_page.dart`
*   **One-sentence purpose:** Allows users to manage application preferences (like theme), view their profile information, and perform account actions like logout and password change.
*   **Key external services used:** Firebase Authentication (for logout, password reset), Cloud Firestore (for user profile data), local theme provider.

### User Profile & Revenue
*   **Directory / main file(s):** `lib/features/profile/`, `lib/features/profile/presentation/controllers/profile_controller.dart`
*   **One-sentence purpose:** Provides detailed user profile information and allows users (likely resellers) to view their revenue/commission data with filtering capabilities.
*   **Key external services used:** Likely Cloud Firestore (via a repository) to fetch detailed profile and revenue data.

### Opportunity Management (Salesforce)
*   **Directory / main file(s):** `lib/features/opportunity/`, `lib/features/opportunity/data/services/opportunity_service.dart`, `lib/features/opportunity/presentation/pages/admin_opportunity_page.dart`
*   **One-sentence purpose:** Enables viewing, creating, updating, deleting, and managing Salesforce Opportunities (including file attachments and activation cycles) via Firebase Cloud Functions.
*   **Key external services used:** Firebase Cloud Functions (as an intermediary), Salesforce REST API (accessed via Cloud Functions).

### Reseller Salesforce Access (JWT)
*   **Directory / main file(s):** `functions/src/downloadFileForReseller.ts`, `functions/src/getResellerProposalDetails.ts`, `functions/src/getResellerOpportunities.ts` (and other similar Cloud Functions)
*   **One-sentence purpose:** Provides resellers with access to specific Salesforce data (like proposals, opportunities, files) via Firebase Cloud Functions that authenticate to Salesforce using a JWT Bearer Flow with a system-level integration user.
*   **Key external services used:** Firebase Cloud Functions, Salesforce REST API (v58.0) with JWT Bearer Token authentication.

### Live Chat
*   **Directory / main file(s):** `lib/features/chat/`, `lib/features/chat/presentation/pages/admin_chat_page.dart`, `lib/features/chat/presentation/pages/chat_page.dart`, `lib/features/chat/data/repositories/chat_repository.dart`
*   **One-sentence purpose:** Enables real-time text-based communication primarily between administrators and resellers, storing conversation history and state in Firestore.
*   **Key external services used:** Cloud Firestore (for conversations and messages), Firebase Authentication (for user identification).

### Advanced File Management System
*   **Directory / main file(s):** `lib/features/opportunity/presentation/widgets/proposal_file_viewer.dart`, `functions/src/downloadFileForReseller.ts`, `functions/src/salesforceFileManagement.ts`, `functions/src/downloadSalesforceFile.ts`, `flutter_pdfview` (package)
*   **One-sentence purpose:** Provides comprehensive file handling across platforms including PDF viewing, file type detection with MIME support, secure Salesforce file retrieval via Cloud Functions, cross-platform file operations (open/save), and role-based file access control.
*   **Key external services used:** Salesforce API (for file retrieval via Cloud Functions), Firebase Cloud Functions, Firebase Storage (for user-uploaded files), MIME type detection service, platform-specific file system APIs.

### Database Migration & Maintenance
*   **Directory / main file(s):** `functions/src/migrations.ts`, `functions/src/messageCleanup.ts`, `functions/src/createMissingConversations.ts`, `functions/src/removeRememberMeField.ts`
*   **One-sentence purpose:** Handles database schema migrations, data integrity maintenance, conversation management for chat system, and cleanup operations to ensure consistent data state across Firebase and Salesforce integrations.
*   **Key external services used:** Firebase Cloud Functions (for automated maintenance), Cloud Firestore (for data migration and cleanup), Firebase Authentication (for user data consistency).

<End of step 1>

## STEP 2 — Technical Stack & Implementation Details

### Core Technologies
* **Framework:** Flutter (Dart) - SDK constraint ^3.7.0
* **State Management:** Flutter Riverpod
* **Navigation:** Go Router
* **Backend Services:** Firebase (Authentication, Firestore, Storage, Cloud Functions)
* **External Integration:** Salesforce REST API (v58.0)
* **Backend Runtime:** Node.js 22 (Cloud Functions)

### Key Dependencies
* **Firebase:**
  * `firebase_core: ^3.13.0`
  * `firebase_auth: ^5.5.2`
  * `cloud_firestore: ^5.6.6`
  * `firebase_storage: ^12.4.5`
  * `cloud_functions: ^5.4.0`
  * `firebase_messaging: ^15.2.5`

* **UI & Design:**
  * `google_fonts: ^6.1.0`
  * `flutter_svg: ^2.0.10+1`
  * `fl_chart: ^0.71.0`
  * `cached_network_image: ^3.3.1`
  * `carousel_slider: ^5.0.0`
  * `flutter_staggered_animations: ^1.1.1`
  * `font_awesome_flutter: ^10.7.0`

* **State & Data:**
  * `flutter_riverpod: ^2.5.1`
  * `equatable: ^2.0.5`
  * `dio: ^5.4.1`
  * `shared_preferences: ^2.5.3`
  * `rxdart: ^0.28.0`

* **Authentication & Security:**
  * `flutter_web_auth_2`
  * `flutter_secure_storage: ^10.0.0-beta.4`
  * `dart_jsonwebtoken: ^3.2.0`
  * `crypto: ^3.0.3`

* **File Handling:**
  * `file_picker: ^10.1.2`
  * `file_selector: ^1.0.1`
  * `path_provider: ^2.1.3`
  * `open_file: ^3.3.2`
  * `file_saver: ^0.2.14`
  * `mime: ^1.0.5`
  * `flutter_pdfview: ^1.4.0`

* **Notifications & Messaging:**
  * `flutter_local_notifications: ^19.1.0`
  * `share_plus: ^11.0.0`

* **Onboarding & UX:**
  * `introduction_screen: ^3.1.14`

* **Cloud Functions Dependencies (Node.js):**
  * `firebase-admin: ^12.6.0`
  * `firebase-functions: ^6.0.1`
  * `jsforce: ^3.7.0`
  * `jsonwebtoken: 9.0.2`
  * `axios: ^1.8.4`
  * `cors: ^2.8.5`

### Architecture Patterns
1. **Repository Pattern:**
   * Each feature has its own repository implementation
   * Abstracts data sources (Firebase, Salesforce)
   * Example: `FirebaseAuthRepository` for authentication

2. **Service Layer:**
   * Handles business logic and external service integration
   * Examples: `FirebaseFunctionsService`, `SalesforceConnectionService`

3. **Provider Pattern (Riverpod):**
   * State management and dependency injection
   * Feature-specific providers (e.g., `UserCreationProvider`)
   * Global providers for shared state

4. **Feature-First Organization:**
   * Each feature is self-contained in its own directory
   * Follows clean architecture principles
   * Structure: `lib/features/<feature_name>/`

5. **Domain-Driven Design:**
   * Clear separation of data, domain, and presentation layers
   * Entity and model separation for complex business logic
   * Use case implementations for business operations

### Security & Authentication
1. **Firebase Authentication:**
   * Email/password authentication
   * Session management
   * Role-based access control with custom claims

2. **Salesforce Integration:**
   * Dual authentication model: OAuth 2.0 and JWT Bearer Flow
   * PKCE (Proof Key for Code Exchange) for web OAuth
   * Secure token storage with platform-specific implementations

3. **Data Security:**
   * Comprehensive Firestore security rules with role-based access
   * Secure storage for sensitive data (FlutterSecureStorage/SharedPreferences)
   * Token-based API authentication with automatic refresh

4. **File Security:**
   * Role-based file access control
   * Secure file retrieval via Cloud Functions
   * MIME type validation and security checks

### Cross-Platform Support
* **Platforms:** Android, iOS, Web, macOS, Windows, Linux
* **Platform-Specific Code:**
  * Conditional imports for web/native implementations
  * Platform-specific configurations for file operations
  * Responsive design patterns for web deployment
  * Hash-based routing for web OAuth callbacks

### Push Notification Architecture
* **Firebase Cloud Messaging Integration:**
  * Cross-platform push notification support
  * Automatic FCM token management and refresh
  * Background message handling with custom handlers

* **Local Notification System:**
  * Foreground notification display
  * Notification overlay management system
  * User-specific notification preferences

### Development Tools & Scripts
* **Utility Scripts:**
  * `sync_salesforce_user_data.dart`
  * `explore_salesforce_user_metadata.dart`
  * `remove_remember_me_field.dart`

* **Testing:**
  * Firebase integration testing
  * Platform-specific test configurations
  * PowerShell scripts for API testing

* **Migration Tools:**
  * Database migration scripts in Cloud Functions
  * Data integrity validation tools
  * Automated cleanup and maintenance scripts

### Build & Deployment
* **Android:**
  * Gradle configuration with Firebase
  * Minimum SDK: 23
  * Target SDK: Latest stable

* **iOS/macOS:**
  * CocoaPods integration
  * Push notification capabilities
  * Background modes configuration

* **Web:**
  * Firebase web configuration with hosting
  * URL strategy configuration for hash routing
  * Progressive Web App support

* **Cloud Functions:**
  * Node.js 22 runtime
  * Environment variable management
  * Regional deployment (us-central1)

<End of step 2>

## STEP 3 — Data Flow & Integration Patterns

### Data Flow Architecture
1. **User Authentication Flow:**
   * Firebase Authentication for primary auth
   * Salesforce OAuth for external data access
   * Token management and refresh handling
   * Role-based access control implementation

2. **Data Synchronization:**
   * Salesforce to Firebase sync for user data
   * Real-time updates using Firestore streams
   * Offline data persistence
   * Conflict resolution strategies

3. **File Management:**
   * Firebase Storage for file uploads
   * File type validation and security
   * Progress tracking and error handling
   * Cross-platform file access

### Integration Patterns
1. **Firebase Integration:**
   * **Authentication:**
     * Email/password authentication
     * Session management
     * Token refresh handling
   
   * **Firestore:**
     * Real-time data synchronization
     * Offline persistence
     * Security rules implementation
   
   * **Cloud Functions:**
     * Serverless backend operations
     * Privileged operations handling
     * Cross-service integration

2. **Salesforce Integration:**
   * **OAuth Flow:**
     * PKCE implementation for web (typically for admin/broader org access)
     * Token storage and refresh
     * Session management
   
   * **JWT Bearer Flow (for Reseller/System Access via Cloud Functions):**
     * Used by Cloud Functions (e.g., `getResellerOpportunities`, `downloadFileForReseller`) to act on behalf of a pre-configured Salesforce integration user.
     * **Process:**
       1. A private key and consumer key are stored as environment variables in Firebase Cloud Functions.
       2. A JWT is generated, claiming `iss` (consumer key), `sub` (Salesforce username of integration user), `aud` (Salesforce token endpoint), and `exp` (expiration time).
       3. The JWT is signed with the private key using RS256 algorithm.
       4. The signed JWT is sent to the Salesforce token endpoint (`https://login.salesforce.com/services/oauth2/token`) with `grant_type: urn:ietf:params:oauth:grant-type:jwt-bearer`.
       5. Salesforce validates the JWT and returns an `access_token` and `instance_url`.
       6. This `access_token` is then used to make API calls to Salesforce REST API.
     * **Key Files:** `functions/src/*.ts` (various functions implementing this flow), `jsonwebtoken` and `axios` npm packages are used.
     * **Security:** Relies on secure storage of the private key and consumer key in Firebase environment variables.
     * **Mermaid Diagram:**
       ```mermaid
       sequenceDiagram
         participant CF as Firebase Cloud Function
         participant SFAuth as Salesforce Token Endpoint
         participant SFAPI as Salesforce REST API

         CF->>+SFAuth: Generate JWT (iss, sub, aud, exp)
         SFAuth->>-CF: Validate JWT, Return access_token, instance_url
         CF->>+SFAPI: API Request with access_token
         SFAPI->>-CF: API Response
       end
       ```

   * **API Integration:**
     * REST API v58.0 utilized by Cloud Functions and direct Flutter services.
     * **Cloud Functions (JWT Flow):** Primarily interact with Salesforce SObjects like `Oportunidade__c` (Opportunity), `Proposta_CPE__c` (Proposal), `ContentVersion` (for files), and potentially `Account` or `Contact` for reseller-related data. Calls involve SOQL queries for data retrieval and DML operations (via REST API for create/update/delete where applicable).
     * **Flutter Services (OAuth Flow):** Likely interact with `User`, `Account`, and other standard/custom SObjects for broader data access and synchronization tasks by authenticated admin users.
     * Batch operations for efficient data handling where applicable.

3. **Cross-Service Communication:**
   * **Firebase → Salesforce:**
     * User data synchronization
     * Opportunity management
     * Proposal lifecycle management
     * File attachment handling
   
   * **Salesforce → Firebase:**
     * User profile updates
     * Revenue data synchronization
     * Status updates
     * Commission calculations

### Proposal Management Data Flow
The proposal system implements a sophisticated workflow for Customer Premises Equipment (CPE) proposals:

1. **Proposal Creation Flow:**
   * Admin creates proposal via `proposal_creation_page.dart`
   * Data validation and business logic via Riverpod providers
   * Firebase Cloud Function `createSalesforceProposal.ts` handles Salesforce SObject creation
   * Real-time status updates via Firestore streams

2. **Proposal Approval Workflow:**
   * Multi-stage approval process with status tracking
   * Document management with Firebase Storage integration
   * Automated notifications via `notifications.ts` Cloud Function
   * Integration with `acceptProposalAndUploadDocs.ts` for final processing

3. **CPE Integration:**
   * Complex SObject relationships in Salesforce
   * Automated equipment configuration via `createCpeForProposal.ts`
   * Integration with provider systems for equipment provisioning

### Notification System Data Flow
The notification system provides comprehensive real-time communication:

1. **Push Notification Flow:**
   * **Trigger Events:** New chat messages, proposal status changes, system alerts
   * **Cloud Function Processing:** `notifications.ts` handles FCM token management and message sending
   * **Multi-Platform Delivery:** iOS, Android, and Web push notifications
   * **Fallback Handling:** Local notifications for foreground app states

2. **Notification Persistence:**
   * **Firestore Storage:** All notifications stored in `notifications` collection
   * **User-Specific Querying:** Optimized with composite indexes for userId + timestamp
   * **Read State Management:** Real-time unread count tracking
   * **Cleanup Operations:** Automated cleanup via `messageCleanup.ts`

3. **Real-Time Updates:**
   * **Firestore Streams:** Real-time notification delivery via Riverpod providers
   * **Overlay Management:** `NotificationOverlayManager` for in-app notification display
   * **Cross-Feature Integration:** Notifications integrated with chat, proposals, and user management

### Commission & Analytics Data Flow
The revenue tracking system provides real-time financial analytics:

1. **Commission Calculation:**
   * **Data Sources:** Salesforce Opportunity data, proposal acceptance events
   * **Processing:** `commissionFunctions.ts` calculates commissions based on business rules
   * **Storage:** Results cached in Firestore for performance
   * **Real-Time Updates:** Dashboard updates via Firestore streams

2. **Dashboard Analytics:**
   * **Data Aggregation:** `getResellerDashboardStats.ts` provides comprehensive metrics
   * **Performance Tracking:** Revenue trends, conversion rates, proposal success metrics
   * **Role-Based Views:** Different analytics for admin vs reseller roles

### Error Handling & Recovery
1. **Network Errors:**
   * Offline mode handling with Firestore persistence
   * Retry mechanisms with exponential backoff
   * Error state management via Riverpod providers

2. **Authentication Errors:**
   * Automatic token refresh handling
   * Session recovery with secure storage fallback
   * Re-authentication flows with user notification

3. **Data Sync Errors:**
   * Conflict resolution strategies for Salesforce/Firebase sync
   * Data validation with business rule enforcement
   * Recovery procedures with manual override capabilities

4. **File Operation Errors:**
   * Cross-platform error handling for file operations
   * Retry mechanisms for file uploads/downloads
   * MIME type validation and security error handling

### Performance Optimization
1. **Data Loading:**
   * Pagination implementation for large datasets
   * Lazy loading with infinite scroll patterns
   * Caching strategies with Firestore offline persistence

2. **File Operations:**
   * Chunked uploads for large files
   * Compression algorithms for optimization
   * Progress tracking with cancellation support

3. **State Management:**
   * Efficient Riverpod provider usage with proper disposal
   * State persistence across app lifecycle
   * Memory management with stream subscription cleanup

4. **Real-Time Updates:**
   * Optimized Firestore listeners with proper scoping
   * Debounced updates to prevent excessive rebuilds
   * Efficient stream composition with RxDart

### Security Implementation
1. **Data Protection:**
   * End-to-end encryption for sensitive operations
   * Secure storage with platform-specific implementations
   * Data sanitization and validation

2. **Access Control:**
   * Role-based permissions with custom Firebase claims
   * Feature flags for gradual rollout
   * Comprehensive audit logging

3. **API Security:**
   * Rate limiting via Firebase security rules
   * Request validation and sanitization
   * Token management with automatic refresh
   * CORS configuration for web security

### Chat Feature Data Model (Firestore)
The live chat feature uses two main collections in Firestore:

1.  **`conversations` Collection:**
    *   Each document in this collection represents a chat conversation, typically between an admin and a reseller.
    *   **Document ID:** Auto-generated by Firestore.
    *   **Key Fields (based on `ChatConversation` model):**
        *   `id` (string): The document ID itself.
        *   `resellerId` (string): UID of the reseller participant.
        *   `resellerName` (string): Display name of the reseller.
        *   `lastMessageContent` (string, nullable): Content of the last message sent in the conversation.
        *   `lastMessageTime` (timestamp, nullable): Timestamp of the last message.
        *   `active` (boolean, nullable): Indicates if the conversation has had any real messages beyond an initial welcome.
        *   `unreadCounts` (map): A map where keys are user UIDs (e.g., 'admin', reseller's UID) and values are the number of unread messages for that user in this conversation.
        *   `participants` (array of strings): Contains UIDs of all participants (e.g., \['admin', reseller's UID]).
        *   `createdAt` (timestamp): When the conversation was initiated.
        *   *(Legacy fields like `unreadByAdmin`, `unreadByReseller`, `unreadCount` might exist for backward compatibility but `unreadCounts` is the current approach).*

2.  **`messages` Subcollection:**
    *   Nested under each document in the `conversations` collection.
    *   Each document in this subcollection represents a single message within that conversation.
    *   **Document ID:** Auto-generated by Firestore.
    *   **Key Fields (based on `ChatMessage` model):**
        *   `id` (string): The document ID itself.
        *   `senderId` (string): UID of the message sender.
        *   `senderName` (string): Display name of the sender.
        *   `content` (string): The actual message content (text or URL for image).
        *   `timestamp` (timestamp): Server timestamp when the message was sent.
        *   `isAdmin` (boolean): True if the sender is an admin.
        *   `isRead` (boolean): Indicates if the message has been read (likely by the recipient).
        *   `type` (string): Type of message, e.g., "text", "image", "file". (Enum `MessageType` in Dart)
        *   `isDefault` (boolean): True if this is an automated message (e.g., a welcome message).
        *   `fileName` (string, nullable): Original filename for file messages.
        *   `fileType` (string, nullable): MIME type of attached files.
        *   `fileSize` (int, nullable): Size in bytes for file messages.

### Provider Management Data Model (Firestore)
The provider system manages energy provider partnerships:

1. **`providers` Collection:**
   * **Document Structure:** Each provider has metadata, contact information, and service offerings
   * **Role-Based Access:** Admins can create/edit, resellers have read-only access
   * **File Management:** Nested `files` subcollection for provider documents

2. **Provider File Management:**
   * **Secure Access:** Files stored in Firebase Storage with role-based access rules
   * **File Metadata:** Stored in Firestore for efficient querying and permission checking
   * **Cross-Platform Support:** File viewing and download across all supported platforms

### Database Migration & Maintenance Patterns
The maintenance system ensures data integrity and system evolution:

1. **Migration Framework:**
   * **Version Control:** Database schema versioning with migration scripts
   * **Rollback Support:** Ability to reverse migrations if issues arise
   * **Data Integrity:** Validation and consistency checks during migrations

2. **Automated Maintenance:**
   * **Scheduled Cleanup:** Regular cleanup of old messages, notifications, and temporary data
   * **Consistency Checks:** Automated validation of data relationships across Firebase and Salesforce
   * **Performance Optimization:** Index optimization and query performance monitoring

### Other Client-Side Integrations
*   **Sharing:** The `share_plus` package is used to integrate with native platform sharing capabilities (e.g., share content via other apps).
*   **Local Notifications:** The `flutter_local_notifications` package is used to display local notifications on the device, often in conjunction with Firebase Messaging for foreground message handling.
*   **Onboarding:** The `introduction_screen` package provides guided onboarding for new users with feature highlights and tutorials.
*   **File Operations:** Cross-platform file operations with `open_file` for viewing and `file_saver` for downloading files to device storage.
*   **MIME Detection:** Advanced file type detection using the `mime` package for proper file handling and security validation.

<End of step 3>

## STEP 4 — Development Workflow & Best Practices

### Development Environment
1. **Required Tools:**
   * Flutter SDK (latest stable)
   * Dart SDK
   * Android Studio / VS Code
   * Firebase CLI
   * FlutterFire CLI

2. **Environment Setup:**
   * Firebase project configuration
   * Platform-specific setup (Android/iOS/Web)
   * Development certificates and keys
   * Environment variables

3. **Development Tools:**
   * Git for version control
   * Flutter DevTools for debugging
   * Firebase Console for backend management
   * Postman/Insomnia for API testing

### Code Organization
1. **Directory Structure:**
   ```
   lib/
   ├── app/                 # App-wide configurations
   ├── core/               # Core utilities and services
   ├── features/           # Feature modules
   │   ├── auth/
   │   ├── user_management/
   │   └── ...
   ├── shared/             # Shared widgets and utilities
   └── main.dart           # Entry point
   ```

2. **Feature Module Structure:**
   ```
   features/
   ├── feature_name/
   │   ├── data/          # Data layer
   │   │   ├── models/
   │   │   ├── repositories/
   │   │   └── services/
   │   ├── domain/        # Business logic
   │   │   ├── entities/
   │   │   └── usecases/
   │   └── presentation/  # UI layer
   │       ├── pages/
   │       ├── widgets/
   │       └── providers/
   ```

### Coding Standards
1. **Dart/Flutter:**
   * Follow official Dart style guide
   * Use meaningful variable names
   * Document public APIs
   * Implement proper error handling

2. **State Management:**
   * Use Riverpod for state management
   * Keep providers focused and small
   * Implement proper error states
   * Handle loading states

3. **Testing:**
   * Write unit tests for business logic
   * Widget tests for UI components
   * Integration tests for features
   * Mock external dependencies

### Version Control
1. **Branch Strategy:**
   * `main` - Production code
   * `develop` - Development branch
   * `feature/*` - Feature branches
   * `hotfix/*` - Production fixes

2. **Commit Guidelines:**
   * Use conventional commits
   * Write clear commit messages
   * Keep commits focused and atomic
   * Reference issue numbers

3. **Code Review:**
   * Review for functionality
   * Check code style
   * Verify test coverage
   * Ensure documentation

### Deployment Process
1. **Pre-deployment:**
   * Run all tests
   * Check code quality
   * Update version numbers
   * Update changelog

2. **Deployment Steps:**
   * Build platform-specific packages
   * Deploy Firebase functions
   * Update Firebase security rules
   * Deploy web version

3. **Post-deployment:**
   * Monitor error reports
   * Check analytics
   * Verify integrations
   * Update documentation

### Documentation
1. **Code Documentation:**
   * Document public APIs
   * Add inline comments
   * Keep README updated
   * Document configuration

2. **Architecture Documentation:**
   * Update architecture docs
   * Document design decisions
   * Maintain API documentation
   * Document deployment process

3. **User Documentation:**
   * Update user guides
   * Document new features
   * Maintain changelog
   * Document known issues

### Performance Monitoring
1. **Metrics to Track:**
   * App startup time
   * Screen load times
   * API response times
   * Memory usage

2. **Error Tracking:**
   * Firebase Crashlytics
   * Error logging
   * User feedback
   * Performance metrics

3. **Optimization:**
   * Regular performance reviews
   * Memory leak detection
   * Network optimization
   * UI performance

<End of step 4>
