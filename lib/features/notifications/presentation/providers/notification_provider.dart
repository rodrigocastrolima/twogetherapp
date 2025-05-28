import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/models/notification.dart';
import '../../data/repositories/notification_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Provider for the notification repository
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

// Provider for the stream of user notifications
final userNotificationsProvider =
    StreamProvider.autoDispose<List<UserNotification>>((ref) {
      ref.keepAlive();
      final isAuthenticated = ref.watch(isAuthenticatedProvider);
      if (!isAuthenticated || FirebaseAuth.instance.currentUser == null) {
        return Stream.value([]);
      }
      
      // Add a flag to track if the app is active
      final isAppActive = ref.watch(isAppActiveProvider);
      if (!isAppActive) {
        return Stream.value([]); // Return empty stream when app is in background
      }
      
      final repository = ref.watch(notificationRepositoryProvider);
      return repository.getUserNotifications();
    });

// Stream provider for unread notifications count
final unreadNotificationsCountProvider = StreamProvider.autoDispose<int>((ref) {
  ref.keepAlive();
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value(0);
  }
  
  // Add a flag to track if the app is active
  final isAppActive = ref.watch(isAppActiveProvider);
  if (!isAppActive) {
    return Stream.value(0); // Return 0 when app is in background
  }
  
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getUnreadNotificationsCount();
});

// Add a provider to track app lifecycle state
final isAppActiveProvider = StateProvider<bool>((ref) => true);

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

// Provider for push notification settings
final pushNotificationSettingsProvider = StateNotifierProvider<PushNotificationSettingsNotifier, bool>((ref) {
  return PushNotificationSettingsNotifier();
});

// Provider for admin push notification settings (separate from reseller)
final adminPushNotificationSettingsProvider = StateNotifierProvider<AdminPushNotificationSettingsNotifier, bool>((ref) {
  return AdminPushNotificationSettingsNotifier();
});

// Class to manage push notification settings
class PushNotificationSettingsNotifier extends StateNotifier<bool> {
  static const String _prefsKey = 'push_notifications_enabled';
  
  PushNotificationSettingsNotifier() : super(true) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefsKey) ?? true; // Default to enabled
      state = enabled;
      
      if (kDebugMode) {
        print('Loaded push notification settings: $enabled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading push notification settings: $e');
      }
    }
  }

  Future<void> toggle() async {
    final newState = !state;
    await setEnabled(newState);
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, enabled);
      
      // Update state
      state = enabled;
      
      // Handle FCM token based on the setting
      if (enabled) {
        await _enableNotifications();
      } else {
        await _disableNotifications();
      }
      
      if (kDebugMode) {
        print('Push notifications ${enabled ? 'enabled' : 'disabled'}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting push notification state: $e');
      }
    }
  }

  Future<void> _enableNotifications() async {
    try {
      // Request permissions
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get token and add it to Firestore
        final token = await messaging.getToken();
        if (token != null) {
          await _addTokenToFirestore(token);
        }
        
        if (kDebugMode) {
          print('Push notifications enabled and token registered');
        }
      } else {
        if (kDebugMode) {
          print('Push notification permission denied');
        }
        // If permission denied, set state back to false
        state = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefsKey, false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error enabling notifications: $e');
      }
    }
  }

  Future<void> _disableNotifications() async {
    try {
      // Remove token from Firestore
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null) {
        await _removeTokenFromFirestore(token);
      }
      
      if (kDebugMode) {
        print('Push notifications disabled and token removed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error disabling notifications: $e');
      }
    }
  }

  Future<void> _addTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userRef.set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding token to Firestore: $e');
      }
    }
  }

  Future<void> _removeTokenFromFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userRef.update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error removing token from Firestore: $e');
      }
    }
  }
}

// Separate class to manage admin push notification settings
class AdminPushNotificationSettingsNotifier extends StateNotifier<bool> {
  static const String _prefsKey = 'admin_push_notifications_enabled';
  
  AdminPushNotificationSettingsNotifier() : super(true) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefsKey) ?? true; // Default to enabled
      state = enabled;
      
      if (kDebugMode) {
        print('Loaded admin push notification settings: $enabled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading admin push notification settings: $e');
      }
    }
  }

  Future<void> toggle() async {
    final newState = !state;
    await setEnabled(newState);
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, enabled);
      
      // Update state
      state = enabled;
      
      // Handle FCM token based on the setting
      if (enabled) {
        await _enableNotifications();
      } else {
        await _disableNotifications();
      }
      
      if (kDebugMode) {
        print('Admin push notifications ${enabled ? 'enabled' : 'disabled'}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting admin push notification state: $e');
      }
    }
  }

  Future<void> _enableNotifications() async {
    try {
      // Request permissions
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get token and add it to Firestore
        final token = await messaging.getToken();
        if (token != null) {
          await _addTokenToFirestore(token);
        }
        
        if (kDebugMode) {
          print('Admin push notifications enabled and token registered');
        }
      } else {
        if (kDebugMode) {
          print('Admin push notification permission denied');
        }
        // If permission denied, set state back to false
        state = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefsKey, false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error enabling admin notifications: $e');
      }
    }
  }

  Future<void> _disableNotifications() async {
    try {
      // Remove token from Firestore
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null) {
        await _removeTokenFromFirestore(token);
      }
      
      if (kDebugMode) {
        print('Admin push notifications disabled and token removed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error disabling admin notifications: $e');
      }
    }
  }

  Future<void> _addTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userRef.set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding admin token to Firestore: $e');
      }
    }
  }

  Future<void> _removeTokenFromFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userRef.update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error removing admin token from Firestore: $e');
      }
    }
  }
}
