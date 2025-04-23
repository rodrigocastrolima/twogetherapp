import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
// Import the centralized provider
import 'shared_preferences_provider.dart';

/// A provider that manages the locale state of the application
class LocaleNotifier extends StateNotifier<Locale> {
  final SharedPreferences _prefs;

  /// Default locale is Portuguese (pt)
  LocaleNotifier(this._prefs) : super(const Locale('pt')) {
    // Load saved locale from SharedPreferences during initialization
    _loadSavedLocale();
  }

  /// Load the saved locale from SharedPreferences
  Future<void> _loadSavedLocale() async {
    final savedLocaleCode = _prefs.getString(AppConstants.localePreferenceKey);
    if (savedLocaleCode != null) {
      state = Locale(savedLocaleCode);
    }
  }

  /// Change the locale and save it to SharedPreferences
  Future<void> setLocale(String localeCode) async {
    state = Locale(localeCode);
    await _prefs.setString(AppConstants.localePreferenceKey, localeCode);
  }

  /// Get language name based on locale code
  String getLanguageName() {
    switch (state.languageCode) {
      case 'pt':
        return 'Português';
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      default:
        return 'Português';
    }
  }

  /// Get display name of the language in its own language
  String getLanguageNameFromCode(String code) {
    switch (code) {
      case 'pt':
        return 'Português';
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      default:
        return 'Unknown';
    }
  }
}

/// Provider for the locale state
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  // Watch the imported, centralized provider
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocaleNotifier(prefs);
});
