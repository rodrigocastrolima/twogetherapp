import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../features/opportunity/presentation/providers/opportunity_providers.dart';
import '../../../features/opportunity/data/models/salesforce_opportunity.dart'
    as sfo;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

// Enum for filter status
enum OpportunityFilterStatus {
  todos,
  ativos,
  acaoNecessaria,
  pendentes,
  rejeitados,
}

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  OpportunityFilterStatus _selectedFilter = OpportunityFilterStatus.todos;

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

  String _getProposalStatusForFilter(sfo.SalesforceOpportunity opportunity) {
    if (opportunity.propostasR?.records != null &&
        opportunity.propostasR!.records.isNotEmpty) {
      return opportunity.propostasR!.records.first.statusC ??
          ''; // Default to empty if status is null
    }
    return ''; // Default if no proposals or records
  }

  bool _matchesFilter(
    sfo.SalesforceOpportunity opportunity,
    OpportunityFilterStatus filter,
  ) {
    final proposalStatus = _getProposalStatusForFilter(opportunity);

    switch (filter) {
      case OpportunityFilterStatus.todos:
        return true;
      case OpportunityFilterStatus.ativos:
        return proposalStatus == 'Aceite';
      case OpportunityFilterStatus.acaoNecessaria:
        return ['Enviada', 'Em Aprovação'].contains(proposalStatus);
      case OpportunityFilterStatus.pendentes:
        return [
          'Aprovada',
          'Expirada',
          'Criação',
          'Em Análise',
        ].contains(proposalStatus);
      case OpportunityFilterStatus.rejeitados:
        return ['Não Aprovada', 'Cancelada'].contains(proposalStatus);
      default:
        return false;
    }
  }

  Widget _buildFilterSegments(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = isDark ? AppTheme.darkPrimary : AppTheme.primary;
    final unselectedColor = isDark ? AppTheme.darkInput : Colors.grey[200];
    final selectedFgColor =
        isDark ? AppTheme.darkPrimaryForeground : AppTheme.primaryForeground;
    final unselectedFgColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.foreground;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SegmentedButton<OpportunityFilterStatus>(
        segments: const <ButtonSegment<OpportunityFilterStatus>>[
          ButtonSegment<OpportunityFilterStatus>(
            value: OpportunityFilterStatus.todos,
            label: Text('Todos'),
          ),
          ButtonSegment<OpportunityFilterStatus>(
            value: OpportunityFilterStatus.ativos,
            label: Text('Ativos'),
          ),
          ButtonSegment<OpportunityFilterStatus>(
            value: OpportunityFilterStatus.acaoNecessaria,
            label: Text('Ação'), // Shortened for space
          ),
          ButtonSegment<OpportunityFilterStatus>(
            value: OpportunityFilterStatus.pendentes,
            label: Text('Pendentes'),
          ),
          ButtonSegment<OpportunityFilterStatus>(
            value: OpportunityFilterStatus.rejeitados,
            label: Text('Rejeitados'),
          ),
        ],
        selected: <OpportunityFilterStatus>{_selectedFilter},
        onSelectionChanged: (Set<OpportunityFilterStatus> newSelection) {
          setState(() {
            _selectedFilter = newSelection.first;
          });
        },
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color?>((
            Set<MaterialState> states,
          ) {
            if (states.contains(MaterialState.selected)) {
              return selectedColor;
            }
            return unselectedColor; // Use the component's default for unselected
          }),
          foregroundColor: MaterialStateProperty.resolveWith<Color?>((
            Set<MaterialState> states,
          ) {
            if (states.contains(MaterialState.selected)) {
              return selectedFgColor;
            }
            return unselectedFgColor;
          }),
          side: MaterialStateProperty.resolveWith<BorderSide?>((
            Set<MaterialState> states,
          ) {
            return BorderSide(color: selectedColor.withAlpha(100));
          }),
          textStyle: MaterialStateProperty.all<TextStyle>(
            const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ), // Adjust font size
          ),
        ),
        showSelectedIcon: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final opportunitiesAsync = ref.watch(resellerOpportunitiesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                0,
              ), // Adjusted bottom padding
              child: _buildSearchBar(context),
            ),
            _buildFilterSegments(context), // Add filter segments here
            Expanded(
              child: opportunitiesAsync.when(
                data: (opportunities) {
                  // Apply status filter first
                  List<sfo.SalesforceOpportunity> statusFilteredOpportunities =
                      opportunities
                          .where(
                            (opportunity) =>
                                _matchesFilter(opportunity, _selectedFilter),
                          )
                          .toList();

                  // Then apply search filter
                  final displayOpportunities =
                      _searchQuery.isEmpty
                          ? statusFilteredOpportunities // Use status-filtered list
                          : statusFilteredOpportunities.where((opportunity) {
                            // Filter on status-filtered list
                            final query = _searchQuery.toLowerCase();
                            final nameMatch = (opportunity.name)
                                .toLowerCase()
                                .contains(query);
                            final accountNameMatch = (opportunity.accountName ??
                                    '')
                                .toLowerCase()
                                .contains(query);
                            return nameMatch || accountNameMatch;
                          }).toList();

                  if (displayOpportunities.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(top: 6),
                    itemCount: displayOpportunities.length,
                    separatorBuilder:
                        (context, index) =>
                            _buildListSeparator(context, isDark),
                    itemBuilder: (context, index) {
                      final sfo.SalesforceOpportunity opportunity =
                          displayOpportunities[index];
                      return _buildOpportunityCard(
                        context,
                        opportunity,
                        key: ValueKey(opportunity.id),
                      );
                    },
                  );
                },
                loading: () => _buildLoadingIndicator(context, isDark),
                error:
                    (error, stackTrace) =>
                        _buildErrorState(context, error, isDark),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(context, isDark),
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

  Widget _buildLoadingIndicator(BuildContext context, bool isDark) {
    return Center(
      child: CircularProgressIndicator(
        color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error, bool isDark) {
    return Center(
      child: Text(
        'Erro ao carregar clientes: $error',
        style: TextStyle(
          color: isDark ? AppTheme.darkDestructive : AppTheme.destructive,
        ),
      ),
    );
  }

  Widget _buildListSeparator(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(left: 72),
      height: 0.5,
      color:
          isDark
              ? AppTheme.darkBorder.withAlpha(128)
              : AppTheme.border.withAlpha(128),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context, bool isDark) {
    return FloatingActionButton(
      backgroundColor: isDark ? AppTheme.darkPrimary : AppTheme.primary,
      elevation: 2.0,
      shape: const CircleBorder(),
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
    );
  }

  ({IconData? icon, Color iconColor, Color outlineColor, Color cardBgColor})
  _getStatusVisuals(String? status, BuildContext context) {
    final theme = Theme.of(context);
    final defaultCardBg = theme.cardColor;
    final defaultOutline = theme.dividerColor.withAlpha(150);

    const Color greenColor = Color(0xFF34C759);
    const Color blueColor = Color(0xFF007AFF);
    const Color orangeColor = Color(0xFFFF9500);
    const Color redColor = Color(0xFFFF3B30);

    switch (status) {
      case 'Aceite':
        return (
          icon: CupertinoIcons.check_mark_circled_solid,
          iconColor: greenColor,
          outlineColor: greenColor.withAlpha(150),
          cardBgColor: defaultCardBg,
        );
      case 'Enviada':
      case 'Em Aprovação':
        return (
          icon: CupertinoIcons.exclamationmark_circle_fill,
          iconColor: blueColor,
          outlineColor: blueColor.withAlpha(150),
          cardBgColor: defaultCardBg,
        );
      case 'Aprovada':
      case 'Expirada':
      case 'Criação':
      case 'Em Análise':
        return (
          icon: CupertinoIcons.clock_fill,
          iconColor: orangeColor,
          outlineColor: orangeColor.withAlpha(150),
          cardBgColor: defaultCardBg,
        );
      case 'Não Aprovada':
      case 'Cancelada':
        return (
          icon: CupertinoIcons.xmark_circle_fill,
          iconColor: redColor,
          outlineColor: redColor.withAlpha(150),
          cardBgColor: defaultCardBg,
        );
      default:
        return (
          icon: CupertinoIcons.question_circle_fill,
          iconColor: theme.dividerColor,
          outlineColor: defaultOutline,
          cardBgColor: defaultCardBg,
        );
    }
  }

  Widget _buildOpportunityCard(
    BuildContext context,
    sfo.SalesforceOpportunity opportunity, {
    Key? key,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final mutedTextColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;
    final chevronColor = mutedTextColor;

    if (kDebugMode) {
      print('[BuildOppCard] ID: ${opportunity.id}');
      final proposals = opportunity.propostasR;
      if (proposals == null) {
        print('[BuildOppCard] Propostas__r is NULL');
      } else if (proposals.records.isEmpty) {
        print('[BuildOppCard] Propostas__r records is EMPTY');
      } else {
        print(
          '[BuildOppCard] First Proposal Status: ${proposals.records.first.statusC}',
        );
        print('[BuildOppCard] All Proposal Records: ${proposals.records}');
      }
    }

    String? latestStatus;
    if (opportunity.propostasR?.records != null &&
        opportunity.propostasR!.records.isNotEmpty) {
      latestStatus = opportunity.propostasR!.records.first.statusC;
    }

    final statusVisuals = _getStatusVisuals(latestStatus, context);

    if (kDebugMode) {
      print('[BuildOppCard] Determined latestStatus: $latestStatus');
      print(
        '[BuildOppCard] Status Visuals: Icon=${statusVisuals.icon}, IconColor=${statusVisuals.iconColor}, Outline=${statusVisuals.outlineColor}',
      );
    }

    String displayDate = '';
    if (opportunity.createdDate != null) {
      try {
        final dateTime = DateTime.parse(opportunity.createdDate!);
        displayDate = DateFormat('dd/MM/yy', 'pt_PT').format(dateTime);
      } catch (e) {
        displayDate = '';
      }
    }

    final cardName = opportunity.accountName ?? opportunity.name;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Material(
        key: key,
        color: statusVisuals.cardBgColor,
        elevation: 1.5,
        shadowColor: Colors.black.withOpacity(isDark ? 0.5 : 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: statusVisuals.outlineColor, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            context.push('/opportunity-details', extra: opportunity);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cardName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (displayDate.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          displayDate,
                          style: TextStyle(fontSize: 13, color: mutedTextColor),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (statusVisuals.icon != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Icon(
                          statusVisuals.icon,
                          color: statusVisuals.iconColor,
                          size: 22,
                        ),
                      ),
                    Icon(
                      CupertinoIcons.chevron_right,
                      color: chevronColor,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
