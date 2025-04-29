import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/theme/theme.dart';
import '../../data/models/salesforce_proposal.dart';
import '../providers/proposal_providers.dart';

class ProposalDetailPage extends ConsumerWidget {
  // Accept full proposal object and index directly
  final SalesforceProposal proposal;
  final int index;

  const ProposalDetailPage({
    super.key,
    required this.proposal,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // No need to fetch, use the passed proposal object directly

    return Scaffold(
      appBar: AppBar(
        title: Text('Proposta #${index + 1}'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProposalInfoSection(context, theme, l10n, proposal, index),
            const SizedBox(height: 24),
            _buildFilesSection(context, theme, l10n),
            const SizedBox(height: 24),
            _buildActionsSection(context, theme, l10n, proposal),
          ],
        ),
      ),
    );
  }

  Widget _buildProposalInfoSection(
    BuildContext context,
    ThemeData theme,
    AppLocalizations? l10n,
    SalesforceProposal proposal,
    int index,
  ) {
    final dateFormat = DateFormat.yMd(l10n?.localeName ?? 'pt_PT');
    final currencyFormat = NumberFormat.currency(
      locale: l10n?.localeName ?? 'pt_PT',
      symbol: '€',
    );
    final commissionString =
        proposal.totalComissaoRetail != null
            ? currencyFormat.format(proposal.totalComissaoRetail)
            : 'N/A';

    // Format validity date
    String validityDateString = 'N/A';
    try {
      final parsedDate = DateTime.parse(proposal.dataDeValidade);
      validityDateString = dateFormat.format(parsedDate);
    } catch (_) {
      // Handle parsing error or keep 'N/A' if format is unexpected
      validityDateString = proposal.dataDeValidade; // Fallback to raw string
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Proposta #${index + 1}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      'Status:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: _buildStatusWidget(context, proposal.status)),
                ],
              ),
            ),
            _buildDetailRow(context, 'Comissão', commissionString),
            _buildDetailRow(context, 'Data de Validade', validityDateString),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesSection(
    BuildContext context,
    ThemeData theme,
    AppLocalizations? l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ficheiros da Proposta',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        // TODO: Fetch and display list of files associated with the proposal
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text('Nenhum ficheiro encontrado.'),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection(
    BuildContext context,
    ThemeData theme,
    AppLocalizations? l10n,
    SalesforceProposal proposal,
  ) {
    // Only show actions if proposal is in a state that allows them (e.g., not 'Aceite' or 'Cancelada')
    bool canTakeAction =
        proposal.status != 'Aceite' &&
        proposal.status != 'Cancelada'; // Example logic

    if (!canTakeAction) {
      return const SizedBox.shrink(); // Don't show buttons if no action can be taken
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(CupertinoIcons.clear_thick),
            label: const Text('Rejeitar'),
            onPressed: () {
              // TODO: Implement reject logic
              print('Reject proposal: ${proposal.id}');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(CupertinoIcons.check_mark_circled),
            label: const Text('Aceitar'),
            onPressed: () {
              // TODO: Implement accept logic
              print('Accept proposal: ${proposal.id}');
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: theme.colorScheme.onPrimary,
              backgroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // Helper from opportunity details page (can be moved to a shared location)
  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120, // Adjust width as needed
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

  // --- Status Widget (Similar to the one in Opportunity Details) ---
  Widget _buildStatusWidget(BuildContext context, String status) {
    final theme = Theme.of(context);
    if (status == 'Aceite') {
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
            'Aceite',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else if (status == 'Cancelada') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.clear_circled_solid, color: Colors.red, size: 16),
          const SizedBox(width: 4),
          Text(
            'Cancelada',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else {
      // Default text display for other statuses
      return Text(status, style: theme.textTheme.bodyMedium);
    }
  }

  // -----------------------------------------------------------------
}
