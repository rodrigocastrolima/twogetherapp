import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/models/notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  // Get admin notifications (submissions and rejections)
  Stream<List<UserNotification>> getAdminSubmissionNotifications() {
    try {
      if (kDebugMode) {
        print('Getting admin submission, proposal rejection, and proposal acceptance notifications');
      }

      // Get all notifications with type 'newSubmission', 'proposalRejected', or 'proposalAccepted'
      return _notificationsRef
          .where(
            'type',
            whereIn: [
              'newSubmission', 
              'proposalRejected',
              'proposalAccepted'
            ],
          ) 
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

  // Helper method to get Firebase uid from Salesforce user ID
  Future<String?> getFirebaseUidFromSalesforceId(String salesforceId) async {
    try {
      if (kDebugMode) {
        print('Looking up Firebase uid for Salesforce ID: $salesforceId');
      }

      final querySnapshot = await _firestore
          .collection('users')
          .where('salesforceId', isEqualTo: salesforceId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final firebaseUid = querySnapshot.docs.first.id;
        if (kDebugMode) {
          print('Found Firebase uid: $firebaseUid for Salesforce ID: $salesforceId');
        }
        return firebaseUid;
      } else {
        if (kDebugMode) {
          print('No Firebase user found for Salesforce ID: $salesforceId');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error looking up Firebase uid for Salesforce ID $salesforceId: $e');
      }
      return null;
    }
  }

  // Create a new submission notification for admins
  Future<String> createNewSubmissionNotification({
    required String submissionId,
    required String resellerName,
    required String clientName,
    String? companyName,
    String? responsibleName,
    String? serviceCategory, // 'energy', 'insurance', etc.
    String? energyType, // 'solar', 'electricityGas', etc.
    String? clientType, // 'residential', 'commercial'
  }) async {
    try {
      // Determine service type display string
      String serviceTypeDisplay = '';
      if (serviceCategory == 'energy') {
        if (energyType == 'solar') {
          serviceTypeDisplay = 'Solar';
        } else if (clientType == 'residential') {
          serviceTypeDisplay = 'Energia Residencial';
        } else if (clientType == 'commercial') {
          serviceTypeDisplay = 'Energia Comercial';
        }
      }
      if (serviceTypeDisplay.isEmpty && serviceCategory != null) {
        serviceTypeDisplay = serviceCategory[0].toUpperCase() + serviceCategory.substring(1);
      }

      // Determine client name
      String clientDisplayName = '';
      if ((clientType == 'residential' && responsibleName != null && responsibleName.isNotEmpty)) {
        clientDisplayName = responsibleName;
      } else if ((clientType == 'commercial' || serviceTypeDisplay == 'Solar') && companyName != null && companyName.isNotEmpty) {
        clientDisplayName = companyName;
      } else {
        clientDisplayName = clientName;
      }

      final notification = UserNotification(
        id: '',
        userId: 'system',
        title: 'Nova Submissão de Serviço',
        message: 'Nova submissão de serviço $serviceTypeDisplay de $resellerName para cliente $clientDisplayName',
        type: NotificationType.newSubmission,
        createdAt: DateTime.now(),
        metadata: {
          'submissionId': submissionId,
          'resellerName': resellerName,
          'clientName': clientName,
          'companyName': companyName,
          'responsibleName': responsibleName,
          'serviceCategory': serviceCategory,
          'energyType': energyType,
          'clientType': clientType,
          'serviceType': serviceTypeDisplay,
        },
      );

      final docRef = await _notificationsRef.add(notification.toFirestore());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating submission notification: $e');
        print('Stack trace: \n${StackTrace.current}');
      }
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

  // Create a new proposal rejected notification for admins/system
  Future<String> createProposalRejectedNotification({
    required String proposalId,
    required String proposalName,
    String? opportunityId,
    String? clientName,
    String? resellerName,
    String? resellerId,
  }) async {
    final functionName = 'createProposalRejectedNotification';
    if (kDebugMode) {
      print('[$runtimeType] $functionName: Called for proposalId: $proposalId');
    }
    try {
      final notification = UserNotification(
        id: '', // Will be set by Firestore
        userId: 'system', // System-level notification for admin/ops review
        title: 'Proposta Rejeitada',
        message:
            'A proposta "$proposalName" para o cliente ${clientName ?? 'N/D'} foi rejeitada pelo revendedor ${resellerName ?? 'N/D'}.',
        type: NotificationType.proposalRejected,
        createdAt: DateTime.now(),
        metadata: {
          'proposalId': proposalId,
          'proposalName': proposalName,
          if (opportunityId != null) 'opportunityId': opportunityId,
          if (clientName != null) 'clientName': clientName,
          if (resellerName != null) 'resellerName': resellerName,
          if (resellerId != null) 'resellerId': resellerId,
          'reason':
              'Rejected by reseller via app', // Placeholder, can be expanded later
        },
      );

      final docRef = await _notificationsRef.add(notification.toFirestore());
      if (kDebugMode) {
        print(
          '[$runtimeType] $functionName: Successfully created notification ${docRef.id}',
        );
      }
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('[$runtimeType] $functionName: Error: $e');
      }
      rethrow; // Rethrow to allow UI to handle it
    }
  }

  // NEW METHOD: Create a new proposal accepted and documents submitted notification
  Future<String> createProposalAcceptedNotification({
    required String proposalId,
    required String proposalName,
    String? opportunityId, // Keep optional for now
    String? clientNif, // Using NIF as client identifier
    String? resellerName,
    String? resellerId,
  }) async {
    final functionName = 'createProposalAcceptedNotification';
    if (kDebugMode) {
      print('[$runtimeType] $functionName: Called for proposalId: $proposalId');
    }
    try {
      final notification = UserNotification(
        id: '', // Will be set by Firestore
        userId: 'system', // System-level notification for admin/ops review
        title: 'Proposta Aceite e Documentos Submetidos',
        message:
            'Documentos submetidos para a proposta $proposalName pelo revendedor ${resellerName ?? 'N/D'}',
        type: NotificationType.proposalAccepted, // Assuming you have or will add this type
        createdAt: DateTime.now(),
        metadata: {
          'proposalId': proposalId,
          'proposalName': proposalName,
          if (opportunityId != null) 'opportunityId': opportunityId,
          if (resellerName != null) 'resellerName': resellerName,
          if (resellerId != null) 'resellerId': resellerId,
          'status': 'Accepted and Documents Submitted',
        },
      );

      final docRef = await _notificationsRef.add(notification.toFirestore());
      if (kDebugMode) {
        print(
          '[$runtimeType] $functionName: Successfully created notification ${docRef.id}',
        );
      }
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('[$runtimeType] $functionName: Error: $e');
      }
      // It's often better not to rethrow here if notification failure shouldn't block primary flow
      // Consider just logging or returning an empty/error indicator if UI needs to know
      return ''; // Or throw specific error if needed by caller
    }
  }

  // NEW METHOD: Create a contract insertion completion notification for reseller
  Future<String> createContractInsertionNotification({
    required String salesforceUserId, // Changed parameter name to clarify it's Salesforce ID
    required String proposalId,
    required String proposalName,
    required String entityName,
    String? entityNif,
    String? opportunityId, // Add opportunity ID parameter
  }) async {
    final functionName = 'createContractInsertionNotification';
    if (kDebugMode) {
      print('[$runtimeType] $functionName: Called for proposalId: $proposalId, salesforceUserId: $salesforceUserId');
    }
    try {
      // Look up the Firebase uid from the Salesforce user ID
      final firebaseUid = await getFirebaseUidFromSalesforceId(salesforceUserId);
      
      if (firebaseUid == null) {
        if (kDebugMode) {
          print('[$runtimeType] $functionName: No Firebase user found for Salesforce ID: $salesforceUserId');
        }
        return ''; // Return empty string to indicate failure without throwing
      }

      final notification = UserNotification(
        id: '', // Will be set by Firestore
        userId: firebaseUid, // Use Firebase uid instead of Salesforce ID
        title: 'Processo Concluído',
        message: 'O processo para o cliente $entityName foi concluído!',
        type: NotificationType.statusChange,
        createdAt: DateTime.now(),
        metadata: {
          'proposalId': proposalId,
          'proposalName': proposalName,
          'entityName': entityName,
          if (entityNif != null) 'entityNif': entityNif,
          if (opportunityId != null) 'opportunityId': opportunityId, // Add opportunity ID to metadata
          'contractInsertedAt': DateTime.now().toIso8601String(),
          'processType': 'contract_insertion',
          'salesforceUserId': salesforceUserId, // Keep Salesforce ID for reference
        },
      );

      final docRef = await _notificationsRef.add(notification.toFirestore());
      if (kDebugMode) {
        print(
          '[$runtimeType] $functionName: Successfully created notification ${docRef.id} for Firebase uid: $firebaseUid',
        );
      }
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('[$runtimeType] $functionName: Error: $e');
      }
      rethrow;
    }
  }
}

// Provider for the NotificationRepository
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});
