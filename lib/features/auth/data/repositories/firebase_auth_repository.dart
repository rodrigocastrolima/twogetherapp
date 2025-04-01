import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/firebase_functions_service.dart';

/// Implementation of [AuthRepository] using Firebase Authentication
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctionsService _functionsService;
  final String _usersCollection = 'users';
  final bool _useCloudFunctions;

  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseFunctionsService? functionsService,
    bool useCloudFunctions = true,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functionsService = functionsService ?? FirebaseFunctionsService(),
       _useCloudFunctions = useCloudFunctions; // Use provided value directly

  @override
  Stream<AppUser?> get authStateChanges {
    return _firebaseAuth.authStateChanges().asyncMap((User? user) async {
      if (user == null) {
        return null;
      }

      // Get user data from Firestore to include role information
      try {
        final userData =
            await _firestore.collection(_usersCollection).doc(user.uid).get();

        if (userData.exists) {
          final role = _mapStringToUserRole(
            userData.data()?['role'] as String? ?? 'unknown',
          );
          final isFirstLogin =
              userData.data()?['isFirstLogin'] as bool? ?? true;

          return AppUser.fromFirebaseUser(user, role: role).copyWith(
            isFirstLogin: isFirstLogin,
            additionalData: userData.data() ?? {},
          );
        } else {
          // If the user exists in Authentication but not in Firestore,
          // create their entry in Firestore
          if (kDebugMode) {
            print('User exists in Auth but not in Firestore, creating record');
          }
          final newUserData = {
            'uid': user.uid,
            'email': user.email,
            'displayName': user.displayName,
            'role': 'unknown', // Default role
            'isFirstLogin': true,
            'createdAt': FieldValue.serverTimestamp(),
          };

          await _firestore
              .collection(_usersCollection)
              .doc(user.uid)
              .set(newUserData);

          return AppUser.fromFirebaseUser(
            user,
          ).copyWith(isFirstLogin: true, additionalData: newUserData);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching user data: $e');
        }
        return AppUser.fromFirebaseUser(user);
      }
    });
  }

  @override
  AppUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return null;
    }

    // Note: This is a synchronous getter, so we can't fetch the Firestore data here.
    // The role will be unknown and clients should use authStateChanges() to get the full user object.
    return AppUser.fromFirebaseUser(user);
  }

  @override
  Future<AppUser> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('No user returned from sign in');
      }

      // Get user data from Firestore
      final userData =
          await _firestore
              .collection(_usersCollection)
              .doc(userCredential.user!.uid)
              .get();

      if (userData.exists) {
        final role = _mapStringToUserRole(
          userData.data()?['role'] as String? ?? 'unknown',
        );
        final isFirstLogin = userData.data()?['isFirstLogin'] as bool? ?? true;

        return AppUser.fromFirebaseUser(
          userCredential.user!,
          role: role,
        ).copyWith(
          isFirstLogin: isFirstLogin,
          additionalData: userData.data() ?? {},
        );
      } else {
        // If it's a new user, create their entry in Firestore
        final newUser = AppUser.fromFirebaseUser(
          userCredential.user!,
          role: UserRole.unknown,
        );
        await _firestore
            .collection(_usersCollection)
            .doc(userCredential.user!.uid)
            .set({
              'uid': userCredential.user!.uid,
              'email': userCredential.user!.email,
              'role': 'unknown',
              'isFirstLogin': true,
              'createdAt': FieldValue.serverTimestamp(),
            });
        return newUser.copyWith(isFirstLogin: true);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<AppUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required UserRole role,
    String? displayName,
  }) async {
    final adminUid = _firebaseAuth.currentUser?.uid;
    if (adminUid == null) {
      throw Exception('Must be logged in to create a user');
    }

    // Check if Cloud Functions are available
    bool functionsAvailable = false;
    if (_useCloudFunctions) {
      try {
        functionsAvailable = await _functionsService.checkAvailability();
        if (functionsAvailable) {
          if (kDebugMode) {
            print('Using Cloud Functions for user creation');
          }
        } else {
          throw Exception(
            'Cloud Functions are required for user creation but are not available. Please try again later.',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error checking Cloud Functions availability: $e');
        }
        throw Exception(
          'Cloud Functions are required for user creation but could not be accessed. Error: $e',
        );
      }
    } else {
      throw Exception(
        'Cloud Functions are required for user creation but are disabled in this environment.',
      );
    }

    // Use Cloud Functions for user creation
    try {
      // Force token refresh to ensure fresh authentication
      await _firebaseAuth.currentUser?.getIdToken(true);

      // Get admin token that will be used to verify admin status on the server
      final adminToken = await _getAdminToken();
      if (kDebugMode) {
        print(
          'Admin token obtained for secure Cloud Function call: ${adminToken.substring(0, 20)}...',
        );
      }

      // Call the Cloud Function to create the user
      if (kDebugMode) {
        print('Creating user with Cloud Functions: $email');
      }
      final newUser = await _functionsService.createUser(
        email: email,
        password: password,
        role: role,
        displayName: displayName,
      );

      if (kDebugMode) {
        print('User created successfully via Cloud Functions: ${newUser.uid}');
      }
      return newUser;
    } catch (e) {
      if (kDebugMode) {
        print('Cloud Functions error: $e');
      }
      if (e is FirebaseFunctionsException) {
        if (kDebugMode) {
          print('Firebase Functions error code: ${e.code}');
          print('Firebase Functions error message: ${e.message}');
          print('Firebase Functions error details: ${e.details}');
        }
      }

      // Propagate the error - no fallback to client-side implementation
      throw Exception('Failed to create user: $e');
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    try {
      await user.updatePassword(newPassword);

      // Mark first login as completed when password is changed
      await completeFirstLogin();
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    // Check if Cloud Functions are available
    if (!_useCloudFunctions) {
      throw Exception(
        'Cloud Functions are required for resetting passwords but are disabled in this environment.',
      );
    }

    // Verify Cloud Functions availability
    if (!_functionsService.functionsAvailable) {
      bool available = false;
      try {
        available = await _functionsService.checkAvailability();
      } catch (e) {
        if (kDebugMode) {
          print('Error checking Cloud Functions availability: $e');
        }
        throw Exception(
          'Cloud Functions are required for resetting passwords but could not be accessed. Error: $e',
        );
      }

      if (!available) {
        throw Exception(
          'Cloud Functions are required for resetting passwords but are not available. Please try again later.',
        );
      }
    }

    try {
      if (kDebugMode) {
        print('Using Cloud Functions to reset password for $email');
      }
      final resetLink = await _functionsService.resetUserPassword(email);

      // In a real app, you might want to send this link via your own email system
      if (kDebugMode) {
        print('Password reset link: $resetLink');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Cloud Functions error: $e');
      }
      if (e is FirebaseFunctionsException) {
        if (kDebugMode) {
          print('Firebase Functions error code: ${e.code}');
          print('Firebase Functions error message: ${e.message}');
          print('Firebase Functions error details: ${e.details}');
        }
      }
      throw Exception('Failed to reset password: $e');
    }
  }

  @override
  Future<bool> isFirstLogin() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    final userData =
        await _firestore.collection(_usersCollection).doc(user.uid).get();

    return userData.data()?['isFirstLogin'] as bool? ?? false;
  }

  @override
  Future<void> completeFirstLogin() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    await _firestore.collection(_usersCollection).doc(user.uid).update({
      'isFirstLogin': false,
      'firstLoginCompletedAt': FieldValue.serverTimestamp(),
    });

    if (kDebugMode) {
      print('First login completed for user: ${user.uid}');
    }
  }

  @override
  Future<AppUser?> getUserById(String uid) async {
    try {
      // Get user data from Firestore
      final userData =
          await _firestore.collection(_usersCollection).doc(uid).get();

      if (!userData.exists) {
        return null;
      }

      final data = userData.data()!;
      final role = _mapStringToUserRole(data['role'] as String? ?? 'unknown');

      return AppUser(
        uid: uid,
        email: data['email'] as String? ?? '',
        role: role,
        displayName: data['displayName'] as String?,
        photoURL: data['photoURL'] as String?,
        isFirstLogin: data['isFirstLogin'] as bool? ?? false,
        isEmailVerified: data['isEmailVerified'] as bool? ?? false,
        additionalData: data,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user by ID: $e');
      }
      return null;
    }
  }

  @override
  Future<List<AppUser>> getAllResellers() async {
    try {
      final querySnapshot =
          await _firestore
              .collection(_usersCollection)
              .where('role', isEqualTo: 'reseller')
              .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        final role = _mapStringToUserRole(data['role'] as String? ?? 'unknown');

        return AppUser(
          uid: doc.id,
          email: data['email'] as String? ?? '',
          role: role,
          displayName: data['displayName'] as String?,
          photoURL: data['photoURL'] as String?,
          isFirstLogin: data['isFirstLogin'] as bool? ?? false,
          isEmailVerified: data['isEmailVerified'] as bool? ?? false,
          additionalData: data,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all resellers: $e');
      }
      return [];
    }
  }

  @override
  Future<void> setUserEnabled(String uid, bool enabled) async {
    // Check if Cloud Functions are available
    if (!_useCloudFunctions) {
      throw Exception(
        'Cloud Functions are required for enabling/disabling users but are disabled in this environment.',
      );
    }

    // Verify Cloud Functions availability
    if (!_functionsService.functionsAvailable) {
      bool available = false;
      try {
        available = await _functionsService.checkAvailability();
      } catch (e) {
        if (kDebugMode) {
          print('Error checking Cloud Functions availability: $e');
        }
        throw Exception(
          'Cloud Functions are required for enabling/disabling users but could not be accessed. Error: $e',
        );
      }

      if (!available) {
        throw Exception(
          'Cloud Functions are required for enabling/disabling users but are not available. Please try again later.',
        );
      }
    }

    try {
      await _functionsService.setUserEnabled(uid, enabled);
    } catch (e) {
      if (kDebugMode) {
        print('Cloud Functions error: $e');
      }
      if (e is FirebaseFunctionsException) {
        throw Exception('Failed to update user status: $e');
      }
      throw Exception('Failed to update user status: $e');
    }
  }

  @override
  Future<void> deleteUser(String uid) async {
    // Check if Cloud Functions are available
    if (!_useCloudFunctions) {
      throw Exception(
        'Cloud Functions are required for deleting users but are disabled in this environment.',
      );
    }

    // Verify Cloud Functions availability
    if (!_functionsService.functionsAvailable) {
      bool available = false;
      try {
        available = await _functionsService.checkAvailability();
      } catch (e) {
        if (kDebugMode) {
          print('Error checking Cloud Functions availability: $e');
        }
        throw Exception(
          'Cloud Functions are required for deleting users but could not be accessed. Error: $e',
        );
      }

      if (!available) {
        throw Exception(
          'Cloud Functions are required for deleting users but are not available. Please try again later.',
        );
      }
    }

    try {
      await _functionsService.deleteUser(uid);
    } catch (e) {
      if (kDebugMode) {
        print('Cloud Functions error: $e');
      }
      if (e is FirebaseFunctionsException) {
        throw Exception('Failed to delete user: $e');
      }
      throw Exception('Failed to delete user: $e');
    }
  }

  // Helper methods
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

  Exception _handleFirebaseAuthException(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return Exception('No user found with this email');
        case 'wrong-password':
          return Exception('Incorrect password');
        case 'email-already-in-use':
          return Exception('Email is already in use');
        case 'weak-password':
          return Exception('Password is too weak');
        case 'invalid-email':
          return Exception('Invalid email address');
        case 'user-disabled':
          return Exception('This account has been disabled');
        case 'requires-recent-login':
          return Exception(
            'Please log out and log back in to change your password',
          );
        default:
          return Exception('Authentication error: ${e.message}');
      }
    } else {
      return Exception('Unknown error: $e');
    }
  }

  /// Get current admin token to maintain admin session
  Future<String> _getAdminToken() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    // Get ID token to validate admin status on server
    final token = await user.getIdToken();
    if (token == null) {
      throw Exception('Failed to get authentication token');
    }
    return token;
  }
}
