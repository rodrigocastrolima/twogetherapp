import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart'; // Import for SVG

/// A reusable loading indicator widget that shows the company logo centered
/// and periodically rotating around the Y-axis on a solid background (white/primary).
class AppLoadingIndicator extends StatefulWidget {
  /// Creates an instance of [AppLoadingIndicator].
  const AppLoadingIndicator({super.key});

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _sweepController;
  late AnimationController _rotationController;
  late Animation<double> _sweepAngleAnimation;

  @override
  void initState() {
    super.initState();

    // Controller for the sweep angle (pulsating gap)
    _sweepController = AnimationController(
      duration: const Duration(milliseconds: 1500), // Faster, more dynamic feel
      vsync: this,
    )..repeat(reverse: true); // Repeat and reverse for a pulsating effect

    _sweepAngleAnimation = Tween<double>(
      begin: math.pi / 2.5, // Start with a 60-degree arc (large gap)
      end: math.pi * 1.8, // End with a ~324-degree arc (small gap)
    ).animate(
      CurvedAnimation(
        parent: _sweepController,
        curve: Curves.easeInOutSine, // Smooth, wobbly easing
      ),
    );

    // Controller for continuous rotation
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2), // Rotation speed
      vsync: this,
    )..repeat(); // Continuous rotation, no reverse
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Use theme.colorScheme.background for consistency with other app pages
    final backgroundColor = theme.colorScheme.background;
    final arcColor =
        isDarkMode
            ? Colors.white
            : Colors.black; // Arc is black in light mode, white in dark
    final logoColor =
        isDarkMode
            ? Colors.white
            : Colors.black; // Logo is black in light mode, white in dark

    const double logoSize = 180.0;
    const double arcDataSize =
        40.0; // Made arc smaller for under-logo placement
    const double spacing = 0; // Spacing between logo and arc

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Static SVG Logo
            SvgPicture.asset(
              'assets/images/twogether-retail_logo-04.svg',
              height: logoSize,
              width: logoSize,
              colorFilter: ColorFilter.mode(logoColor, BlendMode.srcIn),
            ),
            const SizedBox(height: spacing), // Spacing
            // Arc with animated sweep angle AND rotation
            AnimatedBuilder(
              animation: Listenable.merge([
                _sweepController,
                _rotationController,
              ]), // Listen to both
              builder: (context, child) {
                return Transform.rotate(
                  angle:
                      _rotationController.value *
                      2 *
                      math.pi, // Use rotation controller
                  child: CustomPaint(
                    size: const Size(arcDataSize, arcDataSize),
                    painter: _DynamicArcPainter(
                      color: arcColor,
                      strokeWidth: 1.5,
                      startAngle: -math.pi / 2, // Keep arc start at the top
                      sweepAngle:
                          _sweepAngleAnimation
                              .value, // Sweep angle from its own animation
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DynamicArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double startAngle;
  final double sweepAngle;

  _DynamicArcPainter({
    required this.color,
    required this.strokeWidth,
    required this.startAngle,
    required this.sweepAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(_DynamicArcPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.startAngle != startAngle ||
        oldDelegate.sweepAngle != sweepAngle;
  }
}
