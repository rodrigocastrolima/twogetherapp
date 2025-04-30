import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../../app/router/app_router.dart';
import '../../../salesforce/data/repositories/salesforce_repository.dart';
import '../../data/models/create_opp_models.dart';
import '../../data/services/opportunity_service.dart';
import '../../data/models/salesforce_opportunity.dart';
import '../../../../core/services/salesforce_auth_service.dart';
import '../../data/models/detailed_salesforce_opportunity.dart';
import 'package:cloud_functions/cloud_functions.dart'; // Needed for FirebaseFunctions.instance

/// FutureProvider that fetches Salesforce opportunities for the logged-in reseller
///
/// This provider automatically uses the salesforceId from AuthNotifier
/// and calls the SalesforceRepository to fetch opportunities
/// Uses the SalesforceOpportunity MODEL
final resellerOpportunitiesProvider = FutureProvider<
  List<SalesforceOpportunity>
>((ref) async {
  try {
    // Get the repository
    final repository = ref.watch(salesforceRepositoryProvider);

    // Get the current user's Salesforce ID from AuthNotifier
    final salesforceId = AppRouter.authNotifier.salesforceId;

    if (kDebugMode) {
      print('resellerOpportunitiesProvider: Using salesforceId: $salesforceId');
    }

    // Validate the Salesforce ID
    if (salesforceId == null || salesforceId.isEmpty) {
      if (kDebugMode) {
        print(
          'resellerOpportunitiesProvider: No salesforceId available for current user',
        );
      }
      return Future.value([]); // Return a Future containing an empty list
    }

    // Call the repository to fetch opportunities
    final opportunities = await repository.getResellerOpportunities(
      salesforceId,
    );

    if (kDebugMode) {
      print(
        'resellerOpportunitiesProvider: Fetched ${opportunities.length} opportunities',
      );
    }

    // Revert back to simple return
    return opportunities;
  } catch (e) {
    if (kDebugMode) {
      print('resellerOpportunitiesProvider: Error fetching opportunities: $e');
    }
    // Re-throw the error so it's captured in the AsyncValue
    rethrow;
  }
});

/// Provider for filtering and searching opportunities
///
/// This provider depends on resellerOpportunitiesProvider and adds filtering logic
/// Uses the SalesforceOpportunity MODEL
final filteredOpportunitiesProvider = Provider.family<
  List<SalesforceOpportunity>,
  String
>((ref, searchQuery) {
  // Watch the opportunities list (handles loading/error states in the UI)
  final opportunitiesAsync = ref.watch(resellerOpportunitiesProvider);

  // Return an empty list while loading or if there's an error
  return opportunitiesAsync.when(
    data: (opportunities) {
      // If search query is empty, return all opportunities
      if (searchQuery.isEmpty) {
        return opportunities;
      }

      // Convert search query to lowercase for case-insensitive search
      final query = searchQuery.toLowerCase();

      // Filter opportunities based on search query
      return opportunities.where((opportunity) {
        // Search by opportunity name (using the MODEL field)
        // Add null check or default value for safety
        final nameMatch = (opportunity.name).toLowerCase().contains(query);

        // Search by client/account name (using the MODEL field)
        // Add null check and default value
        final accountNameMatch = (opportunity.accountName ?? '')
            .toLowerCase()
            .contains(query);

        // Search by NIF if available (using the MODEL field - assuming NIF is needed)
        // Let's assume the SalesforceOpportunity model *doesn't* have NIF for now
        // final nifMatch =
        //     (opportunity.nif ?? '').toLowerCase().contains(query);

        // Return true if any field matches
        // Adjust based on fields available in SalesforceOpportunity model
        return nameMatch || accountNameMatch; // || nifMatch;
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Provider for the SalesforceRepository itself (assuming it's defined elsewhere or create basic one)
// Example: final salesforceRepositoryProvider = Provider((ref) => SalesforceRepository());
// Ensure you have a provider that provides SalesforceRepository instance.

// --- Provider for Creating Salesforce Opportunity ---

final createOpportunityProvider =
    FutureProvider.family<CreateOppResult, CreateOppParams>((
      ref,
      params,
    ) async {
      // Get the repository instance
      final repository = ref.watch(
        salesforceRepositoryProvider,
      ); // Ensure this provider exists!

      // Call the repository method
      return repository.createSalesforceOpportunity(params);
    });

// --- NEW Providers for Admin SF Opportunity Management ---

/// Provides an instance of the OpportunityService.
final salesforceOpportunityServiceProvider = Provider<OpportunityService>((
  ref,
) {
  // Get dependencies required by OpportunityService constructor
  final authNotifier = ref.watch(salesforceAuthProvider.notifier);
  final functions = FirebaseFunctions.instance; // Use default instance

  // Correctly instantiate OpportunityService with dependencies
  return OpportunityService(authNotifier: authNotifier, functions: functions);
});

/// FutureProvider to fetch the list of existing Salesforce Opportunities for Admin view.
/// Uses the SalesforceOpportunity MODEL
final salesforceOpportunitiesProvider = FutureProvider<
  List<SalesforceOpportunity>
>((ref) async {
  // Watch the Salesforce Auth provider to get token/URL
  final sfAuthNotifier = ref.watch(salesforceAuthProvider.notifier);
  final sfAuthState = ref.watch(salesforceAuthProvider);

  // Don't fetch if not authenticated
  if (sfAuthState != SalesforceAuthState.authenticated) {
    if (kDebugMode) {
      print(
        '[salesforceOpportunitiesProvider] Not authenticated, returning empty list.',
      );
    }
    // Consider throwing an error instead? Depends on UI handling.
    // throw Exception("User is not authenticated with Salesforce.");
    return [];
  }

  // Get access token (this might trigger refresh if needed)
  final String? accessToken = await sfAuthNotifier.getValidAccessToken();
  final String? instanceUrl = sfAuthNotifier.currentInstanceUrl;

  // Check if token/URL retrieval was successful
  if (accessToken == null || instanceUrl == null) {
    if (kDebugMode) {
      print(
        '[salesforceOpportunitiesProvider] Failed to get valid access token or instance URL.',
      );
    }
    // Throw an error because we expected tokens but couldn't get them
    throw Exception("Could not retrieve valid Salesforce credentials.");
  }

  // Get the service and call the fetch method
  final service = ref.read(salesforceOpportunityServiceProvider);
  try {
    final opportunities = await service.fetchSalesforceOpportunities(
      accessToken: accessToken,
      instanceUrl: instanceUrl,
    );
    if (kDebugMode) {
      print(
        '[salesforceOpportunitiesProvider] Fetched ${opportunities.length} opportunities.',
      );
    }
    return opportunities;
  } catch (e) {
    if (kDebugMode) {
      print(
        '[salesforceOpportunitiesProvider] Error fetching opportunities: $e',
      );
    }
    // Re-throw the error to be handled by the provider's error state
    rethrow;
  }
});

/// FutureProvider.family to fetch the DETAILS of a single Salesforce Opportunity.
/// Takes the opportunityId as a parameter.
/// Uses the DetailedSalesforceOpportunity MODEL.
final opportunityDetailsProvider = FutureProvider.family<
  DetailedSalesforceOpportunity,
  String
>((ref, opportunityId) async {
  // Watch the Salesforce Auth provider to get token/URL
  final sfAuthNotifier = ref.watch(salesforceAuthProvider.notifier);
  final sfAuthState = ref.watch(salesforceAuthProvider);

  // Don't fetch if not authenticated
  if (sfAuthState != SalesforceAuthState.authenticated) {
    if (kDebugMode) {
      print(
        '[opportunityDetailsProvider($opportunityId)] Not authenticated, throwing error.',
      );
    }
    throw Exception("User is not authenticated with Salesforce.");
  }

  // Get access token (this might trigger refresh if needed)
  final String? accessToken = await sfAuthNotifier.getValidAccessToken();
  final String? instanceUrl = sfAuthNotifier.currentInstanceUrl;

  // Check if token/URL retrieval was successful
  if (accessToken == null || instanceUrl == null) {
    if (kDebugMode) {
      print(
        '[opportunityDetailsProvider($opportunityId)] Failed to get valid access token or instance URL.',
      );
    }
    throw Exception("Could not retrieve valid Salesforce credentials.");
  }

  // Get the service and call the fetch method
  final service = ref.read(salesforceOpportunityServiceProvider);
  try {
    if (kDebugMode) {
      print('[opportunityDetailsProvider($opportunityId)] Calling service...');
    }
    final details = await service.getOpportunityDetails(
      accessToken: accessToken,
      instanceUrl: instanceUrl,
      opportunityId: opportunityId, // Pass the family parameter
    );
    if (kDebugMode) {
      print(
        '[opportunityDetailsProvider($opportunityId)] Successfully fetched details.',
      );
    }
    return details;
  } catch (e) {
    if (kDebugMode) {
      print(
        '[opportunityDetailsProvider($opportunityId)] Error fetching details: $e',
      );
    }
    // Re-throw the error to be handled by the provider's error state
    rethrow;
  }
});
