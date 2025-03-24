import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for interacting with Firebase Cloud Functions for user management
class FirebaseFunctionsService {
  // Class variables
  late FirebaseFunctions _functions;
  bool _functionsAvailable = true;

  FirebaseFunctionsService() {
    _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    _functionsAvailable = true; // Assume available until proven otherwise
  }

  /// Creates a new user with the given email, password, and role
  /// Only callable by admin users
  Future<AppUser> createUser({
    required String email,
    required String password,
    required UserRole role,
    String? displayName,
  }) async {
    // If functions are not available, fail early
    if (!_functionsAvailable) {
      throw Exception(
        'Cloud Functions are not available or have reached usage limits. Please try again later or contact the administrator.',
      );
    }

    // Validate password
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters long');
    }

    try {
      // Verify the current Firebase user is signed in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to create users');
      }

      // Verify admin status
      final isAdmin = await verifyCurrentUserIsAdmin();
      if (!isAdmin) {
        throw Exception('Only admins can create users');
      }

      debugPrint('Current user UID: ${user.uid}');

      // Force token refresh to ensure the admin has a fresh token
      final token = await user.getIdToken(true);
      debugPrint('Token refreshed, length: ${token?.length ?? 'null token'}');

      debugPrint('Calling createUser Cloud Function with region: us-central1');

      // Simplify the data we're sending
      final simplifiedRole = _getRoleString(role);
      debugPrint('Creating user with role: $simplifiedRole');

      // Call the createUser Cloud Function
      final callable = _functions.httpsCallable('createUser');
      final result = await callable.call({
        'email': email,
        'password': password,
        'role': simplifiedRole,
        'displayName': displayName,
      });

      debugPrint('Cloud function responded with data: ${result.data}');
      final userData = result.data as Map<String, dynamic>;

      // Create an AppUser from the Cloud Function response
      return AppUser(
        uid: userData['uid'],
        email: userData['email'],
        role: _mapStringToUserRole(userData['role']),
        displayName: userData['displayName'],
        additionalData: userData,
      );
    } catch (e) {
      debugPrint('Error calling createUser Cloud Function: $e');
      if (e is FirebaseFunctionsException) {
        debugPrint('Firebase Functions error code: ${e.code}');
        debugPrint('Firebase Functions error message: ${e.message}');
        debugPrint('Firebase Functions error details: ${e.details}');

        // Check for usage limits error
        if (e.code == 'resource-exhausted') {
          _functionsAvailable = false; // Disable functions for this session
          throw Exception(
            'Cloud Functions usage limit reached. Please try again later or contact the administrator.',
          );
        }

        switch (e.code) {
          case 'permission-denied':
            throw Exception('Only admins can create users');
          case 'already-exists':
            throw Exception('Email already exists');
          case 'invalid-argument':
            throw Exception(e.message ?? 'Invalid data provided');
          case 'unavailable':
            _functionsAvailable = false; // Functions not deployed yet
            throw Exception(
              'Cloud Functions are not available. Please try again later or contact the administrator.',
            );
          case 'unauthenticated':
            throw Exception(
              'You must be logged in as an admin to create users. Please log out and log back in.',
            );
          default:
            throw Exception('Failed to create user: ${e.message}');
        }
      }
      throw Exception('Failed to create user: $e');
    }
  }

  /// Enables or disables a user
  /// Only callable by admin users
  Future<void> setUserEnabled(String uid, bool isEnabled) async {
    // If functions are not available, fail early
    if (!_functionsAvailable) {
      throw Exception(
        'Cloud Functions are not available or have reached usage limits. Please try again later or contact the administrator.',
      );
    }

    try {
      // Verify the current Firebase user is signed in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to manage users');
      }

      // Verify admin status
      final isAdmin = await verifyCurrentUserIsAdmin();
      if (!isAdmin) {
        throw Exception('Only admins can enable/disable users');
      }

      // Force token refresh to ensure fresh token
      await user.getIdToken(true);

      debugPrint(
        'Calling setUserEnabled Cloud Function with region: us-central1',
      );
      // Call the setUserEnabled Cloud Function
      final callable = _functions.httpsCallable('setUserEnabled');
      await callable.call({'uid': uid, 'isEnabled': isEnabled});
    } catch (e) {
      debugPrint('Error calling setUserEnabled Cloud Function: $e');
      if (e is FirebaseFunctionsException) {
        debugPrint('Firebase Functions error code: ${e.code}');
        debugPrint('Firebase Functions error details: ${e.details}');

        // Check for usage limits error
        if (e.code == 'resource-exhausted') {
          _functionsAvailable = false; // Disable functions for this session
          throw Exception(
            'Cloud Functions usage limit reached. Please try again later or contact the administrator.',
          );
        }

        switch (e.code) {
          case 'permission-denied':
            throw Exception('Only admins can enable/disable users');
          case 'not-found':
            throw Exception('User not found');
          case 'unavailable':
            _functionsAvailable = false; // Functions not deployed yet
            throw Exception(
              'Cloud Functions are not available. Please try again later or contact the administrator.',
            );
          default:
            throw Exception('Failed to update user status: ${e.message}');
        }
      }
      throw Exception('Failed to update user status: $e');
    }
  }

  /// Sends a password reset link for a user
  /// Only callable by admin users
  Future<String> resetUserPassword(String email) async {
    // If functions are not available, fail early
    if (!_functionsAvailable) {
      throw Exception(
        'Cloud Functions are not available or have reached usage limits. Please try again later or contact the administrator.',
      );
    }

    try {
      // Verify the current Firebase user is signed in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to reset passwords');
      }

      // Verify admin status
      final isAdmin = await verifyCurrentUserIsAdmin();
      if (!isAdmin) {
        throw Exception('Only admins can reset passwords');
      }

      // Force token refresh to ensure fresh token
      await user.getIdToken(true);

      debugPrint(
        'Calling resetUserPassword Cloud Function with region: us-central1',
      );
      // Call the resetUserPassword Cloud Function
      final callable = _functions.httpsCallable('resetUserPassword');
      final result = await callable.call({'email': email});

      final resultData = result.data as Map<String, dynamic>;
      return resultData['link'] as String;
    } catch (e) {
      debugPrint('Error calling resetUserPassword Cloud Function: $e');
      if (e is FirebaseFunctionsException) {
        debugPrint('Firebase Functions error code: ${e.code}');
        debugPrint('Firebase Functions error details: ${e.details}');

        // Check for usage limits error
        if (e.code == 'resource-exhausted') {
          _functionsAvailable = false; // Disable functions for this session
          throw Exception(
            'Cloud Functions usage limit reached. Please try again later or contact the administrator.',
          );
        }

        switch (e.code) {
          case 'permission-denied':
            throw Exception('Only admins can reset passwords');
          case 'not-found':
            throw Exception('No user found with this email');
          case 'unavailable':
            _functionsAvailable = false; // Functions not deployed yet
            throw Exception(
              'Cloud Functions are not available. Please try again later or contact the administrator.',
            );
          default:
            throw Exception('Failed to reset password: ${e.message}');
        }
      }
      throw Exception('Failed to reset password: $e');
    }
  }

  /// Checks if Cloud Functions are available by calling the ping function
  Future<bool> checkAvailability() async {
    try {
      debugPrint('Attempting to check Cloud Functions availability...');

      // Get the specific instance for the region
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      debugPrint('Using Firebase Functions in region: us-central1');

      // Get callable reference to the ping function
      final callable = functions.httpsCallable('ping');
      debugPrint('Calling ping function...');

      // Call the function
      final result = await callable.call();

      // Log the raw result
      debugPrint('Cloud Functions ping result: ${result.data}');

      // Check if the result indicates success
      _functionsAvailable =
          (result.data is Map && result.data['success'] == true);

      debugPrint('Cloud Functions available: $_functionsAvailable');
      return _functionsAvailable;
    } catch (e) {
      debugPrint('Error checking Cloud Functions availability: $e');
      if (e is FirebaseFunctionsException) {
        debugPrint('Firebase Functions error code: ${e.code}');
        debugPrint('Firebase Functions error message: ${e.message}');
        debugPrint('Firebase Functions error details: ${e.details}');
      }
      _functionsAvailable = false;
      return false;
    }
  }

  /// Check if Cloud Functions are available
  bool get functionsAvailable => _functionsAvailable;

  /// Helper method to convert UserRole enum to string
  String _getRoleString(UserRole role) {
    return role.toString().split('.').last.toLowerCase();
  }

  // Helper method to map string role to UserRole enum
  UserRole _mapStringToUserRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'reseller':
        return UserRole.reseller;
      default:
        return UserRole.unknown;
    }
  }

  /// Checks if the current user is authenticated and has admin role in Firestore
  Future<bool> verifyCurrentUserIsAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No authenticated user found');
        return false;
      }

      debugPrint('Checking if user ${user.uid} is admin in Firestore');

      // Force token refresh to ensure we have the latest claims
      await user.getIdToken(true);

      // Check Firestore for admin role
      final userData =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!userData.exists) {
        debugPrint('User document does not exist in Firestore');
        return false;
      }

      final role = userData.data()?['role'] as String?;
      final isAdmin = role?.toLowerCase() == 'admin';

      debugPrint('User role in Firestore: $role, isAdmin: $isAdmin');
      return isAdmin;
    } catch (e) {
      debugPrint('Error verifying admin status: $e');
      return false;
    }
  }
}
