import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart'; // Import the constants file

// Theme mode provider and notifier to manage app theme state
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light) {
    _loadTheme();
  }

  // Load saved theme preference
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool(AppConstants.themePreferenceKey) ?? false;
    state = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  // Toggle between light and dark themes
  Future<void> toggleTheme() async {
    final oldState = state;
    final newState =
        state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    if (kDebugMode) {
      print('[ThemeNotifier] Toggling theme from $oldState to $newState');
    }
    state = newState;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        AppConstants.themePreferenceKey,
        newState == ThemeMode.dark,
      );
      if (kDebugMode) {
        print(
          '[ThemeNotifier] Saved theme preference: ${newState == ThemeMode.dark}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ThemeNotifier] Error saving theme preference: $e');
      }
    }
  }

  // Set theme to a specific value
  Future<void> setTheme(ThemeMode themeMode) async {
    final oldState = state;
    if (kDebugMode) {
      print('[ThemeNotifier] Setting theme from $oldState to $themeMode');
    }
    state = themeMode;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        AppConstants.themePreferenceKey,
        themeMode == ThemeMode.dark,
      );
      if (kDebugMode) {
        print(
          '[ThemeNotifier] Saved theme preference: ${themeMode == ThemeMode.dark}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ThemeNotifier] Error saving theme preference: $e');
      }
    }
  }

  // Check if current theme is dark
  bool get isDarkMode => state == ThemeMode.dark;

  // Get theme name for display
  String getThemeName() {
    return isDarkMode ? 'Dark' : 'Light';
  }
}
