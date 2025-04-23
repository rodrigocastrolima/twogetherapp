import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../../app/router/app_router.dart';
import '../../../salesforce/data/repositories/salesforce_repository.dart';
import '../pages/salesforce_opportunity.dart';
import '../../data/models/create_opp_models.dart';

/// FutureProvider that fetches Salesforce opportunities for the logged-in reseller
///
/// This provider automatically uses the salesforceId from AuthNotifier
/// and calls the SalesforceRepository to fetch opportunities
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
      return []; // Return empty list if no ID is available
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
final filteredOpportunitiesProvider =
    Provider.family<List<SalesforceOpportunity>, String>((ref, searchQuery) {
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
            // Search by opportunity name
            final nameMatch = opportunity.name.toLowerCase().contains(query);

            // Search by client/account name
            final clientNameMatch =
                opportunity.Nome_Entidade__c != null &&
                opportunity.Nome_Entidade__c!.toLowerCase().contains(query);

            // Search by NIF if available
            final nifMatch =
                opportunity.NIF__c != null &&
                opportunity.NIF__c!.toLowerCase().contains(query);

            // Return true if any field matches
            return nameMatch || clientNameMatch || nifMatch;
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

final createOpportunityProvider = FutureProvider.family<CreateOppResult, CreateOppParams>(
  (ref, params) async {
    // Get the repository instance
    final repository = ref.watch(salesforceRepositoryProvider); // Ensure this provider exists!
    
    // Call the repository method
    return repository.createSalesforceOpportunity(params);
  },
);
