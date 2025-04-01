import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart'; // Required for WidgetsFlutterBinding.ensureInitialized()
import '../lib/firebase_options.dart'; // Use relative path
import '../lib/features/salesforce/data/services/salesforce_connection_service.dart'; // Use relative path
import '../lib/features/salesforce/data/repositories/salesforce_repository.dart'; // Use relative path

// This script tests the Salesforce JWT connection via Cloud Function
// and lists available SObjects if successful.

void main() async {
  // Ensure Flutter bindings are initialized for plugin usage
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options:
        DefaultFirebaseOptions
            .currentPlatform, // This should be defined in firebase_options.dart
  );

  print('Firebase Initialized.');
  print('Attempting to get Salesforce token via Firebase Function...');

  final connectionService = SalesforceConnectionService();
  bool tokenRefreshed = false;
  try {
    // Attempt to get/refresh token using the Cloud Function (JWT flow)
    tokenRefreshed =
        await connectionService.refreshTokenUsingFirebaseFunction();

    if (tokenRefreshed) {
      print('Successfully obtained Salesforce token via Firebase Function.');

      // Await the accessToken getter and handle null/length
      String? token = await connectionService.accessToken;
      if (token != null) {
        print(
          'Access Token (first 10 chars): ${token.substring(0, token.length < 10 ? token.length : 10)}...',
        );
      } else {
        print('Access Token: null (Could not retrieve after refresh)');
      }

      print(
        'Instance URL: ${connectionService.instanceUrl}',
      ); // This getter is synchronous
      print('\nAttempting to list available Salesforce SObjects...');

      // Use the same connection service instance for the repository
      final salesforceRepo = SalesforceRepository(
        connectionService: connectionService,
      );

      final objectNames = await salesforceRepo.listAvailableObjects();

      if (objectNames.isNotEmpty) {
        print('\n--- Available Salesforce SObjects ---');
        objectNames.forEach((name) => print('- $name'));
        print('------------------------------------');
        print('\nTest Successful!');
      } else {
        print(
          '\nCould not retrieve SObject list. The connection might be valid, but the API call failed.',
        );
      }
    } else {
      print('\nFailed to obtain Salesforce token via Firebase Function.');
      print(
        'Please check Firebase Function logs (`getSalesforceAccessToken`) for errors.',
      );
    }
  } catch (e) {
    print('\nAn error occurred during the process:');
    print(e);
    if (!tokenRefreshed) {
      print(
        '\nError likely occurred during token retrieval via Cloud Function.',
      );
      print(
        'Please check Firebase Function logs (`getSalesforceAccessToken`) for errors.',
      );
    } else {
      print('\nError likely occurred while listing SObjects.');
    }
  }
}
