import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../auth/domain/models/app_user.dart';
// import '../../../../core/providers/firebase_providers.dart'; // Was incorrect
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../salesforce/data/services/salesforce_user_sync_service.dart';
import '../../../auth/data/services/firebase_functions_service.dart';

// State for the user creation process
@immutable
class UserCreationState {
  final bool isLoading;
  final String? loadingMessage;
  final String? errorMessage;
  final String? successMessage; // Optional: Use successData instead?

  // UI Trigger States
  final bool showVerificationDialog;
  final Map<String, dynamic>? verificationData; // Holds name, email, password
  final bool showSuccessDialog;
  final Map<String, dynamic>? successData; // Holds name, email, password
  final bool showErrorDialog; // Can reuse errorMessage

  const UserCreationState({
    this.isLoading = false,
    this.loadingMessage,
    this.errorMessage,
    this.successMessage,
    this.showVerificationDialog = false,
    this.verificationData,
    this.showSuccessDialog = false,
    this.successData,
    this.showErrorDialog = false,
  });

  UserCreationState copyWith({
    bool? isLoading,
    String? loadingMessage,
    String? errorMessage,
    String? successMessage,
    bool? showVerificationDialog,
    Map<String, dynamic>? verificationData,
    bool? showSuccessDialog,
    Map<String, dynamic>? successData,
    bool? showErrorDialog,
    bool clearError = false,
    bool clearSuccess = false,
    // Helper to reset UI triggers when setting new state
    bool resetDialogTriggers = false,
  }) {
    return UserCreationState(
      isLoading: isLoading ?? this.isLoading,
      loadingMessage:
          isLoading == true
              ? (loadingMessage ?? this.loadingMessage)
              : null, // Clear message when not loading
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage:
          clearSuccess ? null : successMessage ?? this.successMessage,
      // Reset triggers if requested or if loading starts/stops
      showVerificationDialog:
          resetDialogTriggers || isLoading != null
              ? false
              : showVerificationDialog ?? this.showVerificationDialog,
      verificationData:
          resetDialogTriggers || isLoading != null
              ? null
              : verificationData ?? this.verificationData,
      showSuccessDialog:
          resetDialogTriggers || isLoading != null
              ? false
              : showSuccessDialog ?? this.showSuccessDialog,
      successData:
          resetDialogTriggers || isLoading != null
              ? null
              : successData ?? this.successData,
      showErrorDialog:
          resetDialogTriggers || isLoading != null
              ? false
              : showErrorDialog ?? this.showErrorDialog,
    );
  }
}

// Notifier for user creation logic
class UserCreationNotifier extends StateNotifier<UserCreationState> {
  final Ref _ref;
  final FirebaseFirestore _firestore;

  UserCreationNotifier(this._ref, this._firestore)
    : super(const UserCreationState());

  // Step 1: Verify Salesforce ID and check Firestore
  Future<void> verifySalesforceUser(String salesforceId) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      loadingMessage: 'Verifying Salesforce User...',
      resetDialogTriggers: true, // Clear previous dialog flags
      clearError: true,
    );

    try {
      final salesforceService = SalesforceUserSyncService();
      final initialized = await salesforceService.initialize();
      if (!initialized) {
        throw Exception('Failed to connect to Salesforce.');
      }

      if (kDebugMode)
        print('[UserCreationNotifier] Fetching Salesforce user: $salesforceId');
      final userData = await salesforceService.getSalesforceUserById(
        salesforceId,
      );
      if (kDebugMode)
        print(
          '[UserCreationNotifier] Salesforce user data fetched: ${userData ?? "Not Found"}',
        );

      if (userData == null || userData.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No user found with Salesforce ID: $salesforceId',
          showErrorDialog: true,
        );
        return;
      }

      if (kDebugMode)
        print(
          '[UserCreationNotifier] Checking for existing Firestore user with Salesforce ID: $salesforceId',
        );
      final existingUsers =
          await _firestore
              .collection('users')
              .where('salesforceId', isEqualTo: salesforceId)
              .limit(1)
              .get();
      if (kDebugMode)
        print(
          '[UserCreationNotifier] Firestore check complete. Found: ${existingUsers.docs.length}',
        );

      if (existingUsers.docs.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'A user with this Salesforce ID already exists.',
          showErrorDialog: true,
        );
        return;
      }

      // --- Data is valid, prepare for verification dialog ---
      if (kDebugMode)
        print('[UserCreationNotifier] Proceeding to password generation.');
      const chars =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
      final random = Random.secure();
      String password = '';
      // (Password generation logic remains the same)
      password += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'[random.nextInt(26)];
      password += 'abcdefghijklmnopqrstuvwxyz'[random.nextInt(26)];
      password += '0123456789'[random.nextInt(10)];
      password += '!@#\$%^&*()'[random.nextInt(10)];
      while (password.length < 12) {
        password += chars[random.nextInt(chars.length)];
      }
      final email = userData['Email'] as String?;
      final name = userData['Name'] as String?;

      if (email == null || email.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Salesforce user found, but has no email address. Cannot create account.',
          showErrorDialog: true,
        );
        return;
      }

      // Set state to trigger verification dialog in UI
      if (kDebugMode)
        print(
          '[UserCreationNotifier] Setting state to show verification dialog (in two steps).',
        );
      // Step 1: Set loading to false first
      state = state.copyWith(isLoading: false);
      // Step 2: Immediately set the dialog flag and data
      state = state.copyWith(
        showVerificationDialog: true,
        verificationData: {
          'name': name,
          'email': email,
          'password': password,
          'salesforceId': salesforceId, // Pass needed data through state
        },
      );
      // Log the state immediately after setting it
      if (kDebugMode)
        print(
          '[UserCreationNotifier] State AFTER setting showVerificationDialog: $state',
        );
    } catch (e) {
      if (kDebugMode)
        print('[UserCreationNotifier] Error caught during verification: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to verify Salesforce user: ${e.toString()}',
        showErrorDialog: true,
      );
    }
  }

  // Step 2: Create user after UI confirmation
  Future<void> confirmAndCreateUser() async {
    if (state.isLoading || state.verificationData == null)
      return; // Need data from previous step

    final data = state.verificationData!;
    final email = data['email'] as String;
    final password = data['password'] as String;
    final displayName =
        data['name'] as String? ?? email; // Use name or default to email
    final salesforceId = data['salesforceId'] as String;

    state = state.copyWith(
      isLoading: true,
      loadingMessage: 'Creating User Account...',
      resetDialogTriggers: true, // Clear verification flag
      clearError: true,
    );

    try {
      final functionsService = FirebaseFunctionsService();
      final functionsAvailable = await functionsService.checkAvailability();
      if (!functionsAvailable) {
        throw Exception('Cloud Functions unavailable.');
      }

      state = state.copyWith(loadingMessage: 'Creating Firebase User...');
      final authRepository = _ref.read(authRepositoryProvider);
      // Make sure UserRole.reseller is accessible
      final newUser = await authRepository.createUserWithEmailAndPassword(
        email: email,
        password: password,
        role: UserRole.reseller,
        displayName: displayName,
      );

      state = state.copyWith(
        loadingMessage: 'Synchronizing with Salesforce...',
      );
      await _syncUserWithSalesforce(
        newUser.uid,
        salesforceId,
      ); // Internal helper

      if (kDebugMode)
        print(
          '[UserCreationNotifier] User created. Setting state to show success dialog.',
        );
      state = state.copyWith(
        isLoading: false,
        showSuccessDialog: true,
        successData: {
          'displayName': displayName,
          'email': email,
          'password': password,
        },
      );
    } catch (e) {
      if (kDebugMode)
        print('[UserCreationNotifier] Error caught during creation: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create user: ${e.toString()}',
        showErrorDialog: true,
      );
    }
  }

  // Internal helper to sync Salesforce data
  Future<void> _syncUserWithSalesforce(String uid, String salesforceId) async {
    // (This method remains largely the same, but doesn't need context or snackbars)
    try {
      await _firestore.collection('users').doc(uid).update({
        'salesforceId': salesforceId,
        'lastSalesforceSync': FieldValue.serverTimestamp(),
      });

      final syncService = SalesforceUserSyncService();
      final success = await syncService.syncSalesforceUserToFirebase(
        uid,
        salesforceId,
      );

      if (!success) {
        if (kDebugMode)
          print(
            '[UserCreationNotifier] Warning: Failed to sync all data from Salesforce.',
          );
        // Optionally update state with a non-blocking warning?
      }
    } catch (e) {
      if (kDebugMode)
        print(
          '[UserCreationNotifier] Warning: Error syncing data from Salesforce: $e',
        );
      // Optionally update state with a non-blocking warning?
    }
  }

  // --- Removed UI Helper Methods (_showVerificationDialog, _showSuccessDialog, _showErrorDialog, _showSnackbar) ---
}

// Provider definition remains the same
final userCreationProvider =
    StateNotifierProvider<UserCreationNotifier, UserCreationState>((ref) {
      return UserCreationNotifier(ref, FirebaseFirestore.instance);
    });
