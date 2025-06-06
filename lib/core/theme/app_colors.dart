import 'package:flutter/material.dart';

/// Unified color system based on company logo colors
/// Implements a mirrored theme approach where light and dark modes
/// use the same colors but with reversed semantic roles
class AppColors {
  // === FOUNDATION COLORS (from company logo) ===
  static const Color logoWhite = Color(0xFFFFFFFF);
  static const Color logoLightGray = Color(0xFFF1F1F1);
  static const Color logoSoftGray = Color(0xFFCFCFCF);
  static const Color logoMediumGray = Color(0xFF7E7E7E);
  static const Color logoDarkGray = Color(0xFF2B2B2B);
  static const Color logoBlack = Color(0xFF000000);

  // === ACCENT COLORS ===
  // Success (green family)
  static const Color successLight = Color(0xFF22C55E);
  static const Color successDark = Color(0xFF4ADE80);
  
  // Warning (amber family) 
  static const Color warningLight = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFFBBF24);
  
  // Destructive (red family)
  static const Color destructiveLight = Color(0xFFE94E4E);
  static const Color destructiveDark = Color(0xFFF87171);
  
  // Primary accent (blue family - keeping some brand flexibility)
  static const Color primaryAccentLight = Color(0xFF1976D2);
  static const Color primaryAccentDark = Color(0xFF60A5FA);

  // === SEMANTIC COLOR ROLES ===
  
  /// Background colors - the main canvas
  static const Color backgroundLight = logoWhite;
  static const Color backgroundDark = logoDarkGray;
  
  /// Surface colors - for cards, sheets, etc.
  static const Color surfaceLight = logoWhite;
  static const Color surfaceDark = Color(0xFF3A3A3A); // Slightly lighter than background
  
  /// Surface variant - for subtle differentiation
  static const Color surfaceVariantLight = logoSoftGray;
  static const Color surfaceVariantDark = Color(0xFF4A4A4A);
  
  /// Primary text and content
  static const Color foregroundLight = logoDarkGray;
  static const Color foregroundDark = logoLightGray;
  
  /// Secondary text and content
  static const Color foregroundVariantLight = logoMediumGray;
  static const Color foregroundVariantDark = logoSoftGray;
  
  /// Muted text and less important content
  static const Color foregroundMutedLight = logoMediumGray;
  static const Color foregroundMutedDark = logoMediumGray; // Same in both modes for consistency
  
  /// Border colors
  static const Color borderLight = logoSoftGray;
  static const Color borderDark = Color(0xFF4A4A4A);
  
  /// Input field backgrounds
  static const Color inputLight = logoWhite;
  static const Color inputDark = Color(0xFF3A3A3A);
  
  /// Primary action color (buttons, links, etc.)
  static const Color primaryLight = logoDarkGray;
  static const Color primaryDark = logoLightGray;
  
  /// Primary action foreground (text on primary)
  static const Color onPrimaryLight = logoWhite;
  static const Color onPrimaryDark = logoDarkGray;

  // === THEME GETTERS ===
  
  /// Get semantic colors for the current brightness
  static Color background(Brightness brightness) =>
      brightness == Brightness.light ? backgroundLight : backgroundDark;
      
  static Color surface(Brightness brightness) =>
      brightness == Brightness.light ? surfaceLight : surfaceDark;
      
  static Color surfaceVariant(Brightness brightness) =>
      brightness == Brightness.light ? surfaceVariantLight : surfaceVariantDark;
      
  static Color foreground(Brightness brightness) =>
      brightness == Brightness.light ? foregroundLight : foregroundDark;
      
  static Color foregroundVariant(Brightness brightness) =>
      brightness == Brightness.light ? foregroundVariantLight : foregroundVariantDark;
      
  static Color foregroundMuted(Brightness brightness) =>
      foregroundMutedLight; // Same in both modes
      
  static Color border(Brightness brightness) =>
      brightness == Brightness.light ? borderLight : borderDark;
      
  static Color input(Brightness brightness) =>
      brightness == Brightness.light ? inputLight : inputDark;
      
  static Color primary(Brightness brightness) =>
      brightness == Brightness.light ? primaryLight : primaryDark;
      
  static Color onPrimary(Brightness brightness) =>
      brightness == Brightness.light ? onPrimaryLight : onPrimaryDark;
      
  static Color success(Brightness brightness) =>
      brightness == Brightness.light ? successLight : successDark;
      
  static Color warning(Brightness brightness) =>
      brightness == Brightness.light ? warningLight : warningDark;
      
  static Color destructive(Brightness brightness) =>
      brightness == Brightness.light ? destructiveLight : destructiveDark;
      
  static Color primaryAccent(Brightness brightness) =>
      brightness == Brightness.light ? primaryAccentLight : primaryAccentDark;

  // === UTILITY METHODS ===
  
  /// Get color with opacity
  static Color withOpacity(Color color, double opacity) =>
      color.withAlpha((255 * opacity).round());
      
  /// Get surface elevation color (subtle differentiation)
  static Color surfaceElevation(Brightness brightness) =>
      brightness == Brightness.light 
          ? withOpacity(logoDarkGray, 0.02)
          : withOpacity(logoWhite, 0.05);
} 