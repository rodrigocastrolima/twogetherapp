import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../features/opportunity/presentation/providers/opportunity_providers.dart';
import '../../../features/opportunity/data/models/salesforce_opportunity.dart'
    as sfo;
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../../core/theme/ui_styles.dart';
import '../../widgets/simple_list_item.dart';

// Enum for filter status
enum OpportunityFilterStatus {
  todos,
  ativos,
  acaoNecessaria,
  pendentes,
  rejeitados;

  String get displayName {
    switch (this) {
      case OpportunityFilterStatus.todos:
        return 'Todos';
      case OpportunityFilterStatus.ativos:
        return 'Ativos';
      case OpportunityFilterStatus.acaoNecessaria:
        return 'Ação Necessária';
      case OpportunityFilterStatus.pendentes:
        return 'Pendentes';
      case OpportunityFilterStatus.rejeitados:
        return 'Rejeitados';
    }
  }
}

class ClientsPage extends ConsumerStatefulWidget {
  final String? initialFilter;
  
  const ClientsPage({super.key, this.initialFilter});

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
    
    // Set initial filter if provided
    if (widget.initialFilter != null) {
      _selectedFilter = _parseFilterString(widget.initialFilter!);
    }
  }
  
  // Helper method to parse filter string to enum
  OpportunityFilterStatus _parseFilterString(String filterString) {
    switch (filterString) {
      case 'ativos':
        return OpportunityFilterStatus.ativos;
      case 'acaoNecessaria':
        return OpportunityFilterStatus.acaoNecessaria;
      case 'pendentes':
        return OpportunityFilterStatus.pendentes;
      case 'rejeitados':
        return OpportunityFilterStatus.rejeitados;
      default:
        return OpportunityFilterStatus.todos;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper method for responsive font sizing
  double _getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final width = MediaQuery.of(context).size.width;
    return width < 600 ? baseFontSize - 2 : baseFontSize;
  }

  String _getProposalStatusForFilter(sfo.SalesforceOpportunity opportunity) {
    if (opportunity.propostasR?.records != null &&
        opportunity.propostasR!.records.isNotEmpty) {
      return opportunity.propostasR!.records.first.statusC ?? '';
    }
    return '';
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
    }
  }

  void _showIconLegendDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Legenda dos Ícones'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildLegendRow(
                  context,
                  Icon(Icons.check_circle, color: Colors.green[700], size: 24),
                  'Ativo',
                  'Cliente com proposta aceite e ativa.',
                ),
                const SizedBox(height: 16),
                _buildLegendRow(
                  context,
                  Icon(Icons.pending_actions, color: Colors.blue[700], size: 24),
                  'Ação Necessária',
                  'Requer a sua atenção para dar seguimento ao processo.',
                ),
                const SizedBox(height: 16),
                _buildLegendRow(
                  context,
                  Icon(Icons.schedule, color: Colors.orange[700], size: 24),
                  'Pendente',
                  'Processo em andamento ou aguardando aprovação.',
                ),
                const SizedBox(height: 16),
                _buildLegendRow(
                  context,
                  Icon(Icons.cancel, color: Colors.red[700], size: 24),
                  'Rejeitado',
                  'Proposta não foi aprovada ou foi cancelada.',
                ),
                const SizedBox(height: 16),
                _buildLegendRow(
                  context,
                  Icon(Icons.description, color: theme.colorScheme.onSurfaceVariant, size: 24),
                  'Outro',
                  'Estado inicial ou em processo de análise.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegendRow(BuildContext context, Widget icon, String title, String subtitle) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        icon,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title, 
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle, 
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final opportunitiesAsync = ref.watch(resellerOpportunitiesProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isSmallScreen) const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Clientes',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      fontSize: _getResponsiveFontSize(context, 24),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    richMessage: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                      ),
                      children: <InlineSpan>[
                        const TextSpan(text: 'Estados dos Clientes:\n\n', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(Icons.check_circle, color: Colors.green[700], size: 18),
                        ),
                        const TextSpan(text: ' Ativo: Cliente com proposta aceite\n'),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(Icons.pending_actions, color: Colors.blue[700], size: 18),
                        ),
                        const TextSpan(text: ' Ação Necessária: Requer a sua atenção\n'),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(Icons.schedule, color: Colors.orange[700], size: 18),
                        ),
                        const TextSpan(text: ' Pendente: Em processamento\n'),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(Icons.cancel, color: Colors.red[700], size: 18),
                        ),
                        const TextSpan(text: ' Rejeitado: Proposta não aprovada\n'),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(Icons.description, color: theme.colorScheme.onSurfaceVariant, size: 18),
                        ),
                        const TextSpan(text: ' Outro: Estado inicial ou em análise'),
                      ],
                    ),
                    preferBelow: false,
                    verticalOffset: 22, 
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), 
                    decoration: BoxDecoration(
                      color: (theme.brightness == Brightness.dark ? theme.colorScheme.surfaceContainerHigh : theme.cardColor).withAlpha((255 * 0.98).round()),
                      borderRadius: BorderRadius.circular(10), 
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withAlpha((255 * 0.08).round()),
                          blurRadius: 6,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 0,
                      child: Icon(
                        CupertinoIcons.info_circle,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                      onPressed: () {
                        _showIconLegendDialog(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
                          const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: isSmallScreen
                    ? Row(
                        children: [
                          Expanded(child: _buildSearchBar(context)),
                          const SizedBox(width: 12),
                          _buildFilterIconButton(context),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _buildSearchBar(context),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 200.0,
                            child: _buildFilterDropdown(context),
                          ),
                        ],
                      ),
              ),
            
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
                          ? statusFilteredOpportunities
                          : statusFilteredOpportunities.where((opportunity) {
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

                  return AnimationLimiter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),
                        itemCount: displayOpportunities.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 0),
                        itemBuilder: (context, index) {
                          final opportunity = displayOpportunities[index];
                          // Get status visuals
                          String? latestStatus;
                          if (opportunity.propostasR?.records != null &&
                              opportunity.propostasR!.records.isNotEmpty) {
                            latestStatus = opportunity.propostasR!.records.first.statusC;
                          }
                          IconData statusIcon;
                          Color statusIconColor;
                          switch (latestStatus) {
                            case 'Aceite':
                              statusIcon = Icons.check_circle;
                              statusIconColor = Colors.green[700]!;
                              break;
                            case 'Enviada':
                            case 'Em Aprovação':
                              statusIcon = Icons.pending_actions;
                              statusIconColor = Colors.blue[700]!;
                              break;
                            case 'Não Aprovada':
                            case 'Cancelada':
                              statusIcon = Icons.cancel;
                              statusIconColor = Colors.red[700]!;
                              break;
                            case 'Expirada':
                            case 'Aprovada':
                              statusIcon = Icons.schedule;
                              statusIconColor = Colors.orange[700]!;
                              break;
                            default:
                              statusIcon = Icons.description;
                              statusIconColor = theme.colorScheme.onSurfaceVariant;
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
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: SimpleListItem(
                                  leading: Icon(
                                    statusIcon, 
                                    color: statusIconColor, 
                                    size: 24,
                                  ),
                                  title: cardName,
                                  subtitle: displayDate,
                                  dynamicTitleSize: true,
                                  onTap: () {
                                    context.push('/opportunity-details', extra: opportunity);
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                loading: () => _buildLoadingIndicator(context, isDark),
                error: (error, stackTrace) => _buildErrorState(context, error, isDark),
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
    final theme = Theme.of(context);
    final textColor = theme.brightness == Brightness.dark ? AppTheme.darkForeground : AppTheme.foreground;
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
        decoration: AppStyles.searchInputDecoration(context, 'Buscar cliente...'),
        onChanged: (value) {
          setState(() => _searchQuery = value.trim());
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;

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

  Widget _buildFloatingActionButton(BuildContext context, bool isDark) {
    return FloatingActionButton(
      backgroundColor: isDark ? AppTheme.darkPrimary : AppTheme.primary,
      elevation: 2.0,
      shape: const CircleBorder(),
      child: Icon(
        CupertinoIcons.add,
        color: isDark ? AppTheme.darkPrimaryForeground : AppTheme.primaryForeground,
      ),
      onPressed: () {
        context.push('/services');
      },
    );
  }

  Widget _buildFilterDropdown(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final borderRadius = BorderRadius.circular(12.0);

    return SizedBox(
      height: 40,
      child: DropdownButtonFormField<OpportunityFilterStatus>(
        value: _selectedFilter,
        isDense: true,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
        decoration: InputDecoration(
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(color: theme.dividerColor.withAlpha((255 * 0.18).round()), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(color: theme.dividerColor.withAlpha((255 * 0.18).round()), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
        ),
        dropdownColor: theme.colorScheme.surface,
        borderRadius: borderRadius,
        alignment: Alignment.center,
        onChanged: (OpportunityFilterStatus? newValue) {
          if (newValue != null && newValue != _selectedFilter) {
            setState(() {
              _selectedFilter = newValue;
            });
          }
        },
        items: OpportunityFilterStatus.values.map((OpportunityFilterStatus status) {
          return DropdownMenuItem<OpportunityFilterStatus>(
            value: status,
            alignment: Alignment.center,
            child: Center(
              child: Text(
                status.displayName,
                style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterIconButton(BuildContext context) {
    final theme = Theme.of(context);
    final isFilterActive = _selectedFilter != OpportunityFilterStatus.todos;
    final isDark = theme.brightness == Brightness.dark;
    
    return SizedBox(
      width: 40,
      height: 40,
      child: PopupMenuButton<OpportunityFilterStatus>(
        padding: EdgeInsets.zero,
        icon: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isFilterActive && isDark
                ? theme.colorScheme.primary.withAlpha((255 * 0.1).round())
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFilterActive ? theme.colorScheme.primary : theme.colorScheme.outline,
              width: isFilterActive ? 2 : 1,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  Icons.filter_list,
                  size: 20,
                  color: isFilterActive 
                      ? theme.colorScheme.primary 
                      : theme.colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                ),
              ),
              if (isFilterActive)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
        offset: const Offset(0, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (OpportunityFilterStatus status) {
          setState(() {
            _selectedFilter = status;
          });
        },
        itemBuilder: (BuildContext context) => OpportunityFilterStatus.values.map((status) {
          final isSelected = _selectedFilter == status;
          return PopupMenuItem<OpportunityFilterStatus>(
            value: status,
            child: Row(
              children: [
                if (isSelected)
                  Icon(
                    Icons.check,
                    size: 18,
                    color: theme.colorScheme.primary,
                  )
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 12),
                Text(
                  status.displayName,
                  style: TextStyle(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}


