import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../features/opportunity/data/models/salesforce_opportunity.dart';
import '../../../features/proposal/presentation/providers/proposal_providers.dart';
import '../../../features/proposal/data/models/salesforce_proposal.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class OpportunityDetailsPage extends ConsumerWidget {
  final SalesforceOpportunity opportunity;

  const OpportunityDetailsPage({super.key, required this.opportunity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    // Format CreatedDate for the Opportunity
    String formattedOpportunityDate = 'N/A';
    if (opportunity.CreatedDate != null) {
      try {
        final date = DateTime.parse(opportunity.CreatedDate!);
        formattedOpportunityDate = DateFormat.yMd(
          l10n?.localeName ?? 'en_US',
        ).format(date);
      } catch (e) {
        formattedOpportunityDate =
            opportunity.CreatedDate!; // Fallback to raw string if parse fails
      }
    }

    // --- Watch the proposals provider ---
    final proposalsAsync = ref.watch(
      opportunityProposalsProvider(opportunity.id),
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
                // Use LayoutBuilder to prevent unbounded height in Column
                return ListView.separated(
                  shrinkWrap:
                      true, // Important when inside Column/SingleChildScrollView
                  physics:
                      const NeverScrollableScrollPhysics(), // Disable nested scrolling
                  itemCount: proposals.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final proposal = proposals[index];
                    return _buildProposalTile(context, proposal);
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

  // Helper to build opportunity phase badge
  Widget _buildPhaseBadge(BuildContext context, String? phase) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color color;
    String displayPhase;

    // Map Salesforce phases to display text and colors
    if (phase == null) {
      color = theme.colorScheme.onSurfaceVariant;
      displayPhase = 'Não definido';
    } else if (phase.startsWith('0 -')) {
      color = Colors.orange;
      displayPhase = 'Identificada';
    } else if (phase.startsWith('1 -')) {
      color = theme.colorScheme.primary;
      displayPhase = 'Qualificada';
    } else if (phase.startsWith('2 -')) {
      color = Colors.blue;
      displayPhase = 'Proposta';
    } else if (phase.startsWith('3 -')) {
      color = Colors.indigo;
      displayPhase = 'Negociação';
    } else if (phase.startsWith('4 -')) {
      color = Colors.green;
      displayPhase = 'Fechada/Ganha';
    } else if (phase.startsWith('5 -')) {
      color = Colors.red;
      displayPhase = 'Fechada/Perdida';
    } else {
      color = theme.colorScheme.onSurfaceVariant;
      displayPhase = phase;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        displayPhase,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // --- NEW --- Helper to display status based on Phase
  Widget _buildStatusDisplay(BuildContext context, String? phase) {
    final theme = Theme.of(context);

    if (phase == '6 - Conclusão Ganho') {
      return Row(
        mainAxisSize: MainAxisSize.min, // Keep Row compact
        children: [
          Icon(
            CupertinoIcons.checkmark_seal_fill,
            color: Colors.green, // Use a success color
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            'Concluído', // Display friendly status
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else {
      // Fallback to the original phase badge for other statuses
      return _buildPhaseBadge(context, phase);
    }
  }

  // --- NEW Helper to build a proposal list tile ---
  Widget _buildProposalTile(BuildContext context, SalesforceProposal proposal) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: l10n?.localeName ?? 'pt_PT',
      symbol: '€',
    );
    final dateFormat = DateFormat.yMd(l10n?.localeName ?? 'pt_PT');

    // Safely parse creation date from the string field
    String createdDateString = 'N/A';
    try {
      final parsedDate = DateTime.parse(proposal.dataDeCriacao);
      createdDateString = dateFormat.format(parsedDate);
    } catch (_) {
      // Handle parsing error or keep 'N/A'
    }

    // Format commission
    String commissionString = 'N/A';
    if (proposal.totalComissaoRetail != null) {
      commissionString = currencyFormat.format(proposal.totalComissaoRetail);
    }

    return ListTile(
      title: Text(proposal.name, style: theme.textTheme.titleSmall),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status: ${proposal.status}'), // TODO: Localize Status
          Text('Comissão: $commissionString'), // TODO: Localize Comissão
          Text('Criação: $createdDateString'), // TODO: Localize Criação
          // Add more details like Valor Investimento if needed
        ],
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: () {
        // TODO: Implement navigation to proposal detail page or action
        print('Tapped on proposal: ${proposal.id}');
      },
    );
  }

  // -------------------------------------------
}
