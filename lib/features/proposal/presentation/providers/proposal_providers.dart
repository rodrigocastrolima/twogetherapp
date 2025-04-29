import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Corrected/Verified Imports
import 'package:twogether/features/auth/domain/models/app_user.dart';
import 'package:twogether/features/auth/presentation/providers/auth_provider.dart'; // Provides currentUserProvider
import 'package:twogether/core/services/salesforce_auth_service.dart'; // Provides SalesforceAuthNotifier
import 'package:twogether/features/opportunity/data/services/opportunity_service.dart';
import 'package:twogether/features/proposal/domain/salesforce_ciclo.dart';
import 'package:twogether/features/salesforce/data/repositories/salesforce_repository.dart';
import 'package:twogether/features/proposal/data/models/salesforce_proposal.dart'; // Keep if opportunityProposalsProvider is used here

// --- Service/Repository Providers ---

// Provider for SalesforceRepository
final salesforceRepositoryProvider = Provider<SalesforceRepository>((ref) {
  // Constructor takes optional FirebaseFunctions instance
  return SalesforceRepository(); // Use default instance
});

// Provider for OpportunityService
final opportunityServiceProvider = Provider<OpportunityService>((ref) {
  // Constructor takes optional FirebaseFunctions instance
  return OpportunityService(); // Use default instance
});

// Provider for SalesforceAuthNotifier (Assuming FlutterSecureStorage is provided elsewhere or default)
// You might already have a provider like this, adjust if needed.
final salesforceAuthNotifierProvider = StateNotifierProvider<
  SalesforceAuthNotifier,
  SalesforceAuthState
>((ref) {
  // Need FlutterSecureStorage instance. If not provided elsewhere, create default.
  final storage = FlutterSecureStorage();
  return SalesforceAuthNotifier(storage);
});

// --- Data Providers ---

// Provider to fetch proposals for a specific opportunity (if still needed in this file)
final opportunityProposalsProvider = FutureProvider.family<
  List<SalesforceProposal>,
  String
>((ref, opportunityId) async {
  final repository = ref.watch(salesforceRepositoryProvider);
  // SalesforceRepository.getOpportunityProposals likely needs accessToken/instanceUrl
  // This provider needs access to SalesforceAuthNotifier credentials
  final sfAuthNotifier = ref.watch(salesforceAuthNotifierProvider.notifier);
  final accessToken = sfAuthNotifier.currentAccessToken;
  final instanceUrl = sfAuthNotifier.currentInstanceUrl;

  if (accessToken == null || instanceUrl == null) {
    if (kDebugMode) {
      print("[opportunityProposalsProvider] Missing Salesforce credentials.");
    }
    throw Exception("Salesforce authentication required.");
  }
  // TODO: Update getOpportunityProposals in SalesforceRepository to accept credentials if needed
  return repository.getOpportunityProposals(
    opportunityId /*, accessToken, instanceUrl */,
  );
});

// Provider to get total reseller commission
final resellerTotalCommissionProvider = FutureProvider<double>((ref) async {
  // Get logged-in user's Salesforce ID (which is the Reseller ID for them)
  final AppUser? currentUser = ref.watch(currentUserProvider);
  final String? resellerId = currentUser?.salesforceId;

  if (resellerId == null || resellerId.isEmpty) {
    if (kDebugMode) {
      print(
        "[resellerTotalCommissionProvider] User not logged in or missing Salesforce ID.",
      );
    }
    // Return 0 or throw? Throwing might be better if commission is expected.
    // Returning 0.0 for now.
    return 0.0;
    // throw Exception("User not logged in or Salesforce ID missing.");
  }

  final salesforceRepo = ref.watch(salesforceRepositoryProvider);
  try {
    // Call with only resellerId as per method signature
    return await salesforceRepo.getTotalResellerCommission(resellerId);
  } catch (e) {
    if (kDebugMode) {
      print("Error fetching total reseller commission: $e");
    }
    // Check for session expiry (likely via FirebaseFunctionsException code)
    if (e is FirebaseFunctionsException &&
        (e.code == 'unauthenticated' ||
            e.message?.contains('INVALID_SESSION_ID') == true)) {
      if (kDebugMode) {
        print(
          "[resellerTotalCommissionProvider] Session expired detected. Signing out.",
        );
      }
      // Trigger logout using the SalesforceAuthNotifier provider
      ref.read(salesforceAuthNotifierProvider.notifier).signOut();
      throw Exception("Salesforce session expired. Please re-authenticate.");
    } else {
      // Rethrow other errors
      throw Exception("Failed to fetch total commission: $e");
    }
  }
});

// Provider to fetch Activation Cycles
final activationCyclesProvider = FutureProvider<List<SalesforceCiclo>>((
  ref,
) async {
  // Get Salesforce credentials from the SalesforceAuthNotifier
  final sfAuthNotifier = ref.watch(salesforceAuthNotifierProvider.notifier);
  final accessToken = sfAuthNotifier.currentAccessToken;
  final instanceUrl = sfAuthNotifier.currentInstanceUrl;

  // Check if credentials are valid
  final authState = ref.watch(salesforceAuthNotifierProvider);
  if (authState != SalesforceAuthState.authenticated ||
      accessToken == null ||
      instanceUrl == null) {
    if (kDebugMode) {
      print(
        "[activationCyclesProvider] Invalid Salesforce auth state or missing credentials.",
      );
    }
    throw Exception("Salesforce authentication required.");
  }

  final opportunityService = ref.watch(opportunityServiceProvider);

  try {
    // Call OpportunityService method which takes credentials
    return await opportunityService.getActivationCycles(
      accessToken: accessToken,
      instanceUrl: instanceUrl,
    );
  } catch (e) {
    if (kDebugMode) {
      print("Error fetching activation cycles: $e");
    }
    // Check for session expiry (service might throw specific exception or check details)
    if (e.toString().contains('session expired') ||
        (e is FirebaseFunctionsException && e.code == 'unauthenticated')) {
      if (kDebugMode) {
        print(
          "[activationCyclesProvider] Session expired detected. Signing out.",
        );
      }
      // Trigger logout
      ref.read(salesforceAuthNotifierProvider.notifier).signOut();
      throw Exception("Salesforce session expired. Please re-authenticate.");
    } else {
      // Rethrow other errors
      throw Exception("Failed to fetch activation cycles: $e");
    }
  }
});
