import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'app/router/app_router.dart';
import 'features/auth/presentation/providers/cloud_functions_provider.dart';
import 'features/auth/data/services/firebase_functions_service.dart';
import 'core/providers/locale_provider.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set default persistence to SESSION so users are not remembered by default
  // Remember Me will explicitly change this to LOCAL when checked
  await FirebaseAuth.instance.setPersistence(Persistence.SESSION);

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  // Configure Firebase Functions
  bool cloudFunctionsAvailable = false;

  try {
    // Initialize the Firebase Functions service
    final functionsService = FirebaseFunctionsService();

    // Check if Cloud Functions are available
    cloudFunctionsAvailable = await functionsService.checkAvailability();

    if (kDebugMode) {
      print(
        cloudFunctionsAvailable
            ? '✅ Cloud Functions are available!'
            : '❌ Cloud Functions are not available - check deployment in us-central1 region',
      );
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error checking Cloud Functions availability: $e');
    }
  }

  // Reset authentication on app restart only in debug mode
  // In production, we'll let Firebase persistence handle sessions
  if (kDebugMode && false) {
    // Disabled for now to prevent login issues
    print('Debug mode: Resetting authentication state');
    await AppRouter.authNotifier.setAuthenticated(false);
  }

  // Initialize the app with cloud functions availability
  runApp(
    ProviderScope(
      overrides: [
        // Override the provider to indicate whether Cloud Functions are available
        cloudFunctionsAvailableProvider.overrideWithValue(
          cloudFunctionsAvailable,
        ),
        // Override the shared preferences provider with the instance
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const App(),
    ),
  );
}
