import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Application theme based on unified color system
class AppTheme {
  static const double radius = 8.0;

  /// Create the light theme using the unified color system
  static ThemeData light() {
    const brightness = Brightness.light;
    
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        // Core colors
        surface: AppColors.surface(brightness),
        onSurface: AppColors.foreground(brightness),
        background: AppColors.background(brightness),
        onBackground: AppColors.foreground(brightness),
        
        // Primary colors
        primary: AppColors.primary(brightness),
        onPrimary: AppColors.onPrimary(brightness),
        
        // Secondary colors (using surface variant)
        secondary: AppColors.surfaceVariant(brightness),
        onSecondary: AppColors.foreground(brightness),
        
        // Surface variants
        surfaceVariant: AppColors.surfaceVariant(brightness),
        onSurfaceVariant: AppColors.foregroundVariant(brightness),
        surfaceContainerHighest: AppColors.surfaceVariant(brightness),
        
        // Status colors
        error: AppColors.destructive(brightness),
        onError: AppColors.onPrimary(brightness),
        tertiary: AppColors.success(brightness),
        onTertiary: AppColors.onPrimary(brightness),
        tertiaryContainer: AppColors.warning(brightness),
        onTertiaryContainer: AppColors.onPrimary(brightness),
        
        // Border and outline
        outline: AppColors.border(brightness),
        outlineVariant: AppColors.foregroundMuted(brightness),
      ),
      
      // Scaffold
      scaffoldBackgroundColor: AppColors.background(brightness),
      
      // Text theme
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: AppColors.foreground(brightness),
        displayColor: AppColors.foreground(brightness),
      ),
      
      // App bar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background(brightness),
        foregroundColor: AppColors.foreground(brightness),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      
      // Cards
      cardTheme: CardTheme(
        color: AppColors.surface(brightness),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: AppColors.border(brightness)),
        ),
      ),
      
      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.input(brightness),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: AppColors.border(brightness)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: AppColors.border(brightness)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: AppColors.primary(brightness), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: AppColors.destructive(brightness)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: AppColors.foregroundVariant(brightness)),
        hintStyle: TextStyle(color: AppColors.foregroundMuted(brightness)),
      ),
      
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary(brightness),
          foregroundColor: AppColors.onPrimary(brightness),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          elevation: 0,
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary(brightness),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary(brightness),
          side: BorderSide(color: AppColors.border(brightness)),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      
      // Icons
      iconTheme: IconThemeData(color: AppColors.foregroundVariant(brightness)),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: AppColors.border(brightness),
        thickness: 1,
      ),
      
      // Switch - Improved for light mode
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary(brightness);
          }
          return AppColors.surface(brightness); // White thumb when unselected
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.withOpacity(AppColors.primary(brightness), 0.5);
          }
          return AppColors.border(brightness); // Solid border color when unselected
        }),
      ),
      
      // Popup menu
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface(brightness),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        elevation: 4,
        textStyle: TextStyle(color: AppColors.foreground(brightness)),
      ),
      
      // Dropdown menu
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          fillColor: AppColors.surface(brightness),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: BorderSide(color: AppColors.border(brightness)),
          ),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(AppColors.surface(brightness)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          ),
        ),
      ),
    );
  }

  /// Create the dark theme using the unified color system
  static ThemeData dark() {
    const brightness = Brightness.dark;
    
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        // Core colors
        surface: AppColors.surface(brightness),
        onSurface: AppColors.foreground(brightness),
        background: AppColors.background(brightness),
        onBackground: AppColors.foreground(brightness),
        
        // Primary colors
        primary: AppColors.primary(brightness),
        onPrimary: AppColors.onPrimary(brightness),
        
        // Secondary colors (using surface variant)
        secondary: AppColors.surfaceVariant(brightness),
        onSecondary: AppColors.foreground(brightness),
        
        // Surface variants
        surfaceVariant: AppColors.surfaceVariant(brightness),
        onSurfaceVariant: AppColors.foregroundVariant(brightness),
        surfaceContainerHighest: AppColors.surfaceVariant(brightness),
        
        // Status colors
        error: AppColors.destructive(brightness),
        onError: AppColors.onPrimary(brightness),
        tertiary: AppColors.success(brightness),
        onTertiary: AppColors.onPrimary(brightness),
        tertiaryContainer: AppColors.warning(brightness),
        onTertiaryContainer: AppColors.onPrimary(brightness),
        
        // Border and outline
        outline: AppColors.border(brightness),
        outlineVariant: AppColors.foregroundMuted(brightness),
      ),
      
      // Scaffold
      scaffoldBackgroundColor: AppColors.background(brightness),
      
      // Text theme
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: AppColors.foreground(brightness),
        displayColor: AppColors.foreground(brightness),
      ),
      
      // App bar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background(brightness),
        foregroundColor: AppColors.foreground(brightness),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      
      // Cards
      cardTheme: CardTheme(
        color: AppColors.surface(brightness),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: AppColors.border(brightness)),
        ),
      ),
      
      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.input(brightness),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: AppColors.border(brightness)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: AppColors.border(brightness)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: AppColors.primary(brightness), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: AppColors.destructive(brightness)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: AppColors.foregroundVariant(brightness)),
        hintStyle: TextStyle(color: AppColors.foregroundMuted(brightness)),
      ),
      
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary(brightness),
          foregroundColor: AppColors.onPrimary(brightness),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          elevation: 0,
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary(brightness),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary(brightness),
          side: BorderSide(color: AppColors.border(brightness)),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      
      // Icons
      iconTheme: IconThemeData(color: AppColors.foregroundVariant(brightness)),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: AppColors.border(brightness),
        thickness: 1,
      ),
      
      // Switch - Improved for dark mode
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary(brightness);
          }
          return AppColors.foregroundMuted(brightness); // Grey thumb when unselected
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.withOpacity(AppColors.primary(brightness), 0.5);
          }
          return AppColors.withOpacity(AppColors.foregroundMuted(brightness), 0.6); // More solid track when unselected
        }),
      ),
      
      // Popup menu
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface(brightness),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        elevation: 4,
        textStyle: TextStyle(color: AppColors.foreground(brightness)),
      ),
      
      // Dropdown menu
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          fillColor: AppColors.surface(brightness),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: BorderSide(color: AppColors.border(brightness)),
          ),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(AppColors.surface(brightness)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          ),
        ),
      ),
    );
  }

  // === LEGACY SUPPORT ===
  // These getters provide backward compatibility during migration
  // TODO: Remove these once all files are migrated to use AppColors directly
  
  static Color get background => AppColors.backgroundLight;
  static Color get foreground => AppColors.foregroundLight;
  static Color get primary => AppColors.primaryLight;
  static Color get primaryForeground => AppColors.onPrimaryLight;
  static Color get secondary => AppColors.surfaceLight;
  static Color get secondaryForeground => AppColors.foregroundLight;
  static Color get muted => AppColors.surfaceVariantLight;
  static Color get mutedForeground => AppColors.foregroundMutedLight;
  static Color get destructive => AppColors.destructiveLight;
  static Color get destructiveForeground => AppColors.onPrimaryLight;
  static Color get border => AppColors.borderLight;
  static Color get input => AppColors.inputLight;
  static Color get success => AppColors.successLight;
  static Color get warning => AppColors.warningLight;
  
  // Dark theme legacy colors
  static Color get darkBackground => AppColors.backgroundDark;
  static Color get darkForeground => AppColors.foregroundDark;
  static Color get darkPrimary => AppColors.primaryDark;
  static Color get darkPrimaryForeground => AppColors.onPrimaryDark;
  static Color get darkSecondary => AppColors.surfaceDark;
  static Color get darkSecondaryForeground => AppColors.foregroundDark;
  static Color get darkMuted => AppColors.surfaceVariantDark;
  static Color get darkMutedForeground => AppColors.foregroundMutedDark;
  static Color get darkDestructive => AppColors.destructiveDark;
  static Color get darkBorder => AppColors.borderDark;
  static Color get darkInput => AppColors.inputDark;
  static Color get darkSuccess => AppColors.successDark;
  static Color get darkWarning => AppColors.warningDark;
  
  // Navigation specific colors
  static Color get darkNavBarBackground => AppColors.surfaceDark;
  
  // Other legacy properties
  static Color get tulipTree => const Color(0xFFFFBE45); // Keep as accent
}
