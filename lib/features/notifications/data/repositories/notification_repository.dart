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

  // Get admin notifications (submissions)
  Stream<List<UserNotification>> getAdminSubmissionNotifications() {
    try {
      if (kDebugMode) {
        print('Getting admin submission notifications');
      }

      // Get all notifications with type 'newSubmission'
      return _notificationsRef
          .where('type', isEqualTo: 'newSubmission')
          .orderBy('createdAt', descending: true)
          .limit(50) // Limit to most recent 50 for performance
          .snapshots()
          .handleError((error) {
            if (kDebugMode) {
              print('Error in admin notifications stream: $error');
              if (error.toString().contains('index')) {
                print(
                  'Missing index error: You need a composite index on (type, createdAt)',
                );
                print(
                  'Create this index in Firebase Console → Firestore Database → Indexes tab',
                );
                print(
                  'Collection: notifications, Fields: type (Ascending), createdAt (Descending)',
                );
              } else if (error.toString().contains('permission')) {
                print(
                  'Permission error: Update your Firestore security rules to allow reading notifications',
                );
                print(
                  'Example rule: match /notifications/{notificationId} { allow read: if request.auth != null; }',
                );
              }
            }
          })
          .map((snapshot) {
            if (kDebugMode) {
              print(
                'Admin notifications query returned ${snapshot.docs.length} documents',
              );
            }
            return snapshot.docs
                .map((doc) => UserNotification.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      if (kDebugMode) {
        print('Error getting admin submission notifications: $e');
        print('Stack trace: ${StackTrace.current}');
      }
      // Return empty list if there's an error
      return Stream.value([]);
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
          .map((snapshot) {
            if (kDebugMode) {
              print(
                '[DEBUG] Raw snapshot received. Docs count: ${snapshot.docs.length}',
              );
              for (var doc in snapshot.docs) {
                print('[DEBUG] Doc ID: ${doc.id}, Data: ${doc.data()}');
              }
            }
            return snapshot; // Pass the snapshot through
          })
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

  // Helper method to get all admin user IDs
  Future<List<String>> _getAdminUserIds() async {
    try {
      if (kDebugMode) {
        print('Fetching admin user IDs from Firestore...');
      }

      final querySnapshot =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: 'admin')
              .get();

      if (kDebugMode) {
        print('Admin query returned ${querySnapshot.docs.length} documents');

        // Debug each document to verify role values
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          print(
            'User ${doc.id}: role=${data['role']}, displayName=${data['displayName']}',
          );
        }
      }

      // If no admin users found, try to use the current user as a fallback
      if (querySnapshot.docs.isEmpty) {
        if (kDebugMode) {
          print('No admin users found, using current user as fallback');
        }

        try {
          // Get current user
          final currentUser = _auth.currentUser;
          if (currentUser != null) {
            if (kDebugMode) {
              print('Using current user as fallback: ${currentUser.uid}');
            }
            return [currentUser.uid];
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error getting current user as fallback: $e');
          }
        }

        // Last resort: try to get any user from the users collection
        try {
          final anyUser = await _firestore.collection('users').limit(1).get();
          if (anyUser.docs.isNotEmpty) {
            final userId = anyUser.docs.first.id;
            if (kDebugMode) {
              print('Using any user as fallback: $userId');
            }
            return [userId];
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error getting any user as fallback: $e');
          }
        }
      }

      return querySnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting admin user IDs: $e');
        print('Stack trace: ${StackTrace.current}');
      }
      return [];
    }
  }

  // Create a new submission notification for admins
  Future<String> createNewSubmissionNotification({
    required String submissionId,
    required String resellerName,
    required String clientName,
    required String serviceType,
  }) async {
    try {
      if (kDebugMode) {
        print('Creating notification for submission: $submissionId');
        print(
          'Submission details: resellerName=$resellerName, clientName=$clientName, serviceType=$serviceType',
        );
      }

      // Create a single notification for the submission (not tied to any specific admin)
      final notification = UserNotification(
        id: '', // Will be set by Firestore
        userId:
            'system', // Using 'system' as userId to indicate it's a system-generated notification
        title: 'New Submission',
        message:
            'New $serviceType submission from $resellerName for client $clientName',
        type: NotificationType.newSubmission,
        createdAt: DateTime.now(),
        metadata: {
          'submissionId': submissionId,
          'resellerName': resellerName,
          'clientName': clientName,
          'serviceType': serviceType,
        },
      );

      // Add to Firestore
      final docRef = await _notificationsRef.add(notification.toFirestore());

      if (kDebugMode) {
        print('Created notification: ${docRef.id}');
        print('Notification data: ${notification.toFirestore()}');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating submission notification: $e');
        print('Stack trace: ${StackTrace.current}');

        // Add detailed error information for debugging
        if (e.toString().contains('permission')) {
          print(
            'PERMISSION ERROR: This appears to be a Firestore security rule issue.',
          );
          print(
            'Ensure your security rules allow creating notifications with userId="system"',
          );
          print(
            'Check firestore.rules and make sure notifications collection allows writes',
          );
        }
      }

      // Instead of rethrowing, return an empty string to prevent submission creation from failing
      return '';
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

  // DIAGNOSTIC METHOD: Create a test admin notification directly
  // This can be called to test if notifications appear correctly
  Future<String> createTestAdminNotification() async {
    if (kDebugMode) {
      print('Creating test admin notification for diagnostic purposes');
    }

    try {
      final testSubmissionId = 'test_${DateTime.now().millisecondsSinceEpoch}';

      final notification = UserNotification(
        id: '',
        userId: 'system', // Use system as userId
        title: 'Test Admin Notification',
        message: 'This is a test notification for admin users.',
        type: NotificationType.newSubmission, // Important: use the correct type
        createdAt: DateTime.now(),
        metadata: {
          'submissionId': testSubmissionId,
          'resellerName': 'Test Reseller',
          'clientName': 'Test Client',
          'serviceType': 'Test Service',
          'isTestNotification': true,
        },
      );

      // Add to Firestore
      final docRef = await _notificationsRef.add(notification.toFirestore());

      if (kDebugMode) {
        print('Created test admin notification: ${docRef.id}');
        print('Type: ${notification.type}');
        print(
          'Type as string: ${notification.type.toString().split('.').last}',
        );
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating test admin notification: $e');
        print('Stack trace: ${StackTrace.current}');
      }
      return '';
    }
  }
}
