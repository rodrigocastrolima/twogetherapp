import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// A clean, minimalist full-screen loading overlay that displays
/// the company logo and a thin progress bar.
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool showLogo;
  final Color? backgroundColor;
  final Color? progressColor;

  const LoadingOverlay({
    Key? key,
    this.message,
    this.showLogo = true,
    this.backgroundColor,
    this.progressColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return WillPopScope(
      // Prevent back button during loading
      onWillPop: () async => false,
      child: Scaffold(
        // Use theme-aware background color
        backgroundColor:
            backgroundColor ?? (isDark ? Colors.black : Colors.white),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Company logo
              if (showLogo) ...[
                Image.asset(
                  // Select appropriate logo based on theme
                  isDark
                      ? 'assets/images/twogether_logo_dark_br.png'
                      : 'assets/images/twogether_logo_light_br.png',
                  height: 100,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 40),
              ],

              // Thin linear progress indicator
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressColor ?? AppTheme.primary,
                  ),
                ),
              ),

              // Optional message text
              if (message != null) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    message!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Shows the loading overlay as a modal dialog.
  static Future<void> show(
    BuildContext context, {
    String? message,
    bool showLogo = true,
    Color? backgroundColor,
    Color? progressColor,
    bool barrierDismissible = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.transparent,
      builder:
          (context) => LoadingOverlay(
            message: message,
            showLogo: showLogo,
            backgroundColor: backgroundColor,
            progressColor: progressColor,
          ),
    );
  }

  /// Hides the currently displayed loading overlay.
  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
