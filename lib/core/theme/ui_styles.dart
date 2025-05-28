import 'package:flutter/material.dart';
import 'dart:ui';
import 'theme.dart';

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

  // Consistent card shadow for all cards (matches notification card)
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 6,
      offset: const Offset(0, 3),
    ),
  ];

  // Reusable solid card style for app-wide use
  static BoxDecoration solidCard(BuildContext context) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      boxShadow: cardShadow,
    );
  }

  static ButtonStyle glassButtonStyle(BuildContext context) {
    return OutlinedButton.styleFrom(
      backgroundColor: Colors.white.withOpacity(0.10),
      foregroundColor: Colors.white,
      side: BorderSide(color: Colors.white.withOpacity(0.25), width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
      elevation: 0,
    ).copyWith(
      overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.08)),
    );
  }

  static BoxDecoration circularIconButtonStyle(BuildContext context, {bool isHighlighted = false, bool isHovering = false}) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surface.withOpacity(0.15);
    final hoverColor = theme.colorScheme.surface.withOpacity(0.3);
    final highlightColor = theme.colorScheme.primary.withOpacity(0.85);
    final color = isHighlighted
        ? highlightColor
        : isHovering
            ? hoverColor
            : baseColor;
    final borderColor = isHighlighted
        ? theme.colorScheme.primary
        : isHovering
            ? Colors.white.withOpacity(0.3)
            : Colors.white.withOpacity(0.1);
    final boxShadow = isHighlighted
        ? [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
        : isHovering
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ];
    return BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: borderColor, width: 0.5),
      boxShadow: boxShadow,
    );
  }

  static InputDecoration searchInputDecoration(BuildContext context, String hintText) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hintText,
      hintStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
      ),
      filled: true,
      fillColor: theme.colorScheme.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      prefixIcon: Icon(
        Icons.search,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.18), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.18), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6), width: 1.5),
      ),
    );
  }
}

/// Custom ScrollBehavior that removes scrollbars
class NoScrollbarBehavior extends ScrollBehavior {
  const NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Return child directly to remove scrollbar
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Return child directly to remove overscroll indicator
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

extension ChatTheme on ThemeData {
  Color get messageBubbleSent => const Color(0xFF0B84FE); // iPhone blue
  Color get messageBubbleReceived =>
      brightness == Brightness.dark
          ? colorScheme.surfaceVariant.withOpacity(0.7)
          : const Color(0xFFE9E9EB);
  Color get messageBubbleTextSent => Colors.white;
  Color get messageBubbleTextReceived =>
      brightness == Brightness.dark
          ? colorScheme.onSurfaceVariant
          : colorScheme.onSurface;
}
