import 'package:flutter/material.dart';
import 'dart:ui';
import 'theme.dart';
import 'colors.dart';

/// Common UI styles shared across the application
class AppStyles {
  // Background gradients
  static LinearGradient mainGradient(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 1.0],
          colors: [AppTheme.lightGradientStart, AppTheme.lightGradientEnd],
        )
        : const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 1.0],
          colors: [AppTheme.darkGradientStart, AppTheme.darkGradientEnd],
        );
  }

  // Blur effects
  static ImageFilter get standardBlur =>
      ImageFilter.blur(sigmaX: 10, sigmaY: 10);
  static ImageFilter get strongBlur => ImageFilter.blur(sigmaX: 15, sigmaY: 15);

  // Container styles
  static BoxDecoration glassCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(20),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? Colors.white.withAlpha(15) : Colors.white.withAlpha(26),
        width: 0.5,
      ),
    );
  }

  static BoxDecoration glassCardWithHighlight({
    required bool isHighlighted,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color:
          isHighlighted
              ? (isDark
                  ? Colors.white.withAlpha(15)
                  : Colors.white.withAlpha(30))
              : (isDark
                  ? Colors.white.withAlpha(10)
                  : Colors.white.withAlpha(20)),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color:
            isHighlighted
                ? Colors.amber.withAlpha(isDark ? 100 : 128)
                : (isDark
                    ? Colors.white.withAlpha(15)
                    : Colors.white.withAlpha(26)),
        width: isHighlighted ? 1.0 : 0.5,
      ),
    );
  }

  static BoxDecoration sidebarDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color:
          isDark
              ? Colors.black.withAlpha((255 * 0.3).round())
              : Colors.white.withAlpha((255 * 0.3).round()),
      border: Border(
        right: BorderSide(
          color:
              isDark
                  ? Colors.white.withAlpha((255 * 0.05).round())
                  : Colors.black.withAlpha((255 * 0.1).round()),
          width: 1,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color:
              isDark
                  ? Colors.black.withAlpha((255 * 0.2).round())
                  : Colors.black.withAlpha((255 * 0.05).round()),
          blurRadius: 10,
          offset: const Offset(0, 0),
        ),
      ],
    );
  }

  // Badge styles
  static BoxDecoration get notificationBadge =>
      const BoxDecoration(color: Colors.red, shape: BoxShape.circle);

  static BoxDecoration adminNotificationBadge(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
      shape: BoxShape.circle,
    );
  }

  static TextStyle badgeTextStyle(BuildContext context) {
    return const TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );
  }

  // Button styles
  static BoxDecoration circularButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? Colors.white.withAlpha(15) : Colors.white.withAlpha(26),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isDark ? Colors.white.withAlpha(15) : Colors.white.withAlpha(26),
        width: 0.5,
      ),
    );
  }

  // Input field styles
  static BoxDecoration inputField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(20),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark ? Colors.white.withAlpha(15) : Colors.white.withAlpha(26),
      ),
    );
  }

  // Item decorations
  static BoxDecoration activeItemHighlight(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color:
          isDark
              ? Colors.white.withAlpha((255 * 0.05).round())
              : Colors.black.withAlpha((255 * 0.05).round()),
      borderRadius: BorderRadius.circular(8),
    );
  }

  // Common constraints
  static const double sidebarWidth = 250.0;
  static const double badgeSize = 16.0;
  static const double navBarHeight = 84.0;

  // Common paddings
  static const EdgeInsets standardCardPadding = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 12.0,
  );
  static const EdgeInsets contentPadding = EdgeInsets.all(24.0);

  /// Container styles for input fields
  static BoxDecoration inputContainer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(20),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark ? Colors.white.withAlpha(15) : Colors.white.withAlpha(26),
        width: 0.5,
      ),
    );
  }
}

/// Custom ScrollBehavior that removes scrollbars
class NoScrollbarBehavior extends ScrollBehavior {
  const NoScrollbarBehavior();

  @override
  Widget buildViewportChrome(
    BuildContext context,
    Widget child,
    AxisDirection axisDirection,
  ) {
    return child;
  }

  /// Helper method to quickly wrap any scrollable with no-scrollbar behavior
  static Widget noScrollbars(BuildContext context, Widget child) {
    return ScrollConfiguration(
      behavior: const NoScrollbarBehavior(),
      child: child,
    );
  }
}
