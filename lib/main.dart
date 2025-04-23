import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_strategy/url_strategy.dart';
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
import 'core/utils/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'package:shared_preferences/shared_preferences.dart';

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
  WidgetsFlutterBinding.ensureInitialized();
  setPathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize SharedPreferences FIRST
  final sharedPreferences = await SharedPreferences.getInstance();

  // Create the ProviderContainer WITH the override
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      // You might have other overrides here eventually
    ],
  );

  // Handle Salesforce callback immediately on web
  if (kIsWeb) {
    await _handleSalesforceWebCallback(container);
  }

  // Initialize Salesforce auth state (just read the provider)
  container.read(salesforceAuthProvider.notifier);

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

  runApp(
    UncontrolledProviderScope(
      container: container,
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

// --- Salesforce Web Callback Handling ---
Future<void> _handleSalesforceWebCallback(ProviderContainer container) async {
  if (!kIsWeb) return;

  final uri = Uri.base;
  final code = uri.queryParameters['code'];
  final error = uri.queryParameters['error'];
  final errorDescription = uri.queryParameters['error_description'];

  // If there's an error parameter, log it and clean the URL
  if (error != null) {
    if (kDebugMode) {
      print('Salesforce Callback Error: $error - $errorDescription');
    }
    // Clean the URL by removing query parameters
    html.window.history.replaceState(null, '', '/');
    return;
  }

  // If there's a code parameter, handle it
  if (code != null && code.isNotEmpty) {
    // Retrieve the original code verifier stored before redirect
    final verifier = html.window.sessionStorage[_codeVerifierSessionKey];

    if (verifier != null && verifier.isNotEmpty) {
      // Temporarily store code and verifier for the auth service to pick up
      html.window.sessionStorage[_tempSalesforceCodeKey] = code;
      html.window.sessionStorage[_tempSalesforceVerifierKey] = verifier;

      // Remove the original verifier key now that it's copied
      html.window.sessionStorage.remove(_codeVerifierSessionKey);
      // Clean the URL by removing query parameters
      html.window.history.replaceState(null, '', '/');

      if (kDebugMode) {
        print('Salesforce callback code and verifier stored temporarily.');
      }
    } else {
      if (kDebugMode) {
        print('Salesforce callback code received, but verifier missing!');
      }
      // Clean the URL even if verifier is missing
      html.window.history.replaceState(null, '', '/');
    }
  } else {
    // If no code and no error, check if we still have temporary code/verifier
    // This might happen on a page refresh after callback but before completion
    final tempCode = html.window.sessionStorage[_tempSalesforceCodeKey];
    if (tempCode == null) {
      // If no temp code, ensure the URL is clean if it still has params
      if (uri.hasQuery) {
        html.window.history.replaceState(null, '', '/');
      }
    }
  }
}
