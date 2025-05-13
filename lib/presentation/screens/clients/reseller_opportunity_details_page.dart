import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/opportunity/data/models/salesforce_opportunity.dart';
import '../../../features/proposal/presentation/providers/proposal_providers.dart';
import '../../../features/proposal/data/models/salesforce_proposal_ref.dart';
import 'package:intl/intl.dart';
import '../../widgets/logo.dart';
import '../../../../core/theme/theme.dart';

// Helper function to determine color based on customer segment
Color _getSegmentColor(String? segment, ThemeData theme, bool isDark) {
  if (segment == null) {
    return isDark
        ? Colors.grey.shade800
        : Colors.grey.shade300; // Default for null segment
  }
  switch (segment) {
    case 'Cessou Actividade':
      return isDark ? Colors.grey.shade700 : Colors.grey.shade400;
    case 'Ouro':
      return const Color(0xFFFFD700); // Gold
    case 'Prata':
      return isDark
          ? const Color(0xFFC0C0C0)
          : const Color(0xFFAAAAAA); // Silver
    case 'Bronze':
      return const Color(0xFFCD7F32); // Bronze
    case 'Lata':
      return isDark ? Colors.blueGrey.shade400 : Colors.blueGrey.shade200;
    default:
      return isDark
          ? Colors.grey.shade800
          : Colors.grey.shade300; // Default for unknown segment
  }
}

// Helper class to hold status visual properties
class _ProposalStatusVisuals {
  final IconData iconData;
  final Color iconColor;
  final bool isInteractive;

  _ProposalStatusVisuals({
    required this.iconData,
    required this.iconColor,
    this.isInteractive = true,
  });
}

// Helper function to get icon and interactivity based on status
_ProposalStatusVisuals _getProposalStatusVisuals(
  String? status,
  ThemeData theme,
) {
  final bool isDark = theme.brightness == Brightness.dark;
  switch (status) {
    case 'Aceite':
      return _ProposalStatusVisuals(
        iconData: CupertinoIcons.checkmark_seal_fill,
        iconColor: Colors.green,
        isInteractive: true,
      );
    case 'Cancelada':
    case 'Não Aprovada':
      return _ProposalStatusVisuals(
        iconData: CupertinoIcons.xmark_seal_fill,
        iconColor: Colors.red,
        isInteractive: true,
      );
    case 'Expirada':
      return _ProposalStatusVisuals(
        iconData: CupertinoIcons.clock_fill,
        iconColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        isInteractive: false,
      );
    case 'Enviada':
    case 'Pendente':
    case 'Em Aprovação':
    case 'Aprovada':
    case 'Pricing Finalizado':
    case 'A Aguardar Pricing':
    case 'Risco Crédito Revisto':
    case 'Criação':
    case '--Nenhum --':
      return _ProposalStatusVisuals(
        iconData: CupertinoIcons.doc_text,
        iconColor: theme.colorScheme.onSurfaceVariant,
        isInteractive: true,
      );
    default:
      return _ProposalStatusVisuals(
        iconData: CupertinoIcons.question_circle,
        iconColor: theme.colorScheme.onSurfaceVariant,
        isInteractive: true,
      );
  }
}

class OpportunityDetailsPage extends ConsumerWidget {
  final SalesforceOpportunity opportunity;

  const OpportunityDetailsPage({super.key, required this.opportunity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Format CreatedDate for the Opportunity
    String formattedOpportunityDate = 'N/A';
    if (opportunity.createdDate != null) {
      try {
        final date = DateTime.parse(opportunity.createdDate!);
        formattedOpportunityDate = DateFormat.yMd('pt_PT').format(date);
      } catch (e) {
        formattedOpportunityDate =
            opportunity.createdDate!; // Fallback to raw string if parse fails
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
          icon: Icon(
            CupertinoIcons.chevron_left,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => context.pop(),
        ),
        title: LogoWidget(height: 60, darkMode: isDark),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with client name and status
            _buildClientIdentificationHeader(
              context,
              opportunity,
              theme,
              isDark,
            ),

            const SizedBox(height: 24),

            // Opportunity Details Section
            _buildOpportunityDetailsSection(context, formattedOpportunityDate),

            const SizedBox(height: 24),

            // --- Proposals Section ---
            Text(
              'Propostas', // TODO: Add localization
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
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
                // Reverse the list so oldest proposals are first
                final displayedProposals = proposals.reversed.toList();

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedProposals.length,
                  separatorBuilder: (_, __) => const SizedBox.shrink(),
                  itemBuilder: (context, index) {
                    final proposal = displayedProposals[index];
                    // Pass the index directly for chronological numbering (oldest = 1)
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
  Widget _buildClientIdentificationHeader(
    BuildContext context,
    SalesforceOpportunity opportunity,
    ThemeData theme,
    bool isDark,
  ) {
    final segmentColor = _getSegmentColor(
      opportunity.segmentoDeClienteC,
      theme,
      isDark,
    );
    final iconColor =
        isDark ? Colors.white : Colors.black; // Simple contrast for now

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: segmentColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((255 * 0.1).round()),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(CupertinoIcons.person_fill, color: iconColor, size: 50),
          ),
          const SizedBox(height: 16),
          Text(
            opportunity.accountName ?? opportunity.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // Build the main opportunity details section
  Widget _buildOpportunityDetailsSection(
    BuildContext context,
    String formattedOpportunityDate,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalhes',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(context, 'NIF', opportunity.nifC ?? 'N/A'),
          _buildDetailRow(
            context,
            'Data de Início',
            opportunity.createdDate != null
                ? DateFormat(
                  'dd/MM/yyyy',
                ).format(DateTime.parse(opportunity.createdDate!))
                : 'N/A',
          ),
        ],
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

  // --- UPDATED Helper to build a proposal list tile using SalesforceProposalRef ---
  Widget _buildProposalRefTile(
    BuildContext context,
    SalesforceProposalRef proposal,
    int index, // totalProposals removed
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shadowColor =
        isDark
            ? Colors.black.withAlpha((255 * 0.15).round())
            : Colors.grey.withAlpha((255 * 0.2).round());

    final statusVisuals = _getProposalStatusVisuals(proposal.statusC, theme);
    // Numbering is now index + 1 because the list is reversed (oldest is index 0)
    final titleText = 'Proposta ${index + 1}';
    // Format creation date if available
    String subtitleText = proposal.statusC ?? 'Status desconhecido';
    if (proposal.dataDeCriacaoDaPropostaC != null) {
      try {
        final date = DateTime.parse(proposal.dataDeCriacaoDaPropostaC!);
        final formattedDate = DateFormat('dd/MM/yy').format(date);
        subtitleText = '${proposal.statusC ?? "N/A"} - $formattedDate';
      } catch (e) {
        // Keep subtitle as just status if date parsing fails
      }
    }

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      color: theme.cardColor,
      shadowColor: shadowColor,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 10.0,
        ),
        leading: Icon(
          statusVisuals.iconData,
          color: statusVisuals.iconColor,
          size: 28,
        ),
        title: Text(
          titleText,
          style: theme.textTheme.titleMedium?.copyWith(
            // Using titleMedium for a bit more emphasis
            fontWeight: FontWeight.w600,
            color:
                statusVisuals.isInteractive
                    ? (isDark ? AppTheme.darkForeground : AppTheme.foreground)
                    : (isDark
                        ? AppTheme.darkMutedForeground
                        : AppTheme
                            .mutedForeground), // Grey out if not interactive
          ),
        ),
        subtitle: Text(
          subtitleText,
          style: theme.textTheme.bodySmall?.copyWith(
            color:
                statusVisuals.isInteractive
                    ? (isDark
                        ? AppTheme.darkMutedForeground.withAlpha(200)
                        : AppTheme.mutedForeground.withAlpha(200))
                    : (isDark
                        ? AppTheme.darkMutedForeground.withAlpha(150)
                        : AppTheme.mutedForeground.withAlpha(
                          150,
                        )), // Grey out more if not interactive
          ),
        ),
        trailing:
            statusVisuals.isInteractive
                ? Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color:
                      isDark
                          ? AppTheme.darkMutedForeground
                          : AppTheme.mutedForeground,
                )
                : null, // No chevron if not interactive
        onTap:
            statusVisuals.isInteractive
                ? () {
                  context.push(
                    '/reseller-proposal-details',
                    extra: {
                      'proposalId': proposal.id,
                      'proposalName': proposal.name,
                    }, // Pass original name for detail page title
                  );
                }
                : null, // Disable tap if not interactive
      ),
    );
  }
}
