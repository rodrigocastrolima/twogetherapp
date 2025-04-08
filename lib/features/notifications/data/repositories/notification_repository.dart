import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/models/notification.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  NotificationRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // Get the current user ID or throw an error
  String _getCurrentUserId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  // Get notifications collection reference
  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection('notifications');

  // Get user's unread notifications count
  Stream<int> getUnreadNotificationsCount() {
    try {
      final userId = _getCurrentUserId();
      return _notificationsRef
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting unread notifications count: $e');
      }
      // Return stream with 0 if there's an error
      return Stream.value(0);
    }
  }

  // Get user's notifications
  Stream<List<UserNotification>> getUserNotifications() {
    try {
      final userId = _getCurrentUserId();
      if (kDebugMode) {
        print('Fetching notifications for user: $userId');
      }

      return _notificationsRef
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .handleError((error) {
            if (kDebugMode) {
              print('Error in notifications stream: $error');
              if (error.toString().contains('index')) {
                print(
                  'MISSING INDEX ERROR: You need to create a composite index on the notifications collection',
                );
                print(
                  'Fields to index: userId (Ascending) and createdAt (Descending)',
                );
              }
            }
          })
          .map((snapshot) {
            if (kDebugMode) {
              print(
                'Received ${snapshot.docs.length} notifications from Firestore',
              );
            }
            return snapshot.docs
                .map((doc) => UserNotification.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user notifications: $e');
        print('Stack trace: ${StackTrace.current}');
      }
      // Return empty list if there's an error
      return Stream.value([]);
    }
  }

  // Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).update({'isRead': true});
    } catch (e) {
      if (kDebugMode) {
        print('Error marking notification as read: $e');
      }
      rethrow;
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final userId = _getCurrentUserId();
      final batch = _firestore.batch();

      final querySnapshot =
          await _notificationsRef
              .where('userId', isEqualTo: userId)
              .where('isRead', isEqualTo: false)
              .get();

      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        print('Error marking all notifications as read: $e');
      }
      rethrow;
    }
  }

  // Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting notification: $e');
      }
      rethrow;
    }
  }

  // Create a notification
  Future<String> createNotification({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final notification = UserNotification(
        id: '', // Will be set by Firestore
        userId: userId,
        title: title,
        message: message,
        type: type,
        createdAt: DateTime.now(),
        metadata: metadata,
      );

      final docRef = await _notificationsRef.add(notification.toFirestore());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating notification: $e');
      }
      rethrow;
    }
  }

  // Create a status change notification
  Future<String> createStatusChangeNotification({
    required String userId,
    required String submissionId,
    required String oldStatus,
    required String newStatus,
    required String clientName,
  }) async {
    String title;
    String message;

    switch (newStatus) {
      case 'approved':
        title = 'Submission Approved';
        message = 'Your submission for $clientName has been approved.';
        break;
      case 'rejected':
        title = 'Submission Rejected';
        message = 'Your submission for $clientName has been rejected.';
        break;
      case 'pending_review':
        title = 'Submission Pending Review';
        message = 'Your submission for $clientName is pending review.';
        break;
      default:
        title = 'Submission Status Changed';
        message =
            'Your submission for $clientName has been updated to $newStatus.';
    }

    return createNotification(
      userId: userId,
      title: title,
      message: message,
      type: NotificationType.statusChange,
      metadata: {
        'submissionId': submissionId,
        'oldStatus': oldStatus,
        'newStatus': newStatus,
      },
    );
  }
}
