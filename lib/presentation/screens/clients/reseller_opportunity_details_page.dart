import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../features/opportunity/data/models/salesforce_opportunity.dart';
import '../../../features/proposal/presentation/providers/proposal_providers.dart';
import '../../../features/proposal/data/models/salesforce_proposal_ref.dart';
import 'package:intl/intl.dart';

class OpportunityDetailsPage extends ConsumerWidget {
  final SalesforceOpportunity opportunity;

  const OpportunityDetailsPage({super.key, required this.opportunity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Format CreatedDate for the Opportunity
    String formattedOpportunityDate = 'N/A';
    if (opportunity.CreatedDate != null) {
      try {
        final date = DateTime.parse(opportunity.CreatedDate!);
        formattedOpportunityDate = DateFormat.yMd('pt_PT').format(date);
      } catch (e) {
        formattedOpportunityDate =
            opportunity.CreatedDate!; // Fallback to raw string if parse fails
      }
    }

    // --- Watch the NEW proposals provider ---
    final proposalsAsync = ref.watch(
      resellerOpportunityProposalNamesProvider(opportunity.id),
    );
    // -------------------------------------

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: Text(
          opportunity.accountName ?? opportunity.name,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with client name and status
            _buildHeader(context),

            const SizedBox(height: 24),

            // Opportunity Details Section
            _buildOpportunityDetailsSection(context, formattedOpportunityDate),

            const SizedBox(height: 24),

            // --- Proposals Section ---
            Text(
              'Propostas', // TODO: Add localization
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            proposalsAsync.when(
              data: (proposals) {
                if (proposals.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(
                        'Nenhuma proposta encontrada',
                      ), // TODO: Add localization
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: proposals.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final proposal = proposals[index];
                    return _buildProposalRefTile(context, proposal, index);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, stackTrace) => Center(
                    child: Text(
                      'Erro ao carregar propostas: $error',
                    ), // TODO: Add localization
                  ),
            ),
            // --------------------------
          ],
        ),
      ),
    );
  }

  // Header with client name and opportunity phase
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Client icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.building_2_fill,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Client name and status/phase
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opportunity.accountName ?? opportunity.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2, // Allow wrapping to two lines
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _buildStatusDisplay(
                    context,
                    opportunity.Fase__c,
                  ), // Use new status display method
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build the main opportunity details section
  Widget _buildOpportunityDetailsSection(
    BuildContext context,
    String formattedOpportunityDate,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detalhes da Oportunidade', // TODO: Add localization
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Use the new model fields
            _buildDetailRow(context, 'NIF', opportunity.NIF__c ?? 'N/A'),
            _buildDetailRow(
              context,
              'Fase',
              opportunity.Fase__c ?? 'N/A', // Display Fase__c
            ),
            _buildDetailRow(
              context,
              'Data de Criação',
              formattedOpportunityDate,
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build a detail row with label and value
  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  // --- Updated _buildStatusDisplay to only use needed phases ---
  Widget _buildStatusDisplay(BuildContext context, String? phase) {
    final theme = Theme.of(context);

    if (phase == '6 - Conclusão Ganho') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.checkmark_seal_fill,
            color: Colors.green,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            'Concluído', // TODO: Localize
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else if (phase == '6 - Conclusão Desistência Cliente') {
      // Added condition for Canceled by Client
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.clear_circled_solid, // Red cross icon
            color: Colors.red, // Use a error color
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            'Desistência Cliente', // Display friendly status TODO: Localize
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else {
      // For other phases, just display the text if needed, or simplify
      return Text(
        phase ?? 'Status não definido', // TODO: Localize
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      );
    }
  }
  // ---------------------------------------------------------

  // --- UPDATED Helper to build a proposal list tile using SalesforceProposalRef ---
  Widget _buildProposalRefTile(
    BuildContext context,
    SalesforceProposalRef proposal,
    int index,
  ) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        proposal.name,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(CupertinoIcons.chevron_right, size: 18),
      onTap: () {
        context.push(
          '/reseller-proposal-details',
          extra: {'proposalId': proposal.id, 'proposalName': proposal.name},
        );
      },
    );
  }
}
