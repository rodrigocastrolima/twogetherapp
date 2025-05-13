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
      backgroundColor: Colors.transparent,
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

                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: displayOpportunities.length,
                    separatorBuilder:
                        (context, index) => const SizedBox.shrink(),
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
    final colorScheme = theme.colorScheme; // Added for gradient
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final mutedTextColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;

    String? latestStatus;
    if (opportunity.propostasR?.records != null &&
        opportunity.propostasR!.records.isNotEmpty) {
      latestStatus = opportunity.propostasR!.records.first.statusC;
    }

    final statusVisuals = _getStatusVisuals(latestStatus, context);

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
      child: Card(
        // Changed from Material to Card
        key: key,
        // color: statusVisuals.cardBgColor, // Color will be handled by gradient in Container
        elevation: isDark ? 1.0 : 2.0, // Adjusted elevation
        shadowColor:
            isDark
                ? Colors.black.withOpacity(0.5)
                : Colors.grey.withOpacity(0.3), // Adjusted shadowColor
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          // side: BorderSide(color: statusVisuals.outlineColor, width: 1.5), // Removed BorderSide
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            context.push('/opportunity-details', extra: opportunity);
          },
          child: Container(
            // Added Container for gradient
            decoration: BoxDecoration(
              gradient:
                  isDark
                      ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.surfaceVariant.withOpacity(0.1),
                          colorScheme.surfaceVariant.withOpacity(0.05),
                        ],
                      )
                      : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.grey.shade50.withOpacity(0.5),
                        ],
                      ),
            ),
            child: SizedBox(
              // Keep the SizedBox for fixed height
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
                            child: Text(
                              cardName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (displayDate.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              displayDate,
                              style: TextStyle(
                                fontSize: 13,
                                color: mutedTextColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (statusVisuals.icon != null)
                      Icon(
                        statusVisuals.icon,
                        color:
                            statusVisuals
                                .iconColor, // Icon color remains based on status
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopFilterDropdown(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dropdownColor = isDark ? AppTheme.darkInput : AppTheme.input;
    final textColor = isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.border;

    return Container(
      // padding: const EdgeInsets.symmetric(vertical: 0), // Removed to let DropdownButtonFormField control height primarily
      decoration: BoxDecoration(
        color: dropdownColor,
        borderRadius: BorderRadius.circular(10.0), // Match search bar
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1.0),
      ),
      child: DropdownButtonFormField<OpportunityFilterStatus>(
        value: _selectedFilter,
        items:
            OpportunityFilterStatus.values.map((
              OpportunityFilterStatus status,
            ) {
              return DropdownMenuItem<OpportunityFilterStatus>(
                value: status,
                child: Text(
                  status.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                    fontWeight: FontWeight.normal,
                  ), // Ensure normal weight
                ),
              );
            }).toList(),
        onChanged: (OpportunityFilterStatus? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedFilter = newValue;
            });
          }
        },
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 11.0,
          ), // Adjusted for vertical alignment
          border: InputBorder.none,
          isDense: true, // Makes the field more compact vertically
        ),
        isExpanded: true,
        dropdownColor: dropdownColor,
        icon: Icon(
          CupertinoIcons.chevron_down,
          color:
              isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground,
          size: 18,
        ),
        style: TextStyle(
          fontSize: 15,
          color: textColor,
        ), // Style for the selected item text
      ),
    );
  }
}
