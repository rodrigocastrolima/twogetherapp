import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_list_widget.dart';

class NotificationDropdown extends ConsumerWidget {
  final VoidCallback onClose;
  final double maxHeight;
  final double width;

  const NotificationDropdown({
    super.key,
    required this.onClose,
    this.maxHeight = 400,
    this.width = 350,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surface,
      child: Container(
        width: width,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Text(
                'Notificações',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14, // Slightly smaller
                ),
              ),
            ),
            // Notifications List
            Flexible(
              child: NotificationListWidget(
                onNotificationTap: onClose, // Close dropdown when notification is tapped
                maxItems: 10, // Limit to 10 items in dropdown
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 4),
                isCompact: true, // Use compact styling for dropdown
              ),
            ),
          ],
        ),
      ),
    );
  }
} 