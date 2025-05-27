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

### Service Submissions
*   **Directory / main file(s):** `lib/features/services/`, `lib/features/services/data/repositories/service_submission_repository.dart`
*   **One-sentence purpose:** Enables users (resellers) to submit service requests/proposals, including metadata and file attachments, which are stored in Firestore and Firebase Storage respectively.
*   **Key external services used:** Cloud Firestore (for submission metadata), Firebase Storage (for attachments).

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

### File Viewing & Handling
*   **Directory / main file(s):** `lib/features/opportunity/presentation/widgets/proposal_file_viewer.dart` (example UI), `functions/src/downloadFileForReseller.ts` (backend), `flutter_pdfview` (package)
*   **One-sentence purpose:** Allows users to view files (especially PDFs) sourced from Salesforce or uploaded by users, with backend functions to retrieve file data and frontend widgets to display it.
*   **Key external services used:** Salesforce API (for file retrieval via Cloud Functions), Firebase Cloud Functions, Firebase Storage (potentially for user-uploaded files not directly tied to Salesforce).

<End of step 1>

## STEP 2 — Technical Stack & Implementation Details

### Core Technologies
* **Framework:** Flutter (Dart)
* **State Management:** Flutter Riverpod
* **Navigation:** Go Router
* **Backend Services:** Firebase (Authentication, Firestore, Storage, Cloud Functions)
* **External Integration:** Salesforce REST API (v58.0)

### Key Dependencies
* **Firebase:**
  * `firebase_core: ^2.25.4`
  * `firebase_auth: ^4.17.4`
  * `cloud_firestore: ^4.15.4`
  * `firebase_storage: ^11.6.5`
  * `cloud_functions: ^4.7.6`
  * `firebase_messaging: ^14.7.15`

* **UI & Design:**
  * `google_fonts: ^6.1.0`
  * `flutter_svg: ^2.0.10+1`
  * `fl_chart: ^0.71.0`
  * `cached_network_image: ^3.3.1`
  * `carousel_slider: ^5.0.0`
  * `flutter_staggered_animations: ^1.1.1`

* **State & Data:**
  * `flutter_riverpod: ^2.5.1`
  * `equatable: ^2.0.5`
  * `dio: ^5.4.1`
  * `shared_preferences: ^2.5.3`

* **Authentication & Security:**
  * `flutter_web_auth_2`
  * `flutter_secure_storage: ^10.0.0-beta.4`
  * `dart_jsonwebtoken: ^3.2.0`

* **File Handling:**
  * `file_picker: ^10.1.2`
  * `file_selector: ^1.0.1`
  * `path_provider: ^2.1.3`
  * `open_file: ^3.3.2`

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

### Security & Authentication
1. **Firebase Authentication:**
   * Email/password authentication
   * Session management
   * Role-based access control

2. **Salesforce Integration:**
   * OAuth 2.0 authentication
   * PKCE (Proof Key for Code Exchange) for web
   * Secure token storage

3. **Data Security:**
   * Firestore security rules
   * Secure storage for sensitive data
   * Token-based API authentication

### Cross-Platform Support
* **Platforms:** Android, iOS, Web, macOS
* **Platform-Specific Code:**
  * Conditional imports for web/native
  * Platform-specific configurations
  * Responsive design for web

### Development Tools & Scripts
* **Utility Scripts:**
  * `sync_salesforce_user_data.dart`
  * `explore_salesforce_user_metadata.dart`
  * `remove_remember_me_field.dart`

* **Testing:**
  * Firebase integration testing
  * Platform-specific test configurations

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
  * Firebase web configuration
  * URL strategy configuration
  * Progressive Web App support

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
     * File attachment handling
   
   * **Salesforce → Firebase:**
     * User profile updates
     * Revenue data synchronization
     * Status updates

### Error Handling & Recovery
1. **Network Errors:**
   * Offline mode handling
   * Retry mechanisms
   * Error state management

2. **Authentication Errors:**
   * Token refresh handling
   * Session recovery
   * Re-authentication flows

3. **Data Sync Errors:**
   * Conflict resolution
   * Data validation
   * Recovery procedures

### Performance Optimization
1. **Data Loading:**
   * Pagination implementation
   * Lazy loading
   * Caching strategies

2. **File Operations:**
   * Chunked uploads
   * Compression
   * Progress tracking

3. **State Management:**
   * Efficient provider usage
   * State persistence
   * Memory management

### Security Implementation
1. **Data Protection:**
   * End-to-end encryption
   * Secure storage
   * Data sanitization

2. **Access Control:**
   * Role-based permissions
   * Feature flags
   * Audit logging

3. **API Security:**
   * Rate limiting
   * Request validation
   * Token management

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
        *   `type` (string): Type of message, e.g., "text", "image". (Enum `MessageType` in Dart)
        *   `isDefault` (boolean): True if this is an automated message (e.g., a welcome message).

### Other Client-Side Integrations
*   **Sharing:** The `share_plus` package is used to integrate with native platform sharing capabilities (e.g., share content via other apps).
*   **Local Notifications:** The `flutter_local_notifications` package is used to display local notifications on the device, often in conjunction with Firebase Messaging for foreground message handling.

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
