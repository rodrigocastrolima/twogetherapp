import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../data/services/firebase_functions_service.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/cloud_functions_provider.dart';

// Provider for the Firebase Functions Service
final firebaseFunctionsServiceProvider = Provider<FirebaseFunctionsService>((
  ref,
) {
  return FirebaseFunctionsService();
});

// Provider for the AuthRepository implementation
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final functionsService = ref.watch(firebaseFunctionsServiceProvider);
  final cloudFunctionsAvailable = ref.watch(cloudFunctionsAvailableProvider);

  return FirebaseAuthRepository(
    firebaseAuth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    functionsService: functionsService,
    useCloudFunctions: cloudFunctionsAvailable, // Use the availability provider
  );
});

// Provider for the current user - returns null if not authenticated
final currentUserProvider = Provider<AppUser?>((ref) {
  // Watch the authStateChangesProvider to get the full AppUser object
  // This will include the role and additionalData (like salesforceId) from Firestore
  return ref
      .watch(authStateChangesProvider)
      .when(
        data: (user) => user,
        loading:
            () => null, // Or potentially the previous user state if desired
        error: (error, stack) => null, // Handle error appropriately
      );
});

// Stream provider for authentication state changes
final authStateChangesProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// Provider to determine if the user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref
      .watch(authStateChangesProvider)
      .maybeWhen(data: (user) => user != null, orElse: () => false);
});

// Provider to determine if the user is an admin
final isAdminProvider = Provider<bool>((ref) {
  return ref
      .watch(authStateChangesProvider)
      .maybeWhen(
        data: (user) => user?.role == UserRole.admin,
        orElse: () => false,
      );
});

// Provider to determine if the user is a reseller
final isResellerProvider = Provider<bool>((ref) {
  return ref
      .watch(authStateChangesProvider)
      .maybeWhen(
        data: (user) => user?.role == UserRole.reseller,
        orElse: () => false,
      );
});

// Provider to check if this is the user's first login
final isFirstLoginProvider = Provider<bool>((ref) {
  return ref
      .watch(authStateChangesProvider)
      .maybeWhen(
        data: (user) => user?.isFirstLogin ?? false,
        orElse: () => false,
      );
});
