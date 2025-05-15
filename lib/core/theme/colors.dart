import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const primary = Color(0xFF1976D2);
  static const primaryLight = Color(0xFF42A5F5);
  static const primaryDark = Color(0xFF1565C0);

  // Neutral colors
  static const charcoal = Color(0xFF2C2C2C);
  static const silver = Color(0xFF757575);
  static const lightGray = Color(0xFFF5F5F5);
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  // Alpha variants commonly used in the app
  static Color whiteWithOpacity(double opacity) => white.withOpacity(opacity);
  static Color blackWithOpacity(double opacity) => black.withOpacity(opacity);

  // Common white alpha variants
  static final whiteAlpha05 = white.withAlpha(13); // ~5%
  static final whiteAlpha10 = white.withAlpha(26); // ~10%
  static final whiteAlpha20 = white.withAlpha(51); // ~20%
  static final whiteAlpha30 = white.withAlpha(77); // ~30%
  static final whiteAlpha50 = white.withAlpha(128); // ~50%
  static final whiteAlpha70 = white.withAlpha(179); // ~70%
  static final whiteAlpha90 = white.withAlpha(230); // ~90%

  // Common black alpha variants
  static final blackAlpha05 = black.withOpacity(0.05);
  static final blackAlpha10 = black.withOpacity(0.1);
  static final blackAlpha20 = black.withOpacity(0.2);
  static final blackAlpha30 = black.withOpacity(0.3);
  static final blackAlpha50 = black.withOpacity(0.5);
  static final blackAlpha70 = black.withOpacity(0.7);
  static final blackAlpha90 = black.withOpacity(0.9);

  // Status colors
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFA726);
  static const error = Color(0xFFB00020);
  static const info = Color(0xFF2196F3);
  static const amber = Colors.amber;

  // Background colors
  static const background = Color(0xFFF5F5F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF121212);

  // Gradient colors
  static const gradientStart = Color(0xFFD4E0F7); // very soft light blue
  static const gradientMiddle = Color(0xFFB1CCF8); // soft sky blue
  static const gradientEnd = Color(0xFF9DB9F0); // light periwinkle blue

  // Brand highlight color (sidebar/nav highlight)
  static const tulipTree = Color(0xFFFFBE45); // Official yellow for highlights
}
