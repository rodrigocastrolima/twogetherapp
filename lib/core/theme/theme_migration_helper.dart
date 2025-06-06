import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Migration helper to ease the transition to the new unified color system
/// This provides convenient methods to access colors using the current theme context
extension ThemeColors on BuildContext {
  /// Get the current theme brightness
  Brightness get brightness => Theme.of(this).brightness;
  
  /// Check if current theme is dark
  bool get isDarkMode => brightness == Brightness.dark;
  
  /// App color getters using current context brightness
  Color get appBackground => AppColors.background(brightness);
  Color get appSurface => AppColors.surface(brightness);
  Color get appSurfaceVariant => AppColors.surfaceVariant(brightness);
  Color get appForeground => AppColors.foreground(brightness);
  Color get appForegroundVariant => AppColors.foregroundVariant(brightness);
  Color get appForegroundMuted => AppColors.foregroundMuted(brightness);
  Color get appBorder => AppColors.border(brightness);
  Color get appInput => AppColors.input(brightness);
  Color get appPrimary => AppColors.primary(brightness);
  Color get appOnPrimary => AppColors.onPrimary(brightness);
  Color get appSuccess => AppColors.success(brightness);
  Color get appWarning => AppColors.warning(brightness);
  Color get appDestructive => AppColors.destructive(brightness);
  Color get appPrimaryAccent => AppColors.primaryAccent(brightness);
  
  /// Utility methods
  Color appColorWithOpacity(Color color, double opacity) =>
      AppColors.withOpacity(color, opacity);
}

/// Extension methods for Theme to provide backward compatibility
extension AppThemeColors on ThemeData {
  /// Quick access to app colors for the current theme
  Color get appBackground => AppColors.background(brightness);
  Color get appSurface => AppColors.surface(brightness);
  Color get appForeground => AppColors.foreground(brightness);
  Color get appPrimary => AppColors.primary(brightness);
  Color get appOnPrimary => AppColors.onPrimary(brightness);
  Color get appBorder => AppColors.border(brightness);
}

/// Helper class for consistent styling patterns
class ThemeHelpers {
  /// Get text color for the current theme
  static Color getTextColor(BuildContext context, {bool muted = false}) {
    final brightness = Theme.of(context).brightness;
    return muted 
        ? AppColors.foregroundMuted(brightness)
        : AppColors.foreground(brightness);
  }
  
  /// Get appropriate background color for cards/surfaces
  static Color getSurfaceColor(BuildContext context, {bool elevated = false}) {
    final brightness = Theme.of(context).brightness;
    return elevated 
        ? AppColors.surfaceVariant(brightness)
        : AppColors.surface(brightness);
  }
  
  /// Get border color for the current theme
  static Color getBorderColor(BuildContext context, {bool subtle = false}) {
    final brightness = Theme.of(context).brightness;
    return subtle
        ? AppColors.withOpacity(AppColors.border(brightness), 0.5)
        : AppColors.border(brightness);
  }
  
  /// Create a text style with appropriate color for the current theme
  static TextStyle createTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    bool muted = false,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: getTextColor(context, muted: muted),
    );
  }
  
  /// Create a consistent button style
  static ButtonStyle createButtonStyle(
    BuildContext context, {
    bool isPrimary = true,
    bool isOutlined = false,
  }) {
    final brightness = Theme.of(context).brightness;
    
    if (isOutlined) {
      return OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary(brightness),
        side: BorderSide(color: AppColors.border(brightness)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );
    }
    
    return ElevatedButton.styleFrom(
      backgroundColor: isPrimary 
          ? AppColors.primary(brightness)
          : AppColors.surface(brightness),
      foregroundColor: isPrimary 
          ? AppColors.onPrimary(brightness)
          : AppColors.foreground(brightness),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

/// Quick access functions for common color operations
class QuickColors {
  /// Replace old AppTheme.isDark ? darkColor : lightColor patterns
  static Color adaptive(BuildContext context, {
    required Color lightColor,
    required Color darkColor,
  }) {
    return Theme.of(context).brightness == Brightness.light 
        ? lightColor 
        : darkColor;
  }
  
  /// Replace patterns like Colors.white.withOpacity() or Colors.black.withOpacity()
  static Color surfaceOverlay(BuildContext context, double opacity) {
    final brightness = Theme.of(context).brightness;
    return AppColors.withOpacity(AppColors.surface(brightness), opacity);
  }
  
  /// Replace patterns for text colors
  static Color textPrimary(BuildContext context) => 
      AppColors.foreground(Theme.of(context).brightness);
      
  static Color textSecondary(BuildContext context) => 
      AppColors.foregroundVariant(Theme.of(context).brightness);
      
  static Color textMuted(BuildContext context) => 
      AppColors.foregroundMuted(Theme.of(context).brightness);
} 