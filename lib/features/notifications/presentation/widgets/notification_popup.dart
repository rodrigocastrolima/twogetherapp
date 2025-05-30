import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/notification.dart';
import '../../presentation/providers/notification_provider.dart';
import '../../../../features/notifications/presentation/widgets/unified_notification_item.dart';

class NotificationPopup extends ConsumerWidget {
  final UserNotification notification;
  final VoidCallback? onDismiss;

  const NotificationPopup({
    super.key,
    required this.notification,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Delete the notification when tapped
          ref
              .read(notificationActionsProvider)
              .deleteNotification(notification.id);

          // Call the additional dismiss callback if provided
          onDismiss?.call();
        },
        child: UnifiedNotificationItem(
          notification: notification,
          onTap: () {
            ref.read(notificationActionsProvider).deleteNotification(notification.id);
            onDismiss?.call();
          },
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }
}
