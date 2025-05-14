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
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'reseller_opportunity_details_page.dart';

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
      default:
        return 'Filtro'; // Fallback
    }
  }
}

// Define a class to hold status visuals
class _StatusVisuals {
  final IconData? icon;
  final Color iconColor;
  final Color cardIndicatorColor;

  _StatusVisuals({
    this.icon,
    required this.iconColor,
    required this.cardIndicatorColor,
  });
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
  final GlobalKey _cardKey = GlobalKey();

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

  // Method to show filter options using CupertinoActionSheet
  void _showFilterOptions(BuildContext context) {
    final theme = Theme.of(context);
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

  // Widget to build the filter picker button
  Widget _buildFilterPicker(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Use a subtle color for the button to not compete with search icon
    final buttonColor =
        isDark
            ? AppTheme.darkMutedForeground.withOpacity(0.7)
            : AppTheme.mutedForeground.withOpacity(0.7);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8.0), // Minimal padding
      minSize: 0, // Allow button to be as small as its content
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _selectedFilter.displayName,
            style: TextStyle(
              color: buttonColor,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Icon(CupertinoIcons.chevron_down, color: buttonColor, size: 18),
        ],
      ),
      onPressed: () => _showFilterOptions(context),
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
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        bottom: false,
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child:
                  isSmallScreen
                      ? Row(
                        // Mobile UI
                        children: [
                          Expanded(child: _buildSearchBar(context)),
                          if (!_isSearchFocused) const SizedBox(width: 8),
                          _buildFilterPicker(context),
                        ],
                      )
                      : Padding(
                        // Added Padding for desktop top spacing
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Row(
                          // Desktop/Web UI
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .center, // Align items vertically
                          children: [
                            Expanded(
                              // flex: 2, // Search bar will take remaining space
                              child: _buildDesktopSearchBar(context),
                            ),
                            const SizedBox(width: 16),
                            // Expanded(
                            //   flex: 1,
                            //   child: _buildDesktopFilterDropdown(context),
                            // ),
                            SizedBox(
                              // Constrain width of the dropdown
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

                  return AnimationLimiter(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                    itemCount: displayOpportunities.length,
                    itemBuilder: (context, index) {
                        final opportunity = displayOpportunities[index];
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: _buildOpportunityCard(
                        context,
                        opportunity,
                        key: ValueKey(opportunity.id),
                              ),
                            ),
                          ),
                      );
                    },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;
    final iconColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;
    final textColor = isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final textFieldBackgroundColor =
        isDark
            ? AppTheme.darkInput.withAlpha(180) // Slightly more transparent
            : AppTheme.secondary.withAlpha(180); // Slightly more transparent

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SizeTransition(
          sizeFactor: animation,
          axis: Axis.horizontal,
          axisAlignment: -1.0, // Align to the left during transition
          child: child,
        );
      },
      child:
          _isSearchFocused
              ? Container(
                key: const ValueKey('search_field_expanded'),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        placeholder: 'Buscar cliente',
                        placeholderStyle: TextStyle(
                          color: placeholderColor,
                          fontSize: 14,
                        ),
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Icon(
                            CupertinoIcons.search,
                            color: iconColor,
                            size: 18,
                          ),
                        ),
                        suffix:
                            _searchQuery.isNotEmpty
                                ? CupertinoButton(
                                  padding: const EdgeInsets.only(right: 8),
                                  minSize: 0,
                                  child: Icon(
                                    CupertinoIcons.clear_circled_solid,
                                    color: iconColor,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    // No need to call setState as controller listener handles it
                                  },
                                )
                                : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ), // Adjusted padding
                        decoration: BoxDecoration(
                          color: textFieldBackgroundColor,
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        style: TextStyle(fontSize: 15, color: textColor),
                        autofocus: true, // Focus when it becomes visible
                        onTapOutside: (event) {
                          // Added to handle tap outside
                          if (_searchFocusNode.hasFocus) {
                            _searchFocusNode.unfocus();
                          }
                        },
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.only(left: 8.0),
                      minSize: 0,
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _searchFocusNode
                            .unfocus(); // This will trigger the focus listener
                        setState(() {
                          _isSearchFocused = false;
                        });
                      },
                    ),
                  ],
                ),
              )
              : Container(
                key: const ValueKey('search_icon_collapsed'),
                alignment: Alignment.centerLeft, // Keep icon to the left
                child: CupertinoButton(
                  padding: const EdgeInsets.all(0), // Minimal padding
                  child: Icon(
                    CupertinoIcons.search,
                    color: iconColor,
                    size: 26, // Slightly larger icon when collapsed
                  ),
                  onPressed: () {
                    setState(() {
                      _isSearchFocused = true;
                    });
                    // _searchFocusNode.requestFocus(); // Request focus after state change allowing field to build
                  },
                ),
              ),
    );
  }

  Widget _buildDesktopSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;
    final iconColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;
    final textColor = isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final textFieldBackgroundColor =
        isDark
            ? AppTheme.darkInput.withAlpha(
              200,
            ) // Slightly less transparent than mobile's expanded
            : AppTheme.secondary.withAlpha(200);

    return CupertinoTextField(
      controller: _searchController,
      focusNode:
          _searchFocusNode, // Reuse focus node if needed for other logic, or remove if not
      placeholder: 'Buscar cliente...',
      placeholderStyle: TextStyle(color: placeholderColor, fontSize: 14),
      prefix: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Icon(CupertinoIcons.search, color: iconColor, size: 18),
      ),
      suffix:
          _searchQuery.isNotEmpty
              ? CupertinoButton(
                padding: const EdgeInsets.only(right: 8),
                minSize: 0,
                child: Icon(
                  CupertinoIcons.clear_circled_solid,
                  color: iconColor,
                  size: 18,
                ),
                onPressed: () {
                  _searchController.clear();
                },
              )
              : null,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: textFieldBackgroundColor,
        borderRadius: BorderRadius.circular(10.0),
      ),
      style: TextStyle(fontSize: 15, color: textColor),
      // No autofocus for desktop, typically.
      // No onTapOutside needed as it's always visible.
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

  // Helper to get visuals for opportunity status
  _StatusVisuals _getStatusVisuals(String? status, BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    switch (status) {
      case 'Aceite':
        return _StatusVisuals(
          icon: CupertinoIcons.checkmark_seal_fill,
          iconColor: Colors.green,
          cardIndicatorColor: Colors.green.withAlpha((255 * 0.1).round()),
        );
      case 'Enviada':
        return _StatusVisuals(
          icon: CupertinoIcons.exclamationmark_circle_fill,
          iconColor: Colors.blue,
          cardIndicatorColor: Colors.blue.withAlpha((255 * 0.1).round()),
        );
      case 'Em Aprovação':
        return _StatusVisuals(
          icon: CupertinoIcons.doc_text,
          iconColor: theme.primaryColor,
          cardIndicatorColor: theme.primaryColor.withAlpha((255 * 0.1).round()),
        );
      case 'Não Aprovada':
      case 'Cancelada':
        return _StatusVisuals(
          icon: CupertinoIcons.xmark_seal_fill,
          iconColor: Colors.red,
          cardIndicatorColor: Colors.red.withAlpha((255 * 0.1).round()),
        );
      case 'Expirada':
        return _StatusVisuals(
          icon: CupertinoIcons.clock_fill,
          iconColor: Colors.orange,
          cardIndicatorColor: Colors.orange.withAlpha((255 * 0.1).round()),
        );
      default:
        return _StatusVisuals(
          icon: CupertinoIcons.doc_text,
          iconColor: theme.colorScheme.onSurfaceVariant,
          cardIndicatorColor: theme.colorScheme.primary.withAlpha((255 * 0.05).round()),
        );
    }
  }

  // Build the custom filter dropdown
  Widget _buildFilterDropdown(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final borderColor = isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;
    final dropdownColor = theme.colorScheme.surface;

    return Container(
      // padding: const EdgeInsets.symmetric(vertical: 0), // Removed to let DropdownButtonFormField control height primarily
      decoration: BoxDecoration(
        color: dropdownColor,
        borderRadius: BorderRadius.circular(10.0), // Match search bar
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1.0),
      ),
      child: DropdownButtonFormField<OpportunityFilterStatus>(
        isDense: true,
        value: _selectedFilter,
        icon: Icon(
          CupertinoIcons.chevron_down,
          size: 16,
          color: textColor.withOpacity(0.7),
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 11.0,
          ), // Adjusted for vertical alignment
          border: InputBorder.none,
          isDense: true, // Makes the field more compact vertically
        ),
        isExpanded: true,
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
            child: Text(
              status.displayName,
              style: TextStyle(
                fontSize: 15,
                color: textColor,
              ), // Style for the selected item text
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

  // Get rect of widget using its GlobalKey
  Rect? _getWidgetRect(GlobalKey key) {
    final RenderBox? renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    
    final position = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      renderBox.size.width,
      renderBox.size.height,
        );
    }

  // Navigate to detail page with animation
  void _navigateToDetailPage(BuildContext context, sfo.SalesforceOpportunity opportunity, GlobalKey cardKey) {
    // Instead of complex custom route, use GoRouter with extra data
    // This ensures the details page is shown as a separate route without nesting
    context.push('/opportunity-details', extra: opportunity);
  }

  Widget _buildOpportunityCard(
    BuildContext context,
    sfo.SalesforceOpportunity opportunity, {
    Key? key,
  }) {
    // Create a unique key for this specific card
    final cardKey = GlobalKey();

    return _AnimatedOpportunityCard(
      opportunity: opportunity, 
      cardKey: cardKey,
      onTap: (cardKey) => _navigateToDetailPage(context, opportunity, cardKey),
    );
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
    IconData? statusIcon;
    Color statusIconColor = theme.colorScheme.onSurfaceVariant;
    
    // Basic status icon mapping
    switch (latestStatus) {
      case 'Aceite':
        statusIcon = CupertinoIcons.checkmark_seal_fill;
        statusIconColor = Colors.green;
        break;
      case 'Enviada':
        statusIcon = CupertinoIcons.exclamationmark_circle_fill;
        statusIconColor = Colors.blue;
        break;
      case 'Não Aprovada':
      case 'Cancelada':
        statusIcon = CupertinoIcons.xmark_seal_fill;
        statusIconColor = Colors.red;
        break;
      case 'Expirada':
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
      child: Material(
        type: MaterialType.transparency,
          child: Container(
          key: widget.cardKey,
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0), 
            decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7), // Standardized card color
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: isDark 
                    ? theme.colorScheme.shadow.withOpacity(0.2) 
                    : theme.colorScheme.shadow.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
            border: Border.all(
              color: isDark 
                  ? theme.colorScheme.onSurface.withOpacity(0.05) 
                  : Colors.transparent,
              width: isDark ? 1.0 : 0,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12.0), 
            onTap: () {
              // Play the press animation
              _controller.forward().then((_) {
                // Navigate after animation completes
                widget.onTap(widget.cardKey);
                
                // Reset the animation after navigation
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    _controller.reverse();
                  }
                });
              });
            },
            child: SizedBox(
              height: 88.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                    if (statusIcon != null) Icon(statusIcon, color: statusIconColor, size: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


