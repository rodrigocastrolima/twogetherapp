import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';

/// A widget that provides overlay support for popup notifications.
/// Wrap your app with this widget to enable popup notifications.
class NotificationOverlayManager extends ConsumerStatefulWidget {
  final Widget child;

  const NotificationOverlayManager({Key? key, required this.child})
    : super(key: key);

  @override
  ConsumerState<NotificationOverlayManager> createState() =>
      _NotificationOverlayManagerState();
}

class _NotificationOverlayManagerState
    extends ConsumerState<NotificationOverlayManager> {
  @override
  void initState() {
    super.initState();

    // Initialize the notification service after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kDebugMode) {
        print('Initializing notification service...');
      }

      final service = ref.read(notificationServiceProvider);
      service.initialize(context);

      if (kDebugMode) {
        print('Notification service initialized successfully');
      }
    });
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('Disposing notification service...');
    }
    ref.read(notificationServiceProvider).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Simply return the child widget - the overlay entries will be added via the service
    return widget.child;
  }
}
