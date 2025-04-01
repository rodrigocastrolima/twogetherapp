import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light theme colors
  static const background = Color(0xFFFFFFFF);
  static const foreground = Color(0xFF0A0E17);
  static const primary = Color(0xFF1A2337);
  static const primaryForeground = Color(0xFFF2F7FD);
  static const secondary = Color(0xFFF4F7FB);
  static const secondaryForeground = Color(0xFF1A2337);
  static const muted = Color(0xFFF4F7FB);
  static const mutedForeground = Color(0xFF687083);
  static const accent = Color(0xFFF4F7FB);
  static const accentForeground = Color(0xFF1A2337);
  static const destructive = Color(0xFFE94E4E);
  static const destructiveForeground = Color(0xFFF2F7FD);
  static const border = Color(0xFFE5EAF0);
  static const input = Color(0xFFE5EAF0);
  static const ring = Color(0xFF0A0E17);

  // Dark theme colors
  static const darkBackground = Color(0xFF121212);
  static const darkForeground = Color(0xFFF5F5F6);
  static const darkPrimary = Color(0xFF3B82F6); // Brighter blue for dark mode
  static const darkPrimaryForeground = Color(0xFFF8FAFC);
  static const darkSecondary = Color(0xFF232530);
  static const darkSecondaryForeground = Color(0xFFF8FAFC);
  static const darkMuted = Color(0xFF2A2B37);
  static const darkMutedForeground = Color(0xFF9CA3AF);
  static const darkAccent = Color(0xFF3B82F6);
  static const darkAccentForeground = Color(0xFFF8FAFC);
  static const darkBorder = Color(0xFF383A4E);
  static const darkInput = Color(0xFF1F2029);

  // Gradient colors
  static const lightGradientStart = Color(0xFF7CBAE3); // Light blue at top
  static const lightGradientEnd = Color(
    0xFFE1F4FD,
  ); // Very light blue at bottom

  // Dark gradient - darker versions of the light gradient
  static const darkGradientStart = Color(0xFF2A4E72); // Dark blue at top
  static const darkGradientEnd = Color(
    0xFF3A6491,
  ); // Medium-dark blue at bottom

  static const double radius = 8.0;

  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        surface: background,
        onSurface: foreground,
        primary: primary,
        onPrimary: primaryForeground,
        secondary: secondary,
        onSecondary: secondaryForeground,
        error: destructive,
        onError: destructiveForeground,
        background: background,
        onBackground: foreground,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      scaffoldBackgroundColor: background,
      cardTheme: CardTheme(
        color: background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: input,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: primaryForeground,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        surface: darkInput,
        onSurface: darkForeground,
        primary: darkPrimary,
        onPrimary: darkPrimaryForeground,
        secondary: darkSecondary,
        onSecondary: darkSecondaryForeground,
        error: destructive,
        onError: darkForeground,
        background: darkBackground,
        onBackground: darkForeground,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkForeground,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: darkSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: darkBorder.withAlpha(128)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: darkPrimary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: destructive),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      iconTheme: const IconThemeData(color: darkMutedForeground),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkPrimaryForeground,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkPrimary,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}
