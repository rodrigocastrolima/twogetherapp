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
  ThemeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  // Load saved theme preference
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(AppConstants.themePreferenceKey) ?? 0;
    // 0 = system, 1 = light, 2 = dark
    switch (themeIndex) {
      case 1:
        state = ThemeMode.light;
        break;
      case 2:
        state = ThemeMode.dark;
        break;
      default:
        state = ThemeMode.system;
    }
  }

  // Cycle through theme modes: system -> light -> dark -> system
  Future<void> toggleTheme() async {
    final oldState = state;
    late ThemeMode newState;
    
    switch (state) {
      case ThemeMode.system:
        newState = ThemeMode.light;
        break;
      case ThemeMode.light:
        newState = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        newState = ThemeMode.system;
        break;
    }
    
    if (kDebugMode) {
      print('[ThemeNotifier] Toggling theme from $oldState to $newState');
    }
    state = newState;

    try {
      final prefs = await SharedPreferences.getInstance();
      int themeIndex;
      switch (newState) {
        case ThemeMode.light:
          themeIndex = 1;
          break;
        case ThemeMode.dark:
          themeIndex = 2;
          break;
        default:
          themeIndex = 0; // system
      }
      
      await prefs.setInt(AppConstants.themePreferenceKey, themeIndex);
      if (kDebugMode) {
        print('[ThemeNotifier] Saved theme preference: $themeIndex');
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
      int themeIndex;
      switch (themeMode) {
        case ThemeMode.light:
          themeIndex = 1;
          break;
        case ThemeMode.dark:
          themeIndex = 2;
          break;
        default:
          themeIndex = 0; // system
      }
      
      await prefs.setInt(AppConstants.themePreferenceKey, themeIndex);
      if (kDebugMode) {
        print('[ThemeNotifier] Saved theme preference: $themeIndex');
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
    switch (state) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Escuro';
      case ThemeMode.system:
        return 'Sistema';
    }
  }
}
