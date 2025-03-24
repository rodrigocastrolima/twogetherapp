import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';

/// Abstract repository that defines authentication methods
abstract class AuthRepository {
  /// Stream of the current authenticated user
  Stream<AppUser?> get authStateChanges;

  /// The currently authenticated user
  AppUser? get currentUser;

  /// Sign in with email and password
  Future<AppUser> signInWithEmailAndPassword(String email, String password);

  /// Sign out the current user
  Future<void> signOut();

  /// Create a new user account with email and password
  /// For admin use to create reseller accounts
  Future<AppUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required UserRole role,
    String? displayName,
  });

  /// Update user password
  Future<void> updatePassword(String newPassword);

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email);

  /// Check if it's the user's first login
  Future<bool> isFirstLogin();

  /// Mark that the user has completed their first login
  Future<void> completeFirstLogin();

  /// Get user by ID - primarily for admin to access reseller information
  Future<AppUser?> getUserById(String uid);

  /// Get list of all reseller users - for admin use
  Future<List<AppUser>> getAllResellers();

  /// Enable or disable a user account - for admin use
  Future<void> setUserEnabled(String uid, bool enabled);
}
