import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/models/notification.dart';
import '../../data/repositories/notification_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Provider for the notification repository
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

// Stream provider for user's notifications
final userNotificationsProvider =
    StreamProvider.autoDispose<List<UserNotification>>((ref) {
      final isAuthenticated = ref.watch(isAuthenticatedProvider);
      if (!isAuthenticated) {
        return Stream.value([]);
      }
      final repository = ref.watch(notificationRepositoryProvider);
      return repository.getUserNotifications();
    });

// Stream provider for unread notifications count
final unreadNotificationsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value(0);
  }
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getUnreadNotificationsCount();
});

// Counter for generating refresh tokens
final _notificationRefreshCounterProvider = StateProvider<int>((ref) => 0);

// Stream provider for admin's submission notifications with manual refresh capability
final adminSubmissionNotificationsProvider = StreamProvider.autoDispose
    .family<List<UserNotification>, int>((ref, refreshToken) {
      final isAuthenticated = ref.watch(isAuthenticatedProvider);
      if (!isAuthenticated) {
        return Stream.value([]);
      }

      final repository = ref.watch(notificationRepositoryProvider);
      if (kDebugMode) {
        print('Fetching admin notifications with refresh token: $refreshToken');
      }
      return repository.getAdminSubmissionNotifications();
    });

// Auto-refreshable version of the admin submission notifications provider
final refreshableAdminSubmissionsProvider =
    Provider<AsyncValue<List<UserNotification>>>((ref) {
      final isAuthenticated = ref.watch(isAuthenticatedProvider);
      if (!isAuthenticated) {
        return const AsyncData([]);
      }

      final refreshToken = ref.watch(_notificationRefreshCounterProvider);
      return ref.watch(adminSubmissionNotificationsProvider(refreshToken));
    });

// Method to trigger a refresh of admin notifications
void refreshAdminNotifications(WidgetRef ref) {
  ref.read(_notificationRefreshCounterProvider.notifier).state++;
  if (kDebugMode) {
    print('Admin notifications refresh triggered');
  }
}

// Stream provider for unread admin submission notifications count
final unreadAdminSubmissionsCountProvider = StreamProvider.autoDispose<int>((
  ref,
) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value(0);
  }

  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getAdminSubmissionNotifications().map(
    (notifications) => notifications.where((n) => !n.isRead).length,
  );
});

// Provider functions for notification actions
final notificationActionsProvider = Provider<NotificationActions>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationActions(repository);
});

// Class for notification actions
class NotificationActions {
  final NotificationRepository _repository;

  NotificationActions(this._repository);

  Future<void> markAsRead(String notificationId) {
    return _repository.markAsRead(notificationId);
  }

  Future<void> markAllAsRead() {
    return _repository.markAllAsRead();
  }

  Future<void> deleteNotification(String notificationId) {
    return _repository.deleteNotification(notificationId);
  }
}
