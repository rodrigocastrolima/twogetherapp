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
import 'app/router/app_router.dart';
import 'features/auth/presentation/providers/cloud_functions_provider.dart';
import 'features/auth/data/services/firebase_functions_service.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/shared_preferences_provider.dart';
import 'package:flutter/services.dart';
import 'core/theme/theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/salesforce/data/repositories/salesforce_repository.dart';
import 'core/services/salesforce_auth_service.dart';
import 'dart:async'; // Import for StreamSubscription
import 'dart:html' if (dart.library.io) 'dart:io' as html;

// Define session storage keys (ensure these match usage in SalesforceAuthNotifier)
const String _tempSalesforceCodeKey = 'temp_sf_code';
const String _tempSalesforceVerifierKey = 'temp_sf_verifier';
const String _codeVerifierSessionKey = 'salesforce_pkce_verifier';

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

  // --- Handle Salesforce Web Callback URL Parameters ---
  if (kIsWeb) {
    try {
      final uri = Uri.base; // Use Uri.base for initial load URL
      // Check fragment first for /callback (common pattern)
      // Then check query parameters for 'code'
      if (uri.fragment.contains('callback') &&
          uri.queryParameters.containsKey('code')) {
        final code = uri.queryParameters['code'];
        if (code != null && code.isNotEmpty) {
          print(
            'Main: Detected Salesforce callback fragment/query. Processing...',
          );
          // 1. Retrieve verifier stored before redirect
          final verifier = html.window.sessionStorage[_codeVerifierSessionKey];
          if (verifier != null && verifier.isNotEmpty) {
            // 2. Save code & verifier for later exchange
            html.window.sessionStorage[_tempSalesforceCodeKey] = code;
            html.window.sessionStorage[_tempSalesforceVerifierKey] = verifier;

            // 3. Clean up original verifier & URL
            html.window.sessionStorage.remove(_codeVerifierSessionKey);
            html.window.history.replaceState(null, '', '/'); // Clean URL
            print(
              'Main: Salesforce PKCE callback handled: code and verifier cached. URL cleaned.',
            );
          } else {
            print(
              'Main Error: Salesforce callback detected, but PKCE verifier missing in session storage using key $_codeVerifierSessionKey.',
            );
            // Optionally clean URL anyway to avoid infinite loops
            html.window.history.replaceState(null, '', '/');
          }
        } else {
          print(
            'Main Warning: Salesforce callback detected, but code parameter is null or empty.',
          );
          // Optionally clean URL anyway
          html.window.history.replaceState(null, '', '/');
        }
      } // else: Not the callback URL, proceed normally
    } catch (e) {
      print('Main Error: Exception during Salesforce callback check: $e');
      // Attempt to clean URL as a fallback if possible
      try {
        html.window.history.replaceState(null, '', '/');
      } catch (_) {}
    }
  }
  // --- End Salesforce Callback Handling ---

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

  // Initialize the app with ProviderScope
  runApp(
    ProviderScope(
      overrides: [
        // Override the provider to indicate whether Cloud Functions are available
        cloudFunctionsAvailableProvider.overrideWithValue(
          cloudFunctionsAvailable,
        ),
        // Override the IMPORTED shared preferences provider
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const TwogetherApp(),
    ),
  );
}

class TwogetherApp extends ConsumerStatefulWidget {
  const TwogetherApp({super.key});

  @override
  ConsumerState<TwogetherApp> createState() => _TwogetherAppState();
}

class _TwogetherAppState extends ConsumerState<TwogetherApp> {
  StreamSubscription<User?>? _authSubscription;
  bool _initialAuthCheckDone = false;

  @override
  void initState() {
    super.initState();
    _listenForAuthAndTriggerSalesforceCheck();
  }

  void _listenForAuthAndTriggerSalesforceCheck() {
    _authSubscription?.cancel();

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) {
      if (kIsWeb && user != null && !_initialAuthCheckDone) {
        print(
          'TwogetherApp State: Initial Firebase auth detected on web. Triggering Salesforce check.',
        );
        _initialAuthCheckDone = true;
        try {
          final salesforceAuthNotifier = ref.read(
            salesforceAuthProvider.notifier,
          );
          salesforceAuthNotifier.checkAndCompleteWebLogin();
        } catch (e) {
          print(
            'TwogetherApp State: Error triggering Salesforce check from auth listener: $e',
          );
        }
      } else if (user == null) {
        // Optional: Reset flag if user signs out
        // _initialAuthCheckDone = false;
        // print('TwogetherApp State: User signed out, resetting Salesforce check flag.');
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
