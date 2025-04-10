# Notification System Implementation Guide

This guide outlines how to implement a notification system for admins to see new submissions, based on the existing notification system in the TwogetherApp.

## Overview of the Notification System Architecture

The current notification system consists of several key components:

1. **Model**: Defines the notification data structure
2. **Repository**: Handles data operations (CRUD) with Firestore
3. **Providers**: Manages state using Riverpod
4. **Services**: Handles notification display logic
5. **UI Components**: Displays notifications in the app

## Step 1: Create or Extend the Notification Model

The notification model is already defined in `lib/core/models/notification.dart`. You can either:

- Use the existing `UserNotification` model
- Extend the model by adding a new notification type for admin submissions

```dart
// Add a new notification type for admin submissions
enum NotificationType { 
  statusChange, 
  rejection, 
  payment, 
  system,
  newSubmission,  // New type for admin notifications
}
```

## Step 2: Extend the Repository to Support Admin Notifications

Modify the `notification_repository.dart` to add methods for admin notifications:

```dart
class NotificationRepository {
  // ... existing code ...

  // Get admin notifications (submissions)
  Stream<List<UserNotification>> getAdminSubmissionNotifications() {
    try {
      // Check if user is admin (you'll need to implement this logic)
      if (!_isCurrentUserAdmin()) {
        return Stream.value([]);
      }

      return _notificationsRef
          .where('type', isEqualTo: NotificationType.newSubmission.toString().split('.').last)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => UserNotification.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      if (kDebugMode) {
        print('Error getting admin submission notifications: $e');
      }
      return Stream.value([]);
    }
  }

  // Helper method to check if current user is admin
  bool _isCurrentUserAdmin() {
    // Implement logic to check if current user is admin
    // You can use your existing auth system for this
    return true; // Replace with actual logic
  }

  // Create a new submission notification for admins
  Future<String> createNewSubmissionNotification({
    required String submissionId,
    required String resellerName,
    required String clientName,
    required String serviceType,
  }) async {
    try {
      // Get all admin user IDs (you'll need to implement this)
      final adminIds = await _getAdminUserIds();
      
      final batch = _firestore.batch();
      final createdIds = <String>[];
      
      // Create a notification for each admin
      for (final adminId in adminIds) {
        final notification = UserNotification(
          id: '', // Will be set by Firestore
          userId: adminId,
          title: 'New Submission',
          message: 'New $serviceType submission from $resellerName for client $clientName',
          type: NotificationType.newSubmission,
          createdAt: DateTime.now(),
          metadata: {
            'submissionId': submissionId,
            'resellerName': resellerName,
            'clientName': clientName,
            'serviceType': serviceType,
          },
        );
        
        final docRef = _notificationsRef.doc();
        batch.set(docRef, notification.toFirestore());
        createdIds.add(docRef.id);
      }
      
      await batch.commit();
      return createdIds.isNotEmpty ? createdIds.first : '';
    } catch (e) {
      if (kDebugMode) {
        print('Error creating admin submission notification: $e');
      }
      rethrow;
    }
  }
  
  // Helper method to get all admin user IDs
  Future<List<String>> _getAdminUserIds() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
          
      return querySnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting admin user IDs: $e');
      }
      return [];
    }
  }
}
```

## Step 3: Create Riverpod Providers for Admin Notifications

Create new providers in `notification_provider.dart`:

```dart
// Stream provider for admin's submission notifications
final adminSubmissionNotificationsProvider = StreamProvider<List<UserNotification>>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getAdminSubmissionNotifications();
});

// Stream provider for unread admin submission notifications count
final unreadAdminSubmissionsCountProvider = StreamProvider<int>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  final notifications = ref.watch(adminSubmissionNotificationsProvider);
  
  return notifications.whenData((notifications) {
    return notifications.where((n) => !n.isRead).length;
  }).asStream();
});
```

## Step 4: Create Notification Service for Admin Notifications

You can extend the existing notification service or create a new one:

```dart
// In notification_service.dart

// Add a method to handle admin notification popups
void showAdminSubmissionPopup(UserNotification notification) {
  if (_context != null && _context!.mounted) {
    // You can customize this to use a different popup style for admins
    _showPopupNotification(_context!, notification);
  }
}

// Add a method to show a test admin notification
void showTestAdminNotification() {
  if (_context != null && _context!.mounted) {
    final testNotification = UserNotification(
      id: 'test-${DateTime.now().millisecondsSinceEpoch}',
      userId: 'test-admin',
      title: 'New Submission',
      message: 'New Energy submission from Bruno for client Paulo',
      type: NotificationType.newSubmission,
      createdAt: DateTime.now(),
      metadata: {
        'submissionId': 'test-id',
        'resellerName': 'Bruno',
        'clientName': 'Paulo',
        'serviceType': 'Energy',
      },
    );

    _showPopupNotification(_context!, testNotification);
  }
}
```

## Step 5: Implement UI Components for Admin Notifications

### 5.1 Add Notification Badge to Admin Navigation

```dart
// In admin_layout.dart or relevant admin UI component
Widget _buildNavigationItem(BuildContext context, String label, IconData icon, String route) {
  final isSelected = GoRouterState.of(context).uri.toString() == route;
  
  return Stack(
    clipBehavior: Clip.none,
    children: [
      // Regular nav item
      ListTile(
        selected: isSelected,
        onTap: () => context.go(route),
        leading: Icon(icon),
        title: Text(label),
      ),
      
      // Notification badge for submissions
      if (route == '/admin/submissions')
        Positioned(
          top: 8,
          right: 16,
          child: Consumer(
            builder: (context, ref, _) {
              final unreadCount = ref.watch(unreadAdminSubmissionsCountProvider);
              
              return unreadCount.when(
                data: (count) {
                  if (count <= 0) return const SizedBox.shrink();
                  
                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      count > 9 ? '9+' : count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
        ),
    ],
  );
}
```

### 5.2 Create a Notifications List in Admin Home Page or Dedicated Screen

```dart
// In admin_home_page.dart or a new dedicated component
Widget _buildAdminNotificationsSection() {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Submissions',
                style: Theme.of(context).textTheme.headline6,
              ),
              Consumer(
                builder: (context, ref, _) {
                  return TextButton(
                    onPressed: () {
                      // Mark all as read
                      final actions = ref.read(notificationActionsProvider);
                      actions.markAllAsRead();
                    },
                    child: const Text('Mark all as read'),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // List of notifications
          SizedBox(
            height: 300,
            child: Consumer(
              builder: (context, ref, _) {
                final notificationsStream = ref.watch(adminSubmissionNotificationsProvider);
                final notificationActions = ref.read(notificationActionsProvider);
                
                return notificationsStream.when(
                  data: (notifications) {
                    if (notifications.isEmpty) {
                      return const Center(
                        child: Text('No new submissions'),
                      );
                    }
                    
                    return ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: notification.isRead ? Colors.grey : Colors.blue,
                            child: const Icon(Icons.description, color: Colors.white),
                          ),
                          title: Text(notification.title),
                          subtitle: Text(notification.message),
                          trailing: Text(
                            _formatDate(notification.createdAt),
                            style: Theme.of(context).textTheme.caption,
                          ),
                          onTap: () async {
                            // Mark as read
                            await notificationActions.markAsRead(notification.id);
                            
                            // Navigate to submission details
                            if (notification.metadata.containsKey('submissionId')) {
                              final submissionId = notification.metadata['submissionId'];
                              context.push('/admin/submissions/$submissionId');
                            }
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Center(child: Text('Failed to load notifications')),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);
  
  if (difference.inMinutes < 1) {
    return 'Just now';
  } else if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    return DateFormat('MMM d, yyyy').format(date);
  }
}
```

## Step 6: Trigger Notifications When New Submissions Are Created

Add code to the submission creation process to generate admin notifications:

```dart
// In the service or repository where submissions are created
Future<void> createServiceSubmission(ServiceSubmission submission) async {
  try {
    // Save the submission
    final docRef = await _submissionsCollection.add(submission.toFirestore());
    final submissionId = docRef.id;
    
    // Get reseller info
    final resellerDoc = await _firestore.collection('users').doc(submission.resellerId).get();
    final resellerName = resellerDoc.data()?['displayName'] ?? 'Unknown Reseller';
    
    // Create notification for admins
    final notificationRepo = NotificationRepository();
    await notificationRepo.createNewSubmissionNotification(
      submissionId: submissionId,
      resellerName: resellerName,
      clientName: submission.responsibleName,
      serviceType: submission.serviceCategory.displayName,
    );
    
  } catch (e) {
    if (kDebugMode) {
      print('Error creating service submission with notification: $e');
    }
    rethrow;
  }
}
```

## Step 7: Add Firestore Rules and Indexes

Make sure to set up the proper Firestore rules and indexes:

```
// Firestore Rule
match /notifications/{notificationId} {
  allow read: if request.auth != null && (resource.data.userId == request.auth.uid || isAdmin());
  allow write: if isAdmin();
}

// Create the following indexes:
// Collection: notifications
// Fields indexed:
// 1. userId (Ascending), createdAt (Descending)
// 2. type (Ascending), createdAt (Descending)
```

## Step 8: Testing the Notification System

1. Create a test submission
2. Verify notification appears for admins
3. Test notification navigation
4. Test marking as read functionality
5. Test the badge count

## Step 9: Additional Enhancements

1. **Push Notifications**: Integrate with Firebase Cloud Messaging for push notifications
2. **Email Notifications**: Add email notifications for important submissions
3. **Notification Preferences**: Allow admins to customize which notifications they receive
4. **Notification Dashboard**: Create a dedicated notification management page

## Implementation Checklist

- [ ] Update NotificationType enum
- [ ] Add admin notification methods to repository
- [ ] Create Riverpod providers for admin notifications
- [ ] Extend notification service for admin notifications
- [ ] Add UI components (badges, notification lists)
- [ ] Modify submission creation to trigger admin notifications
- [ ] Update Firestore rules and indexes
- [ ] Test the notification system
- [ ] Add enhancements as needed 