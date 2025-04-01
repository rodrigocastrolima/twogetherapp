# TwogetherApp

A Flutter application for managing renewable energy offerings. This app includes user management, authentication, and administrative features with secure Cloud Functions integration.

## Features

- **Authentication**: Secure email/password authentication using Firebase Auth
- **User Management**: Admin dashboard for creating, enabling/disabling users, and resetting passwords
- **Role-Based Access Control**: Different access levels for administrators and resellers
- **Cloud Functions**: Secure server-side operations for user management (requires Blaze plan)

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version recommended)
- Firebase project (Blaze plan required for Cloud Functions)
- Firebase CLI for deploying Cloud Functions

### Project Setup

1. Clone the repository
2. Install dependencies:
   ```
   flutter pub get
   ```
3. Set up Firebase:
   ```
   firebase login
   flutterfire configure
   ```

### Running the App

```
flutter run
```

## Architecture

This project follows a clean architecture approach with:

- **Domain Layer**: Contains business models and repository interfaces
- **Data Layer**: Implements repositories and services for data access
- **Presentation Layer**: UI components, providers, and state management
- **Cloud Functions**: Server-side code for secure administrative operations

## Firebase Cloud Functions

The app integrates with Firebase Cloud Functions for secure user management:

- Creating new users without disrupting admin sessions
- Enabling/disabling user accounts
- Resetting user passwords

**Important**: Cloud Functions require the Firebase Blaze (pay-as-you-go) plan.

See the [functions/README.md](functions/README.md) for detailed setup and deployment instructions.

## Dependencies

Major dependencies include:

- **flutter_riverpod**: State management
- **go_router**: Navigation
- **firebase_auth**: Authentication
- **cloud_firestore**: Database
- **cloud_functions**: Server-side functions

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
