import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../features/opportunity/presentation/providers/opportunity_providers.dart';
import '../../../features/opportunity/presentation/pages/salesforce_opportunity.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Add back Status constants
  static const String STATUS_PENDING_REVIEW = 'pending_review';
  static const String STATUS_APPROVED = 'approved';
  static const String STATUS_REJECTED = 'rejected';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Replace userSubmissionsProvider with filteredOpportunitiesProvider
    final opportunitiesAsync = ref.watch(resellerOpportunitiesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        top: false,
        child: Column(
          children: [
            // Header area with search - simplified and Apple-like
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _buildSearchBar(context),
            ),

            // Opportunities list
            Expanded(
              child: opportunitiesAsync.when(
                data: (opportunities) {
                  // Filter opportunities based on search query
                  final filteredOpportunities = ref.watch(
                    filteredOpportunitiesProvider(_searchQuery),
                  );

                  if (filteredOpportunities.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(top: 6),
                    itemCount: filteredOpportunities.length,
                    separatorBuilder:
                        (context, index) => Container(
                          margin: const EdgeInsets.only(left: 72),
                          height: 0.5,
                          color:
                              isDark
                                  ? AppTheme.darkBorder.withAlpha(128)
                                  : AppTheme.border.withAlpha(128),
                        ),
                    itemBuilder: (context, index) {
                      final opportunity = filteredOpportunities[index];
                      return _buildOpportunityCard(
                        context,
                        opportunity,
                        key: ValueKey(opportunity.Id),
                      );
                    },
                  );
                },
                loading:
                    () => Center(
                      child: CircularProgressIndicator(
                        color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
                      ),
                    ),
                error:
                    (error, stackTrace) => Center(
                      child: Text(
                        'Erro ao carregar clientes: $error',
                        style: TextStyle(
                          color:
                              isDark
                                  ? AppTheme.darkDestructive
                                  : AppTheme.destructive,
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: isDark ? AppTheme.darkPrimary : AppTheme.primary,
        shape: const CircleBorder(),
        elevation: 2.0,
        child: Icon(
          CupertinoIcons.add,
          color:
              isDark
                  ? AppTheme.darkPrimaryForeground
                  : AppTheme.primaryForeground,
        ),
        onPressed: () {
          context.push('/services');
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark
            ? AppTheme.darkInput.withAlpha(204)
            : AppTheme.secondary.withAlpha(204);
    final textColor = isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final hintColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: CupertinoTextField(
        controller: _searchController,
        placeholder: 'Buscar cliente',
        placeholderStyle: TextStyle(color: hintColor, fontSize: 14),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Icon(CupertinoIcons.search, color: hintColor, size: 16),
        ),
        suffix:
            _searchQuery.isNotEmpty
                ? GestureDetector(
                  onTap: () => _searchController.clear(),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      CupertinoIcons.clear_circled_solid,
                      color: hintColor,
                      size: 16,
                    ),
                  ),
                )
                : null,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        style: TextStyle(fontSize: 14, color: textColor),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;

    // Updated empty state message
    const String message = 'Sem Clientes Ativos';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.person_2, size: 48, color: textColor),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Adicione um novo cliente usando o botão +'
                : 'Tente refinar sua busca.',
            style: TextStyle(fontSize: 15, color: textColor),
          ),
        ],
      ),
    );
  }

  // New method to build an opportunity card
  Widget _buildOpportunityCard(
    BuildContext context,
    SalesforceOpportunity opportunity, {
    Key? key,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final chevronColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;

    // Format CreatedDate
    String formattedCreatedDate = '';
    try {
      final date = DateTime.parse(opportunity.CreatedDate);
      // Use a locale-aware format if AppLocalizations is available
      try {
        final l10n = AppLocalizations.of(context);
        if (l10n != null) {
          formattedCreatedDate = DateFormat.yMd(l10n.localeName).format(date);
        } else {
          formattedCreatedDate = DateFormat('dd/MM/yyyy').format(date);
        }
      } catch (_) {
        formattedCreatedDate = DateFormat('dd/MM/yyyy').format(date);
      }
    } catch (e) {
      formattedCreatedDate = opportunity.CreatedDate; // Fallback to raw string
    }

    return GestureDetector(
      key: key,
      onTap: () => _showOpportunityDetails(opportunity),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _buildOpportunityIcon(context, opportunity),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opportunity.Name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 14, color: chevronColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseIndicator(BuildContext context, String? phase) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color color;
    String displayPhase;

    // Map Salesforce phases to display text and colors
    if (phase == null) {
      color = isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;
      displayPhase = 'N/A';
    } else if (phase.startsWith('0 -')) {
      color = isDark ? Colors.orange.shade300 : Colors.orange;
      displayPhase = 'Identificada';
    } else if (phase.startsWith('1 -')) {
      color = isDark ? AppTheme.darkPrimary : AppTheme.primary;
      displayPhase = 'Qualificada';
    } else if (phase.startsWith('2 -')) {
      color = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
      displayPhase = 'Proposta';
    } else if (phase.startsWith('3 -')) {
      color = isDark ? Colors.indigo.shade300 : Colors.indigo;
      displayPhase = 'Negociação';
    } else if (phase.startsWith('4 -')) {
      color = isDark ? AppTheme.darkSuccess : AppTheme.success;
      displayPhase = 'Fechada/Ganha';
    } else if (phase.startsWith('5 -')) {
      color = isDark ? AppTheme.darkDestructive : AppTheme.destructive;
      displayPhase = 'Fechada/Perdida';
    } else {
      color = isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;
      displayPhase = phase; // Use the raw phase string
    }

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          displayPhase,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildOpportunityIcon(
    BuildContext context,
    SalesforceOpportunity opportunity,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppTheme.darkPrimary : AppTheme.primary;

    // Simple icon - could add logic to show different icons based on solution type
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: baseColor.withAlpha(26),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(CupertinoIcons.building_2_fill, size: 20, color: baseColor),
      ),
    );
  }

  void _showOpportunityDetails(SalesforceOpportunity opportunity) {
    // TODO: Implement opportunity detail view
    // For now, just show information in a bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OpportunityDetailsSheet(opportunity: opportunity),
    );
  }
}

// Simple opportunity details sheet
class _OpportunityDetailsSheet extends StatelessWidget {
  final SalesforceOpportunity opportunity;

  const _OpportunityDetailsSheet({required this.opportunity});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.darkBackground : AppTheme.background;
    final foregroundColor =
        isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final mutedColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;
    final handleColor =
        isDark
            ? AppTheme.darkMutedForeground.withOpacity(0.3)
            : Colors.grey.withOpacity(0.3);

    // Format CreatedDate
    String formattedCreatedDate = '';
    try {
      final date = DateTime.parse(opportunity.CreatedDate);
      // Use a locale-aware format if AppLocalizations is available
      try {
        final l10n = AppLocalizations.of(context);
        if (l10n != null) {
          formattedCreatedDate = DateFormat.yMd(l10n.localeName).format(date);
        } else {
          formattedCreatedDate = DateFormat('dd/MM/yyyy').format(date);
        }
      } catch (_) {
        formattedCreatedDate = DateFormat('dd/MM/yyyy').format(date);
      }
    } catch (e) {
      formattedCreatedDate = opportunity.CreatedDate; // Fallback to raw string
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opportunity.Name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: foregroundColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Criada em: $formattedCreatedDate',
                        style: TextStyle(
                          fontSize: 14,
                          color: foregroundColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildPhaseBadge(context, opportunity.Fase__c),
              ],
            ),
          ),

          // Content - Scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Opportunity Information Section
                  _buildSectionTitle(context, 'Informações da Oportunidade'),
                  _buildInfoItem(context, 'Nome', opportunity.Name),
                  _buildInfoItem(context, 'Fase', opportunity.Fase__c ?? 'N/A'),
                  _buildInfoItem(context, 'NIF', opportunity.NIF__c ?? 'N/A'),
                  _buildInfoItem(context, 'Data Criação', formattedCreatedDate),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Close button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                foregroundColor:
                    isDark
                        ? AppTheme.darkPrimaryForeground
                        : AppTheme.primaryForeground,
                backgroundColor:
                    isDark ? AppTheme.darkPrimary : AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Fechar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final foregroundColor =
        Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkForeground
            : AppTheme.foreground;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: foregroundColor,
        ),
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor =
        isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final mutedColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label + ':',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: mutedColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: foregroundColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseBadge(BuildContext context, String? phase) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color color;
    String displayPhase;

    // Map Salesforce phases to display text and colors
    if (phase == null) {
      color = isDark ? AppTheme.darkMutedForeground : Colors.grey;
      displayPhase = 'Não definido';
    } else if (phase.startsWith('0 -')) {
      color = isDark ? Colors.orange.shade300 : Colors.orange;
      displayPhase = 'Identificada';
    } else if (phase.startsWith('1 -')) {
      color = isDark ? AppTheme.darkPrimary : Colors.blue;
      displayPhase = 'Qualificada';
    } else if (phase.startsWith('2 -')) {
      color = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
      displayPhase = 'Proposta';
    } else if (phase.startsWith('3 -')) {
      color = isDark ? Colors.indigo.shade300 : Colors.indigo;
      displayPhase = 'Negociação';
    } else if (phase.startsWith('4 -')) {
      color = isDark ? AppTheme.darkSuccess : AppTheme.success;
      displayPhase = 'Fechada/Ganha';
    } else if (phase.startsWith('5 -')) {
      color = isDark ? AppTheme.darkDestructive : AppTheme.destructive;
      displayPhase = 'Fechada/Perdida';
    } else {
      color = isDark ? AppTheme.darkMutedForeground : Colors.grey;
      displayPhase = phase; // Use the raw phase string
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        displayPhase,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}
