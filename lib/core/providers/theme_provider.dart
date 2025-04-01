import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    state = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  // Toggle between light and dark themes
  Future<void> toggleTheme() async {
    final newState =
        state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = newState;

    // Save theme preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', newState == ThemeMode.dark);
  }

  // Set theme to a specific value
  Future<void> setTheme(ThemeMode themeMode) async {
    state = themeMode;

    // Save theme preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', themeMode == ThemeMode.dark);
  }

  // Check if current theme is dark
  bool get isDarkMode => state == ThemeMode.dark;

  // Get theme name for display
  String getThemeName() {
    return isDarkMode ? 'Dark' : 'Light';
  }
}
