import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/notification.dart';
import '../../data/repositories/notification_repository.dart';

// Provider for the notification repository
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

// Stream provider for user's notifications
final userNotificationsProvider = StreamProvider<List<UserNotification>>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getUserNotifications();
});

// Stream provider for unread notifications count
final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getUnreadNotificationsCount();
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
