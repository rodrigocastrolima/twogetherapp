import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'app/router/app_router.dart';
import 'features/auth/presentation/providers/cloud_functions_provider.dart';
import 'features/auth/data/services/firebase_functions_service.dart';
import 'core/providers/locale_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'core/theme/theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/salesforce/data/repositories/salesforce_repository.dart';

// --- Background Handler ---
// Must be a top-level function (outside of any class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, like Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");

  // TODO: Initialize flutter_local_notifications
  // TODO: Extract title/body from message.notification or message.data
  // TODO: Show local notification

  // Example (needs flutter_local_notifications setup):
  // final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  // await flutterLocalNotificationsPlugin.show(
  //   message.hashCode,
  //   message.notification?.title ?? 'New Message',
  //   message.notification?.body ?? 'You received a new message.',
  //   NotificationDetails(...), // Define platform-specific details
  // );
}

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // --- Register Background Handler ---
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // --- Request Permissions (iOS/Web mainly, good practice for Android too) ---
  // It's often better to request this later after explaining why you need permissions
  // FirebaseMessaging messaging = FirebaseMessaging.instance;
  // NotificationSettings settings = await messaging.requestPermission(
  //   alert: true,
  //   announcement: false,
  //   badge: true,
  //   carPlay: false,
  //   criticalAlert: false,
  //   provisional: false,
  //   sound: true,
  // );
  // if (kDebugMode) {
  //   print('User granted permission: ${settings.authorizationStatus}');
  // }

  // Initialize FilePicker
  try {
    if (kDebugMode) {
      print('Initializing FilePicker...');
    }
    // Ensure FilePicker is properly initialized
    await FilePicker.platform.clearTemporaryFiles();
    if (kDebugMode) {
      print('FilePicker initialized successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error initializing FilePicker: $e');
    }
  }

  // Set default persistence to SESSION only on web platforms
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
  }

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

class TwogetherApp extends ConsumerWidget {
  const TwogetherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get router from the App router class
    final router = AppRouter.router;

    return MaterialApp.router(
      title: 'Twogether',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppTheme.background,
        colorScheme: ColorScheme.light(
          primary: AppTheme.primary,
          onPrimary: Colors.white,
          secondary: AppTheme.secondary,
          onSecondary: Colors.white,
          background: AppTheme.background,
          onBackground: AppTheme.foreground,
          surface: Colors.white,
          onSurface: AppTheme.foreground,
        ),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: AppTheme.background,
          foregroundColor: AppTheme.foreground,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      // Theme configuration
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: AppTheme.primary,
          onPrimary: Colors.white,
          secondary: AppTheme.secondary,
          onSecondary: Colors.white,
          background: Colors.black,
          onBackground: Colors.white,
          surface: Colors.grey[900]!,
          onSurface: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ).apply(bodyColor: Colors.white, displayColor: Colors.white),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      // Router configuration
      routerConfig: router,
      // Localization
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('pt', ''), // Portuguese
      ],
    );
  }
}
