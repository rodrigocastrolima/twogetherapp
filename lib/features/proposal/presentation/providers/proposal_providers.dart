import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../salesforce/data/repositories/salesforce_repository.dart';
import '../../data/models/salesforce_proposal.dart';

/// FutureProvider that fetches Salesforce proposals for a specific opportunity.
///
/// It takes the Salesforce Opportunity ID as a parameter.
final opportunityProposalsProvider =
    FutureProvider.family<List<SalesforceProposal>, String>((
      ref,
      opportunityId,
    ) async {
      // Watch the repository provider
      final repository = ref.watch(salesforceRepositoryProvider);

      // Call the repository method to get proposals
      return repository.getOpportunityProposals(opportunityId);
      // Error handling is implicitly managed by FutureProvider
    });
