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
        return 'Ação Necessária'; // Kept longer name as it fits button
      case OpportunityFilterStatus.pendentes:
        return 'Pendentes';
      case OpportunityFilterStatus.rejeitados:
        return 'Rejeitados';
    }
  }
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
  bool _isSearchFocused = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _isSearchFocused) {
        setState(() {
          _isSearchFocused = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    }
  }

  // Method to show filter options using CupertinoActionSheet
  void _showFilterOptions(BuildContext context) {
    final cupertinoTheme = CupertinoTheme.of(context);

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext modalContext) {
        return CupertinoActionSheet(
          title: const Text('Selecionar Filtro'),
          actions:
              OpportunityFilterStatus.values.map((status) {
                return CupertinoActionSheetAction(
                  child: Text(
                    status.displayName,
                    style: cupertinoTheme.textTheme.actionTextStyle.copyWith(
                      color:
                          _selectedFilter == status
                              ? cupertinoTheme.primaryColor
                              : null, // Default color if not selected
                      fontWeight:
                          _selectedFilter == status
                              ? FontWeight.bold
                              : FontWeight.normal,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedFilter = status;
                    });
                    Navigator.pop(modalContext);
                  },
                );
              }).toList(),
          cancelButton: CupertinoActionSheetAction(
            child: Text(
              'Cancelar',
              style: cupertinoTheme.textTheme.actionTextStyle.copyWith(
                color: CupertinoColors.systemRed, // Standard cancel color
              ),
            ),
            onPressed: () {
              Navigator.pop(modalContext);
            },
          ),
        );
      },
    );
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
                  const Icon(CupertinoIcons.exclamationmark_circle_fill, color: Colors.blue),
                  'Ação Necessária:',
                  'Requer a sua atenção para dar seguimento ao processo.',
                ),
                const SizedBox(height: 8),
                _buildLegendRow(
                  context,
                  const Icon(CupertinoIcons.clock_fill, color: Colors.orange),
                  'A Aguardar:',
                  'A Twogether está a tratar desta oportunidade ou o prazo expirou. Por favor, aguarde ou verifique.',
                ),
                const SizedBox(height: 8),
                _buildLegendRow(
                  context,
                  const Icon(CupertinoIcons.checkmark_seal_fill, color: Colors.green),
                  'Concluído:',
                  'O processo desta oportunidade foi finalizado com sucesso.',
                ),
                const SizedBox(height: 8),
                _buildLegendRow(
                  context,
                  const Icon(CupertinoIcons.xmark_seal_fill, color: Colors.red),
                  'Cancelada/Rejeitada:',
                  'Esta oportunidade foi cancelada ou não foi aprovada.',
                ),
                const SizedBox(height: 8),
                _buildLegendRow(
                  context,
                  Icon(CupertinoIcons.doc_text, color: theme.colorScheme.onSurfaceVariant),
                  'Outro:',
                  'Oportunidade em estado inicial ou outro.',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Fechar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendRow(BuildContext context, Icon icon, String title, String subtitle) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        icon,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodyMedium),
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
    final bool isSmallScreen =
        screenWidth < 600; // Threshold for mobile/desktop

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Clientes',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    richMessage: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontSize: 15, // Increased font size
                      ),
                      children: <InlineSpan>[
                        const TextSpan(text: 'Legenda dos Ícones:\n', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), // Title font size
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(CupertinoIcons.exclamationmark_circle_fill, color: Colors.blue, size: 20), // Increased icon size
                        ),
                        const TextSpan(text: ' Ação Necessária: Requer a sua atenção.\n'),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(CupertinoIcons.clock_fill, color: Colors.orange, size: 20), // Increased icon size
                        ),
                        const TextSpan(text: ' A Aguardar: Aguarde a Twogether ou verifique.\n'),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(CupertinoIcons.checkmark_seal_fill, color: Colors.green, size: 20), // Increased icon size
                        ),
                        const TextSpan(text: ' Concluído: Processo finalizado com sucesso.\n'),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(CupertinoIcons.xmark_seal_fill, color: Colors.red, size: 20), // Increased icon size
                        ),
                        const TextSpan(text: ' Cancelada/Rejeitada: Oportunidade não aprovada.\n'),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(CupertinoIcons.doc_text, color: theme.colorScheme.onSurfaceVariant, size: 20), // Increased icon size
                        ),
                        const TextSpan(text: ' Outro: Estado inicial ou diferente.'),
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
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child:
                  isSmallScreen
                      ? Row(
                          children: [
                            Expanded(child: _buildSearchBar(context)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 160,
                              child: _buildFilterDropdown(context),
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _buildDesktopSearchBar(context),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 200.0,
                                child: _buildDesktopFilterDropdown(context),
                              ),
                            ],
                          ),
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
                          IconData? statusIcon;
                          Color statusIconColor = theme.colorScheme.onSurfaceVariant;
                          switch (latestStatus) {
                            case 'Aceite':
                              statusIcon = CupertinoIcons.checkmark_seal_fill;
                              statusIconColor = Colors.green;
                              break;
                            case 'Enviada':
                            case 'Em Aprovação':
                              statusIcon = CupertinoIcons.exclamationmark_circle_fill;
                              statusIconColor = Colors.blue;
                              break;
                            case 'Não Aprovada':
                            case 'Cancelada':
                              statusIcon = CupertinoIcons.xmark_seal_fill;
                              statusIconColor = Colors.red;
                              break;
                            case 'Expirada':
                            case 'Aprovada':
                              statusIcon = CupertinoIcons.clock_fill;
                              statusIconColor = Colors.orange;
                              break;
                            default:
                              statusIcon = CupertinoIcons.doc_text;
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
                                  leading: Icon(statusIcon, color: statusIconColor, size: 28),
                                  title: cardName,
                                  subtitle: displayDate,
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
    final theme = Theme.of(context);
    final textColor = theme.brightness == Brightness.dark ? AppTheme.darkForeground : AppTheme.foreground;
    final borderRadius = BorderRadius.circular(12.0);
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

  Widget _buildDesktopSearchBar(BuildContext context) {
    return _buildSearchBar(context);
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

  // Build the custom filter dropdown
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

  // Build the desktop filter dropdown
  Widget _buildDesktopFilterDropdown(BuildContext context) {
    // Reuse the same implementation as the standard filter dropdown
    // with any adjustments needed for desktop layout
    return _buildFilterDropdown(context);
  }
}

// Separate card widget with animation
class _AnimatedOpportunityCard extends StatefulWidget {
  final sfo.SalesforceOpportunity opportunity;
  final GlobalKey cardKey;
  final Function(GlobalKey) onTap;

  const _AnimatedOpportunityCard({
    required this.opportunity,
    required this.cardKey,
    required this.onTap,
  });

  @override
  State<_AnimatedOpportunityCard> createState() => _AnimatedOpportunityCardState();
}

class _AnimatedOpportunityCardState extends State<_AnimatedOpportunityCard> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final mutedTextColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;

    String? latestStatus;
    if (widget.opportunity.propostasR?.records != null &&
        widget.opportunity.propostasR!.records.isNotEmpty) {
      latestStatus = widget.opportunity.propostasR!.records.first.statusC;
    }

    // Create our own simple status visual properties
    IconData statusIcon;
    Color statusIconColor = theme.colorScheme.onSurfaceVariant;
    // Basic status icon mapping with fallback
    switch (latestStatus) {
      case 'Aceite':
        statusIcon = CupertinoIcons.checkmark_seal_fill;
        statusIconColor = Colors.green;
        break;
      case 'Enviada':
      case 'Em Aprovação':
        statusIcon = CupertinoIcons.exclamationmark_circle_fill;
        statusIconColor = Colors.blue;
        break;
      case 'Não Aprovada':
      case 'Cancelada':
        statusIcon = CupertinoIcons.xmark_seal_fill;
        statusIconColor = Colors.red;
        break;
      case 'Expirada':
      case 'Aprovada':
        statusIcon = CupertinoIcons.clock_fill;
        statusIconColor = Colors.orange;
        break;
      default:
        statusIcon = CupertinoIcons.doc_text;
        statusIconColor = theme.colorScheme.onSurfaceVariant;
    }

    String displayDate = '';
    if (widget.opportunity.createdDate != null) {
      try {
        final dateTime = DateTime.parse(widget.opportunity.createdDate!);
        displayDate = DateFormat('dd/MM/yy', 'pt_PT').format(dateTime);
      } catch (e) {
        displayDate = '';
      }
    }

    final cardName = widget.opportunity.accountName ?? widget.opportunity.name;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: SizedBox(
        height: 64.0,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            // Navigate to details page
            context.push('/opportunity-details', extra: widget.opportunity);
          },
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(cardName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (displayDate.isNotEmpty) ...[const SizedBox(height: 4), Text(displayDate, style: TextStyle(fontSize: 13, color: mutedTextColor))],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(statusIcon, color: statusIconColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}


