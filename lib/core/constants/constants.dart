// TODO: Review and potentially move some of these to theme or specific feature constants.

class AppConstants {
  // Example Constant (replace or remove as needed)
  static const String appName = 'Twogether';

  // --- Shared Preferences Keys ---
  static const String themePreferenceKey = 'app_theme';
  static const String localePreferenceKey = 'app_locale';
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String kHasCompletedOnboardingTutorial =
      'hasCompletedOnboardingTutorial';
  // --- NEW Constant for Help Icon Hint ---
  static const String kHasSeenHelpIconHint = 'hasSeenHelpIconHint';
  // -------------------------------------
  // Add other shared preferences keys here

  // --- API Endpoints or Base URLs ---
  // static const String baseApiUrl = 'https://api.example.com';
  // Add other API-related constants

  // --- Default Values ---
  static const String defaultLocale = 'en';
  // Add other default values

  // --- Durations ---
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 500);
  // Add other common durations

  // --- UI related constants (consider moving to theme/styles if appropriate) ---
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
}

// Example of specific constants (could be in their own files)
class ApiKeys {
  // static const String googleMapsApiKey = 'YOUR_API_KEY_HERE';
}

// --- Color constants (Strongly consider using Theme.of(context).colorScheme or AppColors instead) ---
// Avoid defining colors here unless absolutely necessary and not theme-dependent.
// class AppColors {
//   static const Color primary = Color(0xFF...). // Use Theme instead
// }
