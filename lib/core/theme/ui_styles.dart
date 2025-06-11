import 'package:flutter/material.dart';
import 'dart:ui';
import 'app_colors.dart';

/// Common UI styles shared across the application
/// Now using the unified AppColors system with mirrored themes
class AppStyles {
  // Background gradients (simplified to use logo colors)
  static LinearGradient mainGradient(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 1.0],
          colors: [
            AppColors.surfaceVariant(brightness),
            AppColors.background(brightness),
          ],
        )
        : LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 1.0],
          colors: [
            AppColors.background(brightness),
            AppColors.surfaceVariant(brightness),
          ],
        );
  }

  // Blur effects
  static ImageFilter get standardBlur =>
      ImageFilter.blur(sigmaX: 10, sigmaY: 10);
  static ImageFilter get strongBlur => ImageFilter.blur(sigmaX: 15, sigmaY: 15);

  // Container styles using new color system
  static BoxDecoration glassCard(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return BoxDecoration(
      color: AppColors.withOpacity(AppColors.surface(brightness), 0.8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: AppColors.border(brightness),
        width: 0.5,
      ),
    );
  }

  static BoxDecoration glassCardWithHighlight({
    required bool isHighlighted,
    required BuildContext context,
  }) {
    final brightness = Theme.of(context).brightness;
    return BoxDecoration(
      color: isHighlighted
          ? AppColors.withOpacity(AppColors.primaryAccent(brightness), 0.1)
          : AppColors.withOpacity(AppColors.surface(brightness), 0.8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isHighlighted
            ? AppColors.primaryAccent(brightness)
            : AppColors.border(brightness),
        width: isHighlighted ? 1.0 : 0.5,
      ),
    );
  }

  static BoxDecoration sidebarDecoration(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return BoxDecoration(
      color: AppColors.withOpacity(AppColors.surface(brightness), 0.95),
      border: Border(
        right: BorderSide(
          color: AppColors.border(brightness),
          width: 1,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.withOpacity(AppColors.foreground(brightness), 0.05),
          blurRadius: 10,
          offset: const Offset(0, 0),
        ),
      ],
    );
  }

  // Badge styles
  static BoxDecoration get notificationBadge =>
      const BoxDecoration(color: Color(0xFFFFBE45), shape: BoxShape.circle);

  static BoxDecoration primaryBadge(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return BoxDecoration(
      color: AppColors.primary(brightness),
      shape: BoxShape.circle,
    );
  }

  static TextStyle badgeTextStyle(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return TextStyle(
      color: AppColors.onPrimary(brightness),
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );
  }

  // Button styles
  static BoxDecoration circularButton(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return BoxDecoration(
      color: AppColors.surface(brightness),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: AppColors.border(brightness),
        width: 0.5,
      ),
    );
  }

  // Input field styles
  static BoxDecoration inputField(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return BoxDecoration(
      color: AppColors.input(brightness),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppColors.border(brightness),
      ),
    );
  }

  // Input decoration using new color system
  static InputDecoration searchInputDecoration(BuildContext context, String hintText) {
    final brightness = Theme.of(context).brightness;
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: AppColors.foregroundMuted(brightness),
        fontSize: 14,
      ),
      prefixIcon: Icon(
        Icons.search,
        color: AppColors.foregroundMuted(brightness),
        size: 20,
      ),
      filled: true,
      fillColor: AppColors.input(brightness),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border(brightness)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border(brightness)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary(brightness), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  // Item decorations
  static BoxDecoration activeItemHighlight(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return BoxDecoration(
      color: AppColors.withOpacity(AppColors.primary(brightness), 0.1),
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
    final brightness = Theme.of(context).brightness;
    return BoxDecoration(
      color: AppColors.input(brightness),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppColors.border(brightness),
        width: 0.5,
      ),
    );
  }

  // Consistent card shadow for all cards
  static List<BoxShadow> cardShadow(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return [
      BoxShadow(
        color: AppColors.withOpacity(AppColors.foreground(brightness), 0.1),
        blurRadius: 6,
        offset: const Offset(0, 3),
      ),
    ];
  }

  // Reusable solid card style for app-wide use
  static BoxDecoration solidCard(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return BoxDecoration(
      color: AppColors.surface(brightness),
      borderRadius: BorderRadius.circular(14),
      boxShadow: cardShadow(context),
    );
  }

  static ButtonStyle glassButtonStyle(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return OutlinedButton.styleFrom(
      backgroundColor: AppColors.withOpacity(AppColors.surface(brightness), 0.8),
      foregroundColor: AppColors.foreground(brightness),
      side: BorderSide(
        color: AppColors.border(brightness),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
      elevation: 0,
    ).copyWith(
      overlayColor: WidgetStateProperty.all(
        AppColors.withOpacity(AppColors.primary(brightness), 0.08),
      ),
    );
  }
}

/// Scrollbar behavior that removes scrollbars
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

/// Chat theme extension using new color system
extension ChatTheme on ThemeData {
  Color get messageBubbleSent => AppColors.primaryAccent(brightness);
  Color get messageBubbleReceived => AppColors.surfaceVariant(brightness);
  Color get messageBubbleTextSent => AppColors.logoWhite;
  Color get messageBubbleTextReceived => AppColors.foreground(brightness);
}
