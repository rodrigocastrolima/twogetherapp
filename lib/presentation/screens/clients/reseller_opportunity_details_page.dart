import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/opportunity/data/models/salesforce_opportunity.dart';
import '../../../features/proposal/presentation/providers/proposal_providers.dart';
import '../../../features/proposal/data/models/salesforce_cpe_proposal_data.dart';
import 'package:intl/intl.dart';
import '../../widgets/logo.dart';
import '../../widgets/simple_list_item.dart';
import '../../widgets/standard_app_bar.dart';
import '../../../../core/theme/theme.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/notifications/data/repositories/notification_repository.dart';
import './submit_proposal_documents_page.dart';
import '../../widgets/secure_file_viewer.dart';
import '../../widgets/success_dialog.dart';
import '../../../core/services/file_icon_service.dart';

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

  _ProposalStatusVisuals({
    required this.iconData,
    required this.iconColor,
  });
}

// Helper function to get icon and interactivity based on status
_ProposalStatusVisuals _getProposalStatusVisuals(
  String? status,
  ThemeData theme,
) {
  switch (status) {
    case 'Aceite':
      return _ProposalStatusVisuals(
        iconData: Icons.check_circle,
        iconColor: Colors.green[700]!,
      );
    case 'Enviada':
    case 'Em Aprovação':
      return _ProposalStatusVisuals(
        iconData: Icons.pending_actions,
        iconColor: Colors.blue[700]!,
      );
    case 'Cancelada':
    case 'Não Aprovada':
      return _ProposalStatusVisuals(
        iconData: Icons.cancel,
        iconColor: Colors.red[700]!,
      );
    case 'Expirada':
    case 'Aprovada':
      return _ProposalStatusVisuals(
        iconData: Icons.schedule,
        iconColor: Colors.orange[700]!,
      );
    case 'Pendente':
    case 'Pricing Finalizado':
    case 'A Aguardar Pricing':
    case 'Risco Crédito Revisto':
    case 'Criação':
    case '--Nenhum --':
      return _ProposalStatusVisuals(
        iconData: Icons.description,
        iconColor: theme.colorScheme.onSurfaceVariant,
      );
    default:
      return _ProposalStatusVisuals(
        iconData: Icons.description,
        iconColor: theme.colorScheme.onSurfaceVariant,
      );
  }
}

class OpportunityDetailsPage extends ConsumerStatefulWidget {
  final SalesforceOpportunity opportunity;
  final String? heroTag;

  const OpportunityDetailsPage({
    super.key, 
    required this.opportunity,
    this.heroTag,
  });

  @override
  ConsumerState<OpportunityDetailsPage> createState() => _OpportunityDetailsPageState();
}

class _OpportunityDetailsPageState extends ConsumerState<OpportunityDetailsPage> {
  String? _selectedProposalId;
  String? _selectedProposalName;

  String _getDisplayDate() {
    // Try multiple date sources in order of preference
    String? dateToUse;
    
    // 1. Try createdDate first
    if (widget.opportunity.createdDate != null && widget.opportunity.createdDate!.isNotEmpty) {
      dateToUse = widget.opportunity.createdDate;
    }
    // 2. Fallback to first proposal's creation date if available
    else if (widget.opportunity.propostasR?.records.isNotEmpty == true) {
      final firstProposal = widget.opportunity.propostasR!.records.first;
      if (firstProposal.dataDeCriacaoDaPropostaC != null && firstProposal.dataDeCriacaoDaPropostaC!.isNotEmpty) {
        dateToUse = firstProposal.dataDeCriacaoDaPropostaC;
      }
    }
    
    if (dateToUse != null) {
      try {
        final parsedDate = DateTime.parse(dateToUse);
        return DateFormat('dd/MM/yyyy').format(parsedDate);
      } catch (e) {
        // If parsing fails, return the original string
        return dateToUse;
      }
    }
    
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // --- Watch the NEW proposals provider ---
    final proposalsAsync = ref.watch(
      resellerOpportunityProposalNamesProvider(widget.opportunity.id),
    );
    // -------------------------------------

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const StandardAppBar(
        showBackButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                // --- Centered Header ---
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _getSegmentColor(widget.opportunity.segmentoDeClienteC, theme, isDark),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha((255 * 0.1).round()),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(CupertinoIcons.person_fill, color: isDark ? Colors.white : Colors.black, size: 40),
            ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          widget.opportunity.accountName ?? widget.opportunity.name,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('NIF:', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 6),
                                Text(widget.opportunity.nifC ?? 'N/A', style: theme.textTheme.bodyMedium),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Data de Início:', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 6),
                                Text(
                                  _getDisplayDate(),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
            Text(
                  'Propostas',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
                const SizedBox(height: 12),
            proposalsAsync.when(
              data: (proposals) {
                if (proposals.isEmpty) {
                  return const Center(
                    child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Text('Nenhuma proposta encontrada'),
                    ),
                  );
                }
                final displayedProposals = proposals.reversed.toList();
                    List<Widget> proposalWidgets = [];
                    for (int index = 0; index < displayedProposals.length; index++) {
                    final proposal = displayedProposals[index];
                      final statusVisuals = _getProposalStatusVisuals(proposal.statusC, theme);
                      final titleText = 'Proposta ${index + 1}';
                      String subtitleText = proposal.statusC ?? 'Status desconhecido';
                      if (proposal.dataDeCriacaoDaPropostaC != null) {
                        try {
                          final date = DateTime.parse(proposal.dataDeCriacaoDaPropostaC!);
                          final formattedDate = DateFormat('dd/MM/yy').format(date);
                          subtitleText = '${proposal.statusC ?? "N/A"} - $formattedDate';
                        } catch (e) {/* ignore parse errors, fallback to status only */}
                      }
                      proposalWidgets.add(
                        SimpleListItem(
                          leading: Icon(statusVisuals.iconData, color: statusVisuals.iconColor, size: 24),
                          title: titleText,
                          subtitle: subtitleText,
                          trailing: Center(
                            child: Icon(CupertinoIcons.chevron_right, size: 16, color: isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground),
                          ),
                          onTap: () {
                            setState(() {
                              if (_selectedProposalId == proposal.id) {
                                _selectedProposalId = null;
                                _selectedProposalName = null;
                              } else {
                                _selectedProposalId = proposal.id;
                                _selectedProposalName = proposal.name;
                              }
                            });
                          },
                          padding: const EdgeInsets.symmetric(vertical: 4),
                        ),
                      );
                      // Insert the details card directly after the selected proposal
                      if (_selectedProposalId == proposal.id) {
                        proposalWidgets.add(
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                            child: Center(
                              key: ValueKey(_selectedProposalId),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  color: isDark ? const Color(0xFF232325) : Colors.white,
                                  clipBehavior: Clip.antiAlias,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: _InlineProposalDetails(
                                      proposalId: _selectedProposalId!,
                                      proposalName: _selectedProposalName ?? '',
                                      showActions: true,
                                      compact: true,
                                      opportunityId: widget.opportunity.id,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    }
                    return Column(children: proposalWidgets);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text('Erro ao carregar propostas: $error'),
              ),
            ),
          ],
        ),
            ),
          ),
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
}

class _InlineProposalDetails extends ConsumerWidget {
  final String proposalId;
  final String proposalName;
  final bool showActions;
  final bool compact;
  final String? opportunityId;
  
  const _InlineProposalDetails({
    required this.proposalId, 
    required this.proposalName, 
    this.showActions = false, 
    this.compact = false,
    this.opportunityId,
  });

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(dateTime.toLocal());
    } catch (e) {
      return dateString;
    }
  }

  String _formatCurrency(double? value) {
    if (value == null) return 'N/A';
    final format = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    return format.format(value);
  }

  String _formatYears(double? value) {
    if (value == null) return 'N/A';
    if (value == value.toInt()) {
      return '${value.toInt()} Ano${value.toInt() == 1 ? '' : 's'}';
    }
    return '${value.toStringAsFixed(1)} Anos';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detailsAsync = ref.watch(resellerProposalDetailsProvider(proposalId));
    // Define actionable statuses
    const actionableStatuses = {'Pendente', 'Enviada'};

    final double verticalSpacing = compact ? 8.0 : 16.0;
    final double cardPadding = compact ? 8.0 : 16.0;
    final double fontSize = compact ? 15.0 : 17.0;

    return detailsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        String errorMessage = 'Erro ao carregar detalhes da proposta.';
        if (error is Exception) {
          errorMessage = 'Erro: ${error.toString()}';
        }
        return Center(
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Text(errorMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: fontSize)),
          ),
        );
      },
      data: (proposal) {
        final cpeList = proposal.cpePropostas ?? [];
        final bool showActionButtons = showActions && actionableStatuses.contains(proposal.status);
        // --- Proposal Details Layout ---
        // Calculate total commission
        double totalCommission = 0;
        for (final cpe in cpeList) {
          if (cpe.commissionRetail != null) {
            totalCommission += cpe.commissionRetail as double;
      }
    }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Commission and Data Validade - responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                
                if (isNarrow) {
                  // Stack vertically on narrow screens
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Total Comissão:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: fontSize)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(_formatCurrency(totalCommission), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: fontSize)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Data de Validade:', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500, fontSize: fontSize)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(_formatDate(proposal.expiryDate), style: theme.textTheme.bodyMedium?.copyWith(fontSize: fontSize)),
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  // Side by side on wider screens
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            Text('Total Comissão:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: fontSize)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(_formatCurrency(totalCommission), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: fontSize)),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('Data de Validade:', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500, fontSize: fontSize)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(_formatDate(proposal.expiryDate), style: theme.textTheme.bodyMedium?.copyWith(fontSize: fontSize)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
            SizedBox(height: verticalSpacing),
            
            if (cpeList.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: verticalSpacing),
                child: Center(child: Text('Nenhum contrato associado.', style: TextStyle(fontSize: fontSize))),
              )
                          else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 500;
                  
                  if (isMobile) {
                    // Stack CPE cards vertically on mobile
                    return Column(
                      children: [
                        for (final cpe in cpeList)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12, top: 4),
                            child: Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(14),
                              color: theme.colorScheme.surface,
                              clipBehavior: Clip.antiAlias,
                              child: Padding(
                                padding: EdgeInsets.all(cardPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Centered CPE title
                                Center(
                                  child: Text(
                                    cpe.cpeC != null && cpe.cpeC!.isNotEmpty
                                        ? cpe.cpeC!
                                        : cpe.id.substring(cpe.id.length - 6),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                      fontSize: fontSize,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                // Main content row with details on left and files on right
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left side - Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                SizedBox(
                                                  width: 80,
                                                  child: Text(
                                                    'Comissão:',
                                                    style: theme.textTheme.bodyMedium?.copyWith(
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                      fontWeight: FontWeight.w500,
                                                      fontSize: fontSize,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    _formatCurrency(cpe.commissionRetail),
                                                    style: theme.textTheme.titleSmall?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                      color: theme.colorScheme.primary,
                                                      fontSize: fontSize,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _buildDetailRow(
                                            context,
                                            'Potência',
                                            cpe.consumptionOrPower?.toStringAsFixed(2) ?? 'N/A',
                                            fontSize,
                                          ),
                                          _buildDetailRow(
                                            context,
                                            'Fidelização',
                                            _formatYears(cpe.loyaltyYears),
                                            fontSize,
                                          ),
                                        ],
                                      ),
                                    ),
                                                                         // Right side - File previews
                                     if (cpe.attachedFiles.isNotEmpty) ...[
                                       const SizedBox(width: 16),
                                       Container(
                                         width: 60,
                                         child: Column(
                                           mainAxisAlignment: MainAxisAlignment.center,
                                           children: [
                                             Wrap(
                                               spacing: 8.0,
                                               runSpacing: 8.0,
                                               alignment: WrapAlignment.center,
                                               children: cpe.attachedFiles.map((fileInfo) {
                                                 return _buildFilePreview(context, fileInfo, iconSize: 40);
                                               }).toList(),
                                             ),
                                           ],
                                         ),
                                       ),
                                     ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ] 
                );
                  } else {
                    // Horizontal scroll for wider screens
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final cpe in cpeList)
                            Container(
                              width: 260,
                              margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                              child: Material(
                                elevation: 2,
                                borderRadius: BorderRadius.circular(14),
                                color: theme.colorScheme.surface,
                                clipBehavior: Clip.antiAlias,
                                child: Padding(
                                  padding: EdgeInsets.all(cardPadding),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Centered CPE title
                                      Center(
                                        child: Text(
                                          cpe.cpeC != null && cpe.cpeC!.isNotEmpty
                                              ? cpe.cpeC!
                                              : cpe.id.substring(cpe.id.length - 6),
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurface,
                                            fontSize: fontSize,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      // Main content row with details on left and files on right
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Left side - Details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      SizedBox(
                                                        width: 80,
                                                        child: Text(
                                                          'Comissão:',
                                                          style: theme.textTheme.bodyMedium?.copyWith(
                                                            color: theme.colorScheme.onSurfaceVariant,
                                                            fontWeight: FontWeight.w500,
                                                            fontSize: fontSize,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          _formatCurrency(cpe.commissionRetail),
                                                          style: theme.textTheme.titleSmall?.copyWith(
                                                            fontWeight: FontWeight.bold,
                                                            color: theme.colorScheme.primary,
                                                            fontSize: fontSize,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                _buildDetailRow(
                                                  context,
                                                  'Potência',
                                                  cpe.consumptionOrPower?.toStringAsFixed(2) ?? 'N/A',
                                                  fontSize,
                                                ),
                                                _buildDetailRow(
                                                  context,
                                                  'Fidelização',
                                                  _formatYears(cpe.loyaltyYears),
                                                  fontSize,
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Right side - File previews
                                          if (cpe.attachedFiles.isNotEmpty) ...[
                                            const SizedBox(width: 12),
                                            Container(
                                              width: 50,
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Wrap(
                                                    spacing: 6.0,
                                                    runSpacing: 6.0,
                                                    alignment: WrapAlignment.center,
                                                    children: cpe.attachedFiles.map((fileInfo) {
                                                      return _buildFilePreview(context, fileInfo, iconSize: 32);
                                                    }).toList(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }
                },
              ),
            if (showActionButtons) ...[
              SizedBox(height: verticalSpacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Rejeitar'),
                      onPressed: () async {
                        // --- START: Confirmation Dialog for Reject ---
                        final currentContext = context;
                        showDialog(
                          context: currentContext,
                          builder: (BuildContext ctx) {
                            return AlertDialog(
                              title: const Text('Confirmar Rejeição'),
                              content: const Text('Tem a certeza que pretende rejeitar esta proposta?'),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Cancelar'),
                                  onPressed: () => Navigator.of(ctx).pop(),
                                ),
                                TextButton(
                                  child: const Text('Rejeitar', style: TextStyle(color: Colors.red)),
                                  onPressed: () async {
                                    Navigator.of(ctx).pop(); // Close dialog
                                    // Show loading indicator
                                    showDialog(
                                      context: currentContext,
                                      barrierDismissible: false,
                                      builder: (context) => const Center(child: CircularProgressIndicator()),
                                    );
                                    try {
                                      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
                                      final callable = functions.httpsCallable('rejectProposalForReseller');
                                      final result = await callable.call<Map<String, dynamic>>({
                                        'proposalId': proposalId,
                                      });
                                      if (currentContext.mounted) {
                                        Navigator.of(currentContext).pop(); // Close loading
                                        if (result.data['success'] == true) {
                                          // Create notification
                                          try {
                                            final currentUser = ref.read(currentUserProvider);
                                            final notificationRepo = ref.read(notificationRepositoryProvider);
                                            await notificationRepo.createProposalRejectedNotification(
                                              proposalId: proposalId,
                                              proposalName: proposalName,
                                              opportunityId: opportunityId,
                                              clientName: proposal.nifC,
                                              resellerName: currentUser?.displayName,
                                              resellerId: currentUser?.uid,
                                            );
                                          } catch (e) {
                                            // Silently ignore notification creation errors
                                          }
                                          await showSuccessDialog(
                                            context: currentContext,
                                            message: 'Proposta rejeitada com sucesso',
                                            onDismissed: () {},
                                          );
                                          ref.refresh(resellerProposalDetailsProvider(proposalId));
                                        } else {
                                          final errorMsg = result.data['error'] ?? 'Falha ao rejeitar a proposta';
                                          ScaffoldMessenger.of(currentContext).showSnackBar(
                                            SnackBar(
                                              content: Text('Erro: $errorMsg'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (currentContext.mounted) {
                                        Navigator.of(currentContext).pop(); // Close loading
                                        String errorMessage = e is FirebaseFunctionsException ? (e.message ?? e.code) : e.toString();
                                        ScaffoldMessenger.of(currentContext).showSnackBar(
                                          SnackBar(
                                            content: Text('Erro ao rejeitar proposta: $errorMessage'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            );
                          },
                        );
                        // --- END: Confirmation Dialog for Reject ---
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(
                          color: theme.colorScheme.error.withAlpha((255 * 0.7).round()),
                          width: 1.2,
                        ),
                        minimumSize: const Size(120, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        textStyle: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.check_circle_outline, color: theme.colorScheme.tertiary),
                      label: Text('Aceitar', style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: theme.colorScheme.tertiary,
                      )),
                      onPressed: () {
                        // --- START: Navigate to Submit Documents Page ---
                        final currentContext = context;
                        final nif = proposal.nifC;
                        if (nif == null || nif.isEmpty) {
                          ScaffoldMessenger.of(currentContext).showSnackBar(
                            const SnackBar(
                              content: Text('Erro: NIF não encontrado para esta proposta.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        Navigator.push(
                          currentContext,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => SubmitProposalDocumentsPage(
                              proposalId: proposalId,
                              proposalName: proposalName,
                              cpeList: cpeList,
                              nif: nif,
                              opportunityId: opportunityId,
                            ),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              const begin = Offset(1.0, 0.0);
                              const end = Offset.zero;
                              const curve = Curves.easeInOutCubic;

                              var tween = Tween(begin: begin, end: end).chain(
                                CurveTween(curve: curve),
                              );

                              return SlideTransition(
                                position: animation.drive(tween),
                                child: child,
                              );
                            },
                            transitionDuration: const Duration(milliseconds: 300),
                            reverseTransitionDuration: const Duration(milliseconds: 250),
                          ),
                        );
                        // --- END: Navigate to Submit Documents Page ---
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.tertiary,
                        side: BorderSide(
                          color: theme.colorScheme.tertiary,
                          width: 1.5,
                        ),
                        minimumSize: const Size(120, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        textStyle: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, double fontSize) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontSize: fontSize,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontSize: fontSize))),
        ],
      ),
    );
  }

  Widget _buildFilePreview(BuildContext context, SalesforceFileInfo fileInfo, {double iconSize = 20}) {
    final theme = Theme.of(context);
    
    // Get file extension from title
    final fileName = fileInfo.title.toLowerCase();
    String fileExtension = '';
    if (fileName.contains('.')) {
      fileExtension = fileName.split('.').last;
    }
    
    // Get custom icon asset path
    final iconAsset = FileIconService.getIconAssetPath(fileExtension);

    return GestureDetector(
      onTap: () => _viewFile(context, fileInfo),
      child: Tooltip(
        message: fileInfo.title,
        child: Container(
          width: iconSize + 16,
          height: iconSize + 16,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha((255 * 0.8).round()),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: theme.colorScheme.outline.withAlpha((255 * 0.3).round()),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((255 * 0.1).round()),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Image.asset(
              iconAsset,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _viewFile(BuildContext context, SalesforceFileInfo fileInfo) async {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => SecureFileViewer.fromSalesforce(
          contentVersionId: fileInfo.id,
          title: fileInfo.title,
          isResellerContext: true,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}
