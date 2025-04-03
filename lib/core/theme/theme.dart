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
  static const darkBackground = Color(0xFF0A192F); // Deep dark blue
  static const darkNavBarBackground = Color(
    0xFF061324,
  ); // Slightly darker blue for nav
  static const darkForeground = Color(0xFFE0E0E0); // Light gray for text
  static const darkPrimary = Color(
    0xFF60A5FA,
  ); // Lighter blue for primary actions
  static const darkPrimaryForeground = Color(
    0xFF0A192F,
  ); // Dark blue text on primary
  static const darkSecondary = Color(0xFF1E293B); // Dark grayish blue
  static const darkSecondaryForeground = Color(
    0xFFE0E0E0,
  ); // Light gray text on secondary
  static const darkMuted = Color(0xFF334155); // Muted dark blue/gray
  static const darkMutedForeground = Color(0xFF94A3B8); // Lighter muted text
  static const darkAccent = Color(0xFF60A5FA); // Same as primary for accent
  static const darkAccentForeground = Color(0xFF0A192F); // Dark text on accent
  static const darkBorder = Color(0xFF1E293B); // Match secondary for borders
  static const darkInput = Color(0xFF1E293B); // Match secondary for inputs

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
        surface: darkSecondary, // Use secondary for card/surface backgrounds
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
        backgroundColor: darkBackground, // Use main dark background
        foregroundColor: darkForeground,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: darkSecondary, // Use secondary color for cards
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: darkBorder), // Use dark border
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInput, // Use dark input color
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: darkBorder), // Use dark border
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: darkBorder.withAlpha(128),
          ), // Slightly lighter border
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(
            color: darkPrimary,
          ), // Primary color for focus
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: destructive),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(
          color: darkMutedForeground,
        ), // Muted color for labels
        hintStyle: const TextStyle(
          color: darkMutedForeground,
        ), // Muted color for hints
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: darkForeground, displayColor: darkForeground),
      iconTheme: const IconThemeData(
        color: darkMutedForeground,
      ), // Muted icon color
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return darkPrimary;
          }
          return darkMuted; // Off state color
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return darkPrimary.withOpacity(0.5);
          }
          return darkMuted.withOpacity(0.5); // Off state track color
        }),
      ),
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
