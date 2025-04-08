import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/notification.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_popup.dart';

/// A service to manage popup notifications in the app
class NotificationService {
  final Ref _ref;
  OverlayEntry? _currentOverlay;
  final Set<String> _processedIds = {};
  StreamSubscription? _notificationSubscription;
  BuildContext? _context;

  NotificationService(this._ref);

  /// Initialize notification listening
  void initialize(BuildContext context) {
    try {
      if (kDebugMode) {
        print('NotificationService.initialize: Setting context');
      }

      _context = context;

      // Setup subscription to notifications stream
      if (kDebugMode) {
        print('NotificationService.initialize: Setting up notification stream');
      }

      final notificationRepo = _ref.read(notificationRepositoryProvider);
      final notificationsStream = notificationRepo.getUserNotifications();

      // Cancel existing subscription if any
      _notificationSubscription?.cancel();

      // Subscribe to the notifications stream
      _notificationSubscription = notificationsStream.listen(
        (notifications) {
          if (kDebugMode) {
            print('Received ${notifications.length} notifications');
          }

          // Process any new unread notifications
          for (final notification in notifications) {
            if (!_processedIds.contains(notification.id) &&
                !notification.isRead &&
                notification.type == NotificationType.statusChange) {
              if (kDebugMode) {
                print('Processing new notification: ${notification.title}');
              }

              _processedIds.add(notification.id);
              _showPopupNotification(context, notification);
              break; // Show only one at a time
            }
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('Error listening to notifications: $error');
          }
        },
      );

      if (kDebugMode) {
        print('NotificationService: Initialization complete');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing notification service: $e');
      }
    }
  }

  /// Show a popup notification for status change
  void _showPopupNotification(
    BuildContext context,
    UserNotification notification,
  ) {
    if (kDebugMode) {
      print('Showing popup notification: ${notification.title}');
    }

    // Remove existing overlay if any
    _dismissCurrentOverlay();

    try {
      // Create new overlay
      _currentOverlay = OverlayEntry(
        builder:
            (context) => Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 0,
              right: 0,
              child: Consumer(
                builder: (context, ref, _) {
                  return NotificationPopup(
                    notification: notification,
                    onDismiss: _dismissCurrentOverlay,
                  );
                },
              ),
            ),
      );

      // Insert the overlay
      if (context.mounted) {
        Overlay.of(context).insert(_currentOverlay!);

        // Auto-dismiss after 5 seconds
        Future.delayed(const Duration(seconds: 5), _dismissCurrentOverlay);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error showing notification popup: $e');
      }
    }
  }

  /// Dismiss the current notification overlay
  void _dismissCurrentOverlay() {
    if (_currentOverlay != null) {
      try {
        _currentOverlay!.remove();
      } catch (e) {
        if (kDebugMode) {
          print('Error removing overlay: $e');
        }
      }
      _currentOverlay = null;
    }
  }

  /// Manual method to show a specific notification as a popup
  void showNotification(UserNotification notification) {
    if (_context != null && _context!.mounted) {
      _showPopupNotification(_context!, notification);
    } else {
      if (kDebugMode) {
        print('Cannot show notification: context is not available');
      }
    }
  }

  /// Test method to show a test notification
  void showTestNotification() {
    if (_context != null && _context!.mounted) {
      final testNotification = UserNotification(
        id: 'test-${DateTime.now().millisecondsSinceEpoch}',
        userId: 'test-user',
        title: 'Test Notification',
        message: 'This is a test notification to verify the overlay system',
        type: NotificationType.statusChange,
        createdAt: DateTime.now(),
      );

      if (kDebugMode) {
        print('Showing test notification');
      }

      _showPopupNotification(_context!, testNotification);
    } else {
      if (kDebugMode) {
        print('Cannot show test notification: context is not available');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _dismissCurrentOverlay();
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _context = null;
  }
}

/// Provider for the notification service
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref),
);
