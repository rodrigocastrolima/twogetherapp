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
    // Replace userSubmissionsProvider with filteredOpportunitiesProvider
    final opportunitiesAsync = ref.watch(resellerOpportunitiesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          children: [
            // Header area with search - simplified and Apple-like
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _buildSearchBar(),
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
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(top: 6),
                    itemCount: filteredOpportunities.length,
                    separatorBuilder:
                        (context, index) => Container(
                          margin: const EdgeInsets.only(left: 72),
                          height: 0.5,
                          color: CupertinoColors.systemGrey5.withAlpha(128),
                        ),
                    itemBuilder: (context, index) {
                      final opportunity = filteredOpportunities[index];
                      return _buildOpportunityCard(
                        opportunity,
                        key: ValueKey(opportunity.Id),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, stackTrace) => Center(
                      child: Text(
                        'Erro ao carregar clientes: $error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        shape: const CircleBorder(),
        elevation: 2.0,
        child: const Icon(CupertinoIcons.add, color: Colors.white),
        onPressed: () {
          context.push('/services');
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.withAlpha(204),
        borderRadius: BorderRadius.circular(10),
      ),
      child: CupertinoTextField(
        controller: _searchController,
        placeholder: 'Buscar cliente',
        placeholderStyle: const TextStyle(
          color: CupertinoColors.systemGrey,
          fontSize: 14,
        ),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Icon(
            CupertinoIcons.search,
            color: CupertinoColors.systemGrey,
            size: 16,
          ),
        ),
        suffix:
            _searchQuery.isNotEmpty
                ? GestureDetector(
                  onTap: () => _searchController.clear(),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(
                      CupertinoIcons.clear_circled_solid,
                      color: CupertinoColors.systemGrey,
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
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildEmptyState() {
    // Updated empty state message
    const String message = 'Sem Clientes Ativos';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.person_2,
            size: 48,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Adicione um novo cliente usando o botão +'
                : 'Tente refinar sua busca.',
            style: const TextStyle(
              fontSize: 15,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  // New method to build an opportunity card
  Widget _buildOpportunityCard(SalesforceOpportunity opportunity, {Key? key}) {
    // Format date if available (Data_de_Previs_o_de_Fecho__c)
    String formattedDate = '';
    if (opportunity.Data_de_Previs_o_de_Fecho__c != null) {
      try {
        final date = DateTime.parse(opportunity.Data_de_Previs_o_de_Fecho__c!);
        formattedDate = DateFormat('dd/MM/yyyy').format(date);
      } catch (e) {
        // If parsing fails, use the raw string
        formattedDate = opportunity.Data_de_Previs_o_de_Fecho__c!;
      }
    }

    return GestureDetector(
      key: key,
      onTap: () => _showOpportunityDetails(opportunity),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _buildOpportunityIcon(opportunity),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opportunity.Name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.label,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${opportunity.Solu_o__c ?? "N/A"} • ${formattedDate.isNotEmpty ? formattedDate : "N/A"}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildPhaseIndicator(opportunity.Fase__c),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: CupertinoColors.systemGrey3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseIndicator(String? phase) {
    Color color;
    String displayPhase;

    // Map Salesforce phases to display text and colors
    if (phase == null) {
      color = CupertinoColors.systemGrey;
      displayPhase = 'N/A';
    } else if (phase.startsWith('0 -')) {
      color = CupertinoColors.systemOrange;
      displayPhase = 'Identificada';
    } else if (phase.startsWith('1 -')) {
      color = CupertinoColors.systemBlue;
      displayPhase = 'Qualificada';
    } else if (phase.startsWith('2 -')) {
      color = CupertinoColors.activeBlue;
      displayPhase = 'Proposta';
    } else if (phase.startsWith('3 -')) {
      color = CupertinoColors.systemIndigo;
      displayPhase = 'Negociação';
    } else if (phase.startsWith('4 -')) {
      color = CupertinoColors.systemGreen;
      displayPhase = 'Fechada/Ganha';
    } else if (phase.startsWith('5 -')) {
      color = CupertinoColors.systemRed;
      displayPhase = 'Fechada/Perdida';
    } else {
      color = CupertinoColors.systemGrey;
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

  Widget _buildOpportunityIcon(SalesforceOpportunity opportunity) {
    // Simple icon - could add logic to show different icons based on solution type
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: CupertinoColors.systemIndigo.withAlpha(26),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          CupertinoIcons.building_2_fill,
          size: 20,
          color: CupertinoColors.systemIndigo,
        ),
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
    // Format date
    String formattedDate = '';
    if (opportunity.Data_de_Previs_o_de_Fecho__c != null) {
      try {
        final date = DateTime.parse(opportunity.Data_de_Previs_o_de_Fecho__c!);
        formattedDate = DateFormat('dd/MM/yyyy').format(date);
      } catch (e) {
        formattedDate = opportunity.Data_de_Previs_o_de_Fecho__c!;
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: AppTheme.background,
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
                color: Colors.grey.withOpacity(0.3),
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
                        'Detalhes da Oportunidade',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (formattedDate.isNotEmpty)
                        Text(
                          'Fechamento: $formattedDate',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.foreground.withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildPhaseBadge(opportunity.Fase__c),
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
                  _buildSectionTitle('Informações da Oportunidade'),
                  _buildInfoItem('Nome', opportunity.Name),
                  _buildInfoItem('Fase', opportunity.Fase__c ?? 'N/A'),
                  _buildInfoItem('Solução', opportunity.Solu_o__c ?? 'N/A'),
                  _buildInfoItem(
                    'Data Fechamento',
                    formattedDate.isNotEmpty ? formattedDate : 'N/A',
                  ),
                  const SizedBox(height: 20),

                  // Account Information Section
                  _buildSectionTitle('Informações da Conta'),
                  _buildInfoItem('ID da Conta', opportunity.AccountId ?? 'N/A'),
                  _buildInfoItem(
                    'Nome da Conta',
                    opportunity.Account?.Name ?? 'N/A',
                  ),
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
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.primary,
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.foreground,
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
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
                color: AppTheme.foreground.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: AppTheme.foreground),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseBadge(String? phase) {
    Color color;
    String displayPhase;

    // Map Salesforce phases to display text and colors
    if (phase == null) {
      color = Colors.grey;
      displayPhase = 'Não definido';
    } else if (phase.startsWith('0 -')) {
      color = Colors.orange;
      displayPhase = 'Identificada';
    } else if (phase.startsWith('1 -')) {
      color = Colors.blue;
      displayPhase = 'Qualificada';
    } else if (phase.startsWith('2 -')) {
      color = Colors.blue.shade700;
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
      color = Colors.grey;
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
