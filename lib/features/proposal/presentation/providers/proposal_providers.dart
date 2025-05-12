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
import 'package:twogether/features/proposal/data/models/salesforce_proposal_ref.dart'; // <-- Import new model
import 'package:twogether/features/proposal/data/models/detailed_salesforce_proposal.dart';
import 'package:twogether/features/proposal/data/repositories/salesforce_proposal_repository.dart';
import 'package:twogether/features/proposal/data/models/salesforce_proposal_data.dart'; // Import the direct return type

// --- Service/Repository Providers ---

// Provider for SalesforceRepository
final salesforceRepositoryProvider = Provider<SalesforceRepository>((ref) {
  // Constructor takes optional FirebaseFunctions instance
  return SalesforceRepository(); // Use default instance
});

// Provider for OpportunityService
final proposalServiceProvider = Provider<OpportunityService>((ref) {
  // Get the dependencies needed by OpportunityService
  final authNotifier = ref.watch(salesforceAuthProvider.notifier);
  final functions = FirebaseFunctions.instance;

  // Pass the required authNotifier argument
  return OpportunityService(
    authNotifier: authNotifier,
    functions: functions, // Pass functions instance as well
  );
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

// Provider for the SalesforceProposalRepository instance
final salesforceProposalServiceProvider =
    Provider<SalesforceProposalRepository>((ref) {
      return SalesforceProposalRepository();
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

// --- NEW Provider for Reseller Proposal Names (JWT Flow) ---
final resellerOpportunityProposalNamesProvider =
    FutureProvider.family<List<SalesforceProposalRef>, String>((
      ref,
      opportunityId,
    ) async {
      // Get the repository instance
      final repository = ref.watch(salesforceRepositoryProvider);

      // Call the NEW repository method (uses JWT Cloud Function)
      // Method name is still the same, but its internal return type is updated
      return repository.getResellerOpportunityProposalNames(opportunityId);
    });
// ----------------------------------------------------------

// --- NEW Provider for Reseller Proposal DETAILS (JWT Flow) ---
final resellerProposalDetailsProvider = FutureProvider.family<
  SalesforceProposalData, // Now returns the proposal data directly
  String // Takes proposalId as argument
>((ref, proposalId) async {
  // Get the repository instance
  final repository = ref.watch(salesforceRepositoryProvider);

  // Call the repository method (which now returns SalesforceProposalData)
  return repository.getResellerProposalDetails(proposalId);
});
// -----------------------------------------------------------

// Provider to get total reseller commission
final resellerTotalCommissionProvider = FutureProvider<double>((ref) async {
  // Watch the current user provider's state (returns AppUser?)
  final AppUser? currentUser = ref.watch(currentUserProvider);

  // --- Enhanced Debug Logging ---
  if (kDebugMode) {
    final userId = currentUser?.uid ?? 'null';
    // Try getting ID directly from additionalData
    final sfIdFromData = currentUser?.additionalData['salesforceId'] as String?;
    final additionalDataKeys = currentUser?.additionalData.keys.toList() ?? [];
    print(
      '[resellerTotalCommissionProvider] Checking user state: currentUser=${currentUser != null}, userId=$userId, sfIdFromData=$sfIdFromData, additionalDataKeys=$additionalDataKeys',
    );
  }
  // --- End Enhanced Debug Logging ---

  // Get the Salesforce ID DIRECTLY from the additionalData map
  final String? resellerId =
      currentUser?.additionalData['salesforceId'] as String?;

  // If no user or no Salesforce ID yet, return 0.0.
  // The provider will re-run when currentUserProvider updates with the ID.
  if (currentUser == null || resellerId == null || resellerId.isEmpty) {
    if (kDebugMode) {
      print(
        "[resellerTotalCommissionProvider] User not logged in or missing Salesforce ID. Waiting for update...",
      );
    }
    // Return 0.0 for now. UI will show loading/placeholder until this provider
    // re-runs with a valid ID and returns the actual future.
    return 0.0;
  }

  // If we have the resellerId, proceed with fetching the commission
  if (kDebugMode) {
    print(
      "[resellerTotalCommissionProvider] User logged in with Salesforce ID: $resellerId. Fetching commission...",
    );
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

  final opportunityService = ref.watch(proposalServiceProvider);

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

// FutureProvider to fetch detailed proposal data
// It's a family provider because it depends on the proposalId
final proposalDetailsProvider = FutureProvider.autoDispose
    .family<DetailedSalesforceProposal, String>((ref, proposalId) async {
      // Get the authentication state and notifier
      final authNotifier = ref.watch(salesforceAuthProvider.notifier);
      final authState = ref.watch(salesforceAuthProvider);

      // Ensure authenticated before proceeding
      if (authState != SalesforceAuthState.authenticated) {
        throw Exception('User is not authenticated with Salesforce.');
      }

      // Get valid credentials
      final accessToken = await authNotifier.getValidAccessToken();
      final instanceUrl = authNotifier.currentInstanceUrl;

      if (accessToken == null || instanceUrl == null) {
        throw Exception('Could not retrieve Salesforce credentials.');
      }

      // Get the repository instance
      final repository = ref.watch(salesforceProposalServiceProvider);

      // Fetch the data
      try {
        final details = await repository.getProposalDetails(
          accessToken: accessToken,
          instanceUrl: instanceUrl,
          proposalId: proposalId,
        );
        return details;
      } catch (e) {
        // Rethrow the error to be caught by the UI
        // Consider more specific error handling/logging here if needed
        print('Error fetching proposal details in provider: $e');
        rethrow;
      }
    });
