import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:twogether/features/auth/presentation/providers/auth_provider.dart';
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
  void dispose() {
    if (kDebugMode) {
      print('Disposing NotificationOverlayManager and notification service...');
    }
    ref.read(notificationServiceProvider).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final service = ref.read(notificationServiceProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final currentUser = FirebaseAuth.instance.currentUser;

      if (isAuthenticated && currentUser != null) {
        if (kDebugMode)
          print(
            'NotificationOverlayManager: Auth change detected - User authenticated (${currentUser.uid}). Starting listeners.',
          );
        service.startListeningForUser(context, currentUser.uid);
      } else {
        if (kDebugMode)
          print(
            'NotificationOverlayManager: Auth change detected - User logged out. Stopping listeners.',
          );
        service.stopListening();
      }
    });

    return widget.child;
  }
}
