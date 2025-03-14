import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';

class BaseLayout extends StatelessWidget {
  const BaseLayout({
    super.key,
    required this.child,
    this.showBackground = true,
  });

  final Widget child;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (showBackground) ...[
          Image.asset(
            'assets/images/bg.jpg',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
          // Semi-transparent overlay to ensure text readability
          Container(color: AppTheme.background.withOpacity(0.65)),
        ],
        // Main content
        child,
      ],
    );
  }
}
