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

      // Force token refresh to ensure the admin has a fresh token
      final token = await user.getIdToken(true);

      // Simplify the data we're sending
      final simplifiedRole = _getRoleString(role);

      // Call the createUser Cloud Function
      final callable = _functions.httpsCallable('createUser');
      final result = await callable.call({
        'email': email,
        'password': password,
        'role': simplifiedRole,
        'displayName': displayName,
      });

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
      if (kDebugMode) {
        print('Error calling createUser Cloud Function: $e');
      }

      if (e is FirebaseFunctionsException) {
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

      // Call the setUserEnabled Cloud Function
      final callable = _functions.httpsCallable('setUserEnabled');
      await callable.call({'uid': uid, 'isEnabled': isEnabled});
    } catch (e) {
      if (kDebugMode) {
        print('Error calling setUserEnabled Cloud Function: $e');
      }

      if (e is FirebaseFunctionsException) {
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

      // Call the resetUserPassword Cloud Function
      final callable = _functions.httpsCallable('resetUserPassword');
      final result = await callable.call({'email': email});

      final resultData = result.data as Map<String, dynamic>;
      return resultData['link'] as String;
    } catch (e) {
      if (kDebugMode) {
        print('Error calling resetUserPassword Cloud Function: $e');
      }

      if (e is FirebaseFunctionsException) {
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
      // Get the specific instance for the region
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

      // Get callable reference to the ping function
      final callable = functions.httpsCallable('ping');

      // Call the function
      final result = await callable.call();

      // Check if the result indicates success
      _functionsAvailable =
          (result.data is Map && result.data['success'] == true);

      return _functionsAvailable;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking Cloud Functions availability: $e');
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
        return false;
      }

      // Force token refresh to ensure we have the latest claims
      await user.getIdToken(true);

      // Check Firestore for admin role
      final userData =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!userData.exists) {
        return false;
      }

      final role = userData.data()?['role'] as String?;
      final isAdmin = role?.toLowerCase() == 'admin';

      return isAdmin;
    } catch (e) {
      if (kDebugMode) {
        print('Error verifying admin status: $e');
      }
      return false;
    }
  }

  /// Deletes a user completely (removes from Authentication and Firestore)
  /// Only callable by admin users
  Future<void> deleteUser(String uid) async {
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
        throw Exception('You must be logged in to delete users');
      }

      // Verify admin status
      final isAdmin = await verifyCurrentUserIsAdmin();
      if (!isAdmin) {
        throw Exception('Only admins can delete users');
      }

      // Force token refresh to ensure fresh token
      await user.getIdToken(true);

      // Call the deleteUser Cloud Function
      final callable = _functions.httpsCallable('deleteUser');
      await callable.call({'uid': uid});
    } catch (e) {
      if (kDebugMode) {
        print('Error calling deleteUser Cloud Function: $e');
      }

      if (e is FirebaseFunctionsException) {
        // Check for usage limits error
        if (e.code == 'resource-exhausted') {
          _functionsAvailable = false; // Disable functions for this session
          throw Exception(
            'Cloud Functions usage limit reached. Please try again later or contact the administrator.',
          );
        }

        switch (e.code) {
          case 'permission-denied':
            throw Exception('Only admins can delete users');
          case 'not-found':
            throw Exception('User not found');
          case 'failed-precondition':
            throw Exception(e.message ?? 'Cannot delete yourself');
          case 'unavailable':
            _functionsAvailable = false; // Functions not deployed yet
            throw Exception(
              'Cloud Functions are not available. Please try again later or contact the administrator.',
            );
          default:
            throw Exception('Failed to delete user: ${e.message}');
        }
      }
      throw Exception('Failed to delete user: $e');
    }
  }
}
