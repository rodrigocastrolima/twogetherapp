import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For potential date formatting
import 'package:go_router/go_router.dart'; // Import GoRouter

import '../../data/models/detailed_salesforce_opportunity.dart';
import '../../data/models/salesforce_proposal.dart';
import '../providers/opportunity_providers.dart';

class AdminSalesforceOpportunityDetailPage extends ConsumerWidget {
  final String opportunityId;

  const AdminSalesforceOpportunityDetailPage({
    required this.opportunityId,
    super.key,
  });

  // Helper to format dates nicely (adjust format as needed)
  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateString);
      // Example format: 15 Jan 2024
      return DateFormat('dd MMM yyyy').format(dateTime.toLocal());
    } catch (e) {
      return dateString; // Return original string if parsing fails
    }
  }

  // --- ADDED: Navigation Helper --- //
  void _navigateToCreateProposal(
    BuildContext context,
    DetailedSalesforceOpportunity opp,
  ) {
    // Validate required IDs before navigating
    if (opp.id == null ||
        opp.accountId == null ||
        opp.resellerSalesforceId == null ||
        opp.nifC == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing required data to create a proposal.'),
          backgroundColor: Colors.orange,
        ), // TODO: l10n
      );
      return;
    }

    context.push(
      '/proposal/create', // Make sure this matches your GoRouter route
      extra: {
        'salesforceOpportunityId': opp.id, // Actual ID
        'salesforceAccountId': opp.accountId, // Actual ID
        'accountName': opp.accountName ?? 'N/A', // Pass name, handle null
        'resellerSalesforceId': opp.resellerSalesforceId, // Actual ID
        'resellerName': opp.resellerName ?? 'N/A', // Pass name, handle null
        'nif': opp.nifC, // Pass NIF
        'opportunityName': opp.name, // Pass Opp Name
      },
    );
  }
  // --- END Navigation Helper --- //

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detailsAsync = ref.watch(opportunityDetailsProvider(opportunityId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Opportunity Details'), // TODO: l10n
        actions: [
          // Show button only when data is loaded successfully
          detailsAsync.maybeWhen(
            data:
                (opportunityDetails) => IconButton(
                  icon: const Icon(
                    Icons.add_comment_outlined,
                  ), // Or another suitable icon
                  tooltip: 'Create Proposal', // TODO: l10n
                  onPressed:
                      () => _navigateToCreateProposal(
                        context,
                        opportunityDetails,
                      ),
                ),
            orElse: () => const SizedBox.shrink(), // Hide button otherwise
          ),
        ],
      ),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading details: \n$error',
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        data: (opportunityDetails) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildDetailSection(context, 'Core Information', [
                _buildDetailItem('Name', opportunityDetails.name),
                _buildDetailItem('Account', opportunityDetails.accountName),
                _buildDetailItem('Reseller', opportunityDetails.resellerName),
                _buildDetailItem('NIF', opportunityDetails.nifC),
              ]),
              const SizedBox(height: 16),
              _buildDetailSection(context, 'Status & Dates', [
                _buildDetailItem('Phase', opportunityDetails.faseC),
                _buildDetailItem(
                  'Created Date',
                  _formatDate(opportunityDetails.createdDate),
                ),
                _buildDetailItem(
                  'Est. Close Date',
                  _formatDate(opportunityDetails.dataDePrevisaoDeFechoC),
                ),
                _buildDetailItem(
                  'Opportunity Creation Date',
                  _formatDate(opportunityDetails.dataDeCriacaoDaOportunidadeC),
                ),
              ]),
              const SizedBox(height: 16),
              _buildDetailSection(context, 'Categorization', [
                _buildDetailItem(
                  'Opportunity Type',
                  opportunityDetails.tipoDeOportunidadeC,
                ),
                _buildDetailItem(
                  'Customer Segment',
                  opportunityDetails.segmentoDeClienteC,
                ),
                _buildDetailItem('Solution', opportunityDetails.soluOC),
              ]),
              const SizedBox(height: 24),
              _buildProposalsSection(context, opportunityDetails.proposals),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailSection(
    BuildContext context,
    String title,
    List<Widget> items,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150, // Adjust width as needed
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'), // Display N/A if value is null
          ),
        ],
      ),
    );
  }

  Widget _buildProposalsSection(
    BuildContext context,
    List<SalesforceProposal> proposals,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related Proposals', // TODO: l10n
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (proposals.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                'No proposals linked to this opportunity.', // TODO: l10n
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true, // Important inside ListView
            physics:
                const NeverScrollableScrollPhysics(), // Disable scrolling for inner list
            itemCount: proposals.length,
            itemBuilder: (context, index) {
              final proposal = proposals[index];
              return ListTile(
                dense: true,
                leading: Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: theme.colorScheme.secondary,
                ),
                title: Text(proposal.name),
                // Add subtitle later if more fields are needed (e.g., status)
                // subtitle: Text('Status: ${proposal.status ?? "N/A"}'),
                onTap: () {
                  // TODO: Navigate to Proposal Detail Page (if applicable)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Proposal detail view not implemented yet.',
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}
