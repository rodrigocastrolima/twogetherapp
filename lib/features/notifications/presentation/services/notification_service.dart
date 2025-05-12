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
  String? _currentListeningUserId;

  NotificationService(this._ref);

  /// Initialize basic service state (like context if needed immediately)
  /// Actual stream subscription is now handled by startListeningForUser
  void initializeCore(BuildContext context) {
    _context = context;
    if (kDebugMode) {
      print('NotificationService.initializeCore: Context set.');
    }
  }

  /// Start listening to notifications for a specific user
  void startListeningForUser(BuildContext context, String userId) {
    _context = context;

    if (_currentListeningUserId == userId &&
        _notificationSubscription != null) {
      if (kDebugMode) {
        print('NotificationService: Already listening for user $userId.');
      }
      return;
    }

    stopListening();
    _currentListeningUserId = userId;
    _processedIds.clear();

    if (kDebugMode) {
      print(
        'NotificationService.startListeningForUser: Setting up notification stream for user $userId.',
      );
    }

    final notificationRepo = _ref.read(notificationRepositoryProvider);
    final notificationsStream = notificationRepo.getUserNotifications();

    _notificationSubscription = notificationsStream.listen(
      (notifications) {
        if (kDebugMode) {
          print(
            'Received ${notifications.length} notifications for user $_currentListeningUserId',
          );
        }
        if (_context == null || !_context!.mounted) {
          if (kDebugMode)
            print(
              'NotificationService: Context is null or not mounted. Cannot show popup.',
            );
          return;
        }
        for (final notification in notifications) {
          if (!_processedIds.contains(notification.id) &&
              !notification.isRead &&
              notification.type == NotificationType.statusChange) {
            if (kDebugMode) {
              print(
                'Processing new notification: ${notification.title} for user $_currentListeningUserId',
              );
            }
            _processedIds.add(notification.id);
            _showPopupNotification(_context!, notification);
            break;
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print(
            'Error listening to notifications for user $_currentListeningUserId: $error',
          );
        }
      },
      onDone: () {
        if (kDebugMode) {
          print(
            'Notification stream for user $_currentListeningUserId is done.',
          );
        }
      },
    );

    if (kDebugMode) {
      print(
        'NotificationService: Subscription active for user $_currentListeningUserId.',
      );
    }
  }

  /// Stop listening to notifications
  void stopListening() {
    if (_notificationSubscription != null) {
      if (kDebugMode) {
        print(
          'NotificationService.stopListening: Cancelling subscription for user $_currentListeningUserId.',
        );
      }
      _notificationSubscription!.cancel();
      _notificationSubscription = null;
    }
    _currentListeningUserId = null;
  }

  /// Show a popup notification for status change
  void _showPopupNotification(
    BuildContext context,
    UserNotification notification,
  ) {
    if (kDebugMode) {
      print('Showing popup notification: ${notification.title}');
    }

    _dismissCurrentOverlay();

    try {
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

      if (context.mounted) {
        Overlay.of(context).insert(_currentOverlay!);

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
    stopListening();
    _context = null;
    _processedIds.clear();
    if (kDebugMode) {
      print('NotificationService: Disposed.');
    }
  }
}

/// Provider for the notification service
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref),
);
