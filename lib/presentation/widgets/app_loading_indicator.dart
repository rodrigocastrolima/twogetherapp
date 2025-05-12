import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async'; // Import for Timer

/// A reusable loading indicator widget that shows the company logo centered
/// and periodically rotating around the Y-axis on a solid background (white/primary).
class AppLoadingIndicator extends StatefulWidget {
  /// Creates an instance of [AppLoadingIndicator].
  const AppLoadingIndicator({super.key});

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      // Slower duration for the flip animation
      duration: const Duration(milliseconds: 2000), // Increased from 800ms
      vsync: this,
    );

    // Start the first animation
    _controller.forward();

    // Listen for completion to schedule the next run
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Start a timer for a 1-second pause before the next animation
        _timer = Timer(const Duration(seconds: 1), () {
          // Pause for exactly 1 second
          if (mounted) {
            // Check if the widget is still in the tree
            _controller.forward(from: 0.0); // Restart animation from beginning
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer if it's active
    _controller.dispose(); // Dispose the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Choose the appropriate logo based on the theme
    final logoAssetPath =
        isDarkMode
            ? 'assets/images/twogether_logo_dark_br.png'
            : 'assets/images/twogether_logo_light_br.png';

    // Choose the background color based on the theme
    final backgroundColor =
        isDarkMode ? theme.colorScheme.primary : Colors.white;
    // Use the contrasting color for the logo if needed, or adjust logo assets
    final logoColorFilter =
        isDarkMode
            ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
            : null; // Example: make dark logo white on primary background

    return Container(
      // Fill the available space
      width: double.infinity,
      height: double.infinity,
      color: backgroundColor,
      child: Center(
        // Use AnimatedBuilder to apply the 3D rotation
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform(
              // Apply rotation around the Y-axis
              transform:
                  Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // Add a little perspective
                    ..rotateY(
                      _controller.value * 2 * math.pi,
                    ), // Full 360 degrees
              alignment: FractionalOffset.center,
              child: child,
            );
          },
          child: Image.asset(
            logoAssetPath,
            height: 160, // Adjust height as needed
            width: 400, // Adjust width as needed
            // Apply color filter if necessary for dark mode visibility
            // color: isDarkMode ? Colors.white : null, // Alternative way to color
            // colorBlendMode: isDarkMode ? BlendMode.srcIn : null,
          ),
        ),
      ),
    );
  }
}
