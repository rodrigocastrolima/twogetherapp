import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'app/router/app_router.dart';
import 'features/auth/presentation/providers/cloud_functions_provider.dart';
import 'features/auth/data/services/firebase_functions_service.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set persistence to LOCAL to maintain session across app restarts
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

  // Configure Firebase Functions
  // We'll skip emulator in debug mode since we've deployed the functions
  bool cloudFunctionsAvailable = false;

  try {
    debugPrint('🔍 Checking Cloud Functions availability...');

    // Initialize the Firebase Functions service
    final functionsService = FirebaseFunctionsService();
    debugPrint('FirebaseFunctionsService initialized for region: us-central1');

    // Use the service's method to check availability
    cloudFunctionsAvailable = await functionsService.checkAvailability();

    if (cloudFunctionsAvailable) {
      debugPrint('✅ Cloud Functions are available!');
    } else {
      debugPrint(
        '❌ Cloud Functions are not available - check deployment in us-central1 region',
      );
    }
  } catch (e) {
    debugPrint('❌ Error checking Cloud Functions availability: $e');
    // Print stack trace for deeper debugging
    debugPrint('Stack trace: ${StackTrace.current}');
  }

  // Reset authentication on app restart only in debug mode
  // In production, we'll let Firebase persistence handle sessions
  if (kDebugMode && false) {
    // Disabled for now to prevent login issues
    debugPrint('Debug mode: Resetting authentication state');
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
      ],
      child: const App(),
    ),
  );
}
