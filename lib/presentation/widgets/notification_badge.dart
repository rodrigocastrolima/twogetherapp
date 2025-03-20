import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

class NotificationBadge extends StatelessWidget {
  final bool hasNotifications;
  final VoidCallback onTap;

  const NotificationBadge({
    super.key,
    required this.hasNotifications,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: AppTheme.foreground),
          onPressed: onTap,
        ),
        if (hasNotifications)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.destructive,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
      ],
    );
  }
}
