import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/service_types.dart';

// Callback type definition - Updated for Sets
typedef ApplyFiltersCallback =
    void Function(
      Set<String>? resellers,
      Set<ServiceCategory>? serviceTypes,
      Set<EnergyType>? energyTypes,
    );

class OpportunityFilterSheet extends StatefulWidget {
  // --- Ensure these use Sets ---
  final Set<String>? initialResellers;
  final Set<ServiceCategory>? initialServiceTypes;
  final Set<EnergyType>? initialEnergyTypes;
  // ---------------------------
  final List<String> availableResellers;
  final ApplyFiltersCallback onApplyFilters;

  const OpportunityFilterSheet({
    super.key,
    // --- Ensure constructor uses Sets ---
    required this.initialResellers,
    required this.initialServiceTypes,
    required this.initialEnergyTypes,
    // ---------------------------------
    required this.availableResellers,
    required this.onApplyFilters,
  });

  @override
  State<OpportunityFilterSheet> createState() => _OpportunityFilterSheetState();
}

class _OpportunityFilterSheetState extends State<OpportunityFilterSheet> {
  // Updated temporary state types
  late Set<String>? _tempSelectedResellers;
  late Set<ServiceCategory>? _tempSelectedServiceTypes;
  late Set<EnergyType>? _tempSelectedEnergyTypes;

  @override
  void initState() {
    super.initState();
    // Initialize temporary state Sets (handle nulls, create copies)
    _tempSelectedResellers =
        widget.initialResellers == null
            ? null
            : Set<String>.from(widget.initialResellers!);
    _tempSelectedServiceTypes =
        widget.initialServiceTypes == null
            ? null
            : Set<ServiceCategory>.from(widget.initialServiceTypes!);
    _tempSelectedEnergyTypes =
        widget.initialEnergyTypes == null
            ? null
            : Set<EnergyType>.from(widget.initialEnergyTypes!);
  }

  @override
  Widget build(BuildContext context) {
    // Use Cupertino theme data if available, fallback to Material
    final cupertinoTheme = CupertinoTheme.of(context);
    final theme = Theme.of(context);
    const allEnergyTypes = EnergyType.values;
    const allServiceCategories = ServiceCategory.values;

    bool isAllResellersSelected =
        _tempSelectedResellers == null || _tempSelectedResellers!.isEmpty;
    bool isAllServiceTypesSelected =
        _tempSelectedServiceTypes == null || _tempSelectedServiceTypes!.isEmpty;

    // --- Helper function to handle "All" selection logic ---
    void handleAllSelection<T>(
      bool? selected,
      Set<T>? currentSet,
      Function(Set<T>?) updateState,
    ) {
      setState(() {
        if (selected == true) {
          updateState(null); // null represents 'All'
        } else {
          updateState(
            {},
          ); // Empty set means nothing selected (except potentially 'All' if re-checked)
        }
        // If selecting/deselecting 'All Services', also clear energy types
        if (T == ServiceCategory) {
          _tempSelectedEnergyTypes = null;
        }
      });
    }

    // --- Helper function to handle individual item selection ---
    void handleItemSelection<T>(
      bool? selected,
      T item,
      Set<T>? currentSet,
      Function(Set<T>?) updateState,
    ) {
      setState(() {
        Set<T> newSet =
            currentSet == null
                ? {}
                : Set<T>.from(currentSet); // Create mutable copy or new set
        if (selected == true) {
          newSet.add(item);
        } else {
          newSet.remove(item);
        }
        updateState(
          newSet.isEmpty ? null : newSet,
        ); // If empty, revert to 'All' (null)

        // Special handling for ServiceCategory -> EnergyType
        if (T == ServiceCategory) {
          final serviceCategoryItem = item as ServiceCategory;
          // If Energy is deselected, clear energy types
          if (serviceCategoryItem == ServiceCategory.energy &&
              selected == false) {
            _tempSelectedEnergyTypes = null;
          }
          // If Energy is selected, ensure energy types is at least an empty set
          else if (serviceCategoryItem == ServiceCategory.energy &&
              selected == true &&
              _tempSelectedEnergyTypes == null) {
            _tempSelectedEnergyTypes = {};
          }
        }
      });
    }
    // -----------------------------------------------------------

    // Use CupertinoPageScaffold for basic structure if needed, or just Column
    // Using Column directly within the bottom sheet container
    return Padding(
      // Use safe area padding for bottom notch/insets
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom,
        left: 8,
        right: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Optional: Add a title bar if needed, or rely on sheet context
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Text(
              'Filtrar Oportunidades', // Replaced l10n.adminOpportunityFilterSheetTitle
              style: cupertinoTheme.textTheme.navTitleTextStyle,
            ),
          ),

          // Scrollable Filter Options using CupertinoListSection
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  CupertinoListSection.insetGrouped(
                    header: Text(
                      'Revendedor'.toUpperCase(),
                    ), // Replaced l10n.resellerRole
                    backgroundColor: Colors.transparent, // Inherit from sheet
                    children: <Widget>[
                      _buildCupertinoCheckboxTile(
                        context,
                        title:
                            'Todos os Revendedores', // Replaced hardcoded string
                        value: isAllResellersSelected,
                        onChanged:
                            (selected) => handleAllSelection(
                              selected,
                              _tempSelectedResellers,
                              (newSet) => _tempSelectedResellers = newSet,
                            ),
                      ),
                      ...widget.availableResellers.map((reseller) {
                        return _buildCupertinoCheckboxTile(
                          context,
                          title: reseller,
                          value:
                              !isAllResellersSelected &&
                              (_tempSelectedResellers?.contains(reseller) ??
                                  false),
                          onChanged:
                              (selected) => handleItemSelection(
                                selected,
                                reseller,
                                _tempSelectedResellers,
                                (newSet) => _tempSelectedResellers = newSet,
                              ),
                        );
                      }).toList(),
                    ],
                  ),
                  CupertinoListSection.insetGrouped(
                    header: Text(
                      'Tipo de Serviço'.toUpperCase(),
                    ), // Replaced l10n.servicesSelectType
                    backgroundColor: Colors.transparent,
                    children: <Widget>[
                      _buildCupertinoCheckboxTile(
                        context,
                        title:
                            'Todos os Tipos de Serviço', // Replaced hardcoded string
                        value: isAllServiceTypesSelected,
                        onChanged:
                            (selected) => handleAllSelection(
                              selected,
                              _tempSelectedServiceTypes,
                              (newSet) => _tempSelectedServiceTypes = newSet,
                            ),
                      ),
                      ...allServiceCategories.expand((serviceType) {
                        final isSelected =
                            !isAllServiceTypesSelected &&
                            (_tempSelectedServiceTypes?.contains(serviceType) ??
                                false);
                        return [
                          _buildCupertinoCheckboxTile(
                            context,
                            title: serviceType.displayName,
                            value: isSelected,
                            onChanged:
                                (selected) => handleItemSelection(
                                  selected,
                                  serviceType,
                                  _tempSelectedServiceTypes,
                                  (newSet) =>
                                      _tempSelectedServiceTypes = newSet,
                                ),
                          ),
                          // --- Inline Energy Type Checkboxes (Nested Section) ---
                          if (serviceType == ServiceCategory.energy &&
                              isSelected)
                            // Use another list section for nesting
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 15.0,
                              ), // Indent nested items
                              child: CupertinoListSection.insetGrouped(
                                // header: Text('Energy Types'), // Optional sub-header
                                margin: EdgeInsets.zero,
                                backgroundColor: Colors.transparent,
                                children: <Widget>[
                                  ...allEnergyTypes.map((energyType) {
                                    final isEnergyTypeChecked =
                                        _tempSelectedEnergyTypes == null ||
                                        (_tempSelectedEnergyTypes?.contains(
                                              energyType,
                                            ) ??
                                            false);
                                    return _buildCupertinoCheckboxTile(
                                      context,
                                      title: energyType.displayName,
                                      value: isEnergyTypeChecked,
                                      onChanged: (bool? selected) {
                                        setState(() {
                                          _tempSelectedEnergyTypes ??=
                                              Set<EnergyType>.from(
                                                allEnergyTypes,
                                              );
                                          if (selected == true) {
                                            _tempSelectedEnergyTypes!.add(
                                              energyType,
                                            );
                                          } else {
                                            _tempSelectedEnergyTypes!.remove(
                                              energyType,
                                            );
                                            if (_tempSelectedEnergyTypes!
                                                .isEmpty) {
                                              _tempSelectedEnergyTypes = null;
                                            }
                                          }
                                        });
                                      },
                                      // Make nested items slightly smaller text?
                                      // textStyle: cupertinoTheme.textTheme.textStyle.copyWith(fontSize: 14),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                        ];
                      }).toList(),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween, // Space out buttons
              children: [
                CupertinoButton(
                  padding:
                      EdgeInsets
                          .zero, // Remove default padding for cleaner look
                  onPressed: () {
                    setState(() {
                      _tempSelectedResellers = null;
                      _tempSelectedServiceTypes = null;
                      _tempSelectedEnergyTypes = null;
                    });
                    widget.onApplyFilters(null, null, null);
                    Navigator.pop(context);
                  },
                  child: Text('Limpar'), // Replaced l10n.commonClear
                ),
                CupertinoButton.filled(
                  // Use filled style for primary action
                  onPressed: () {
                    widget.onApplyFilters(
                      _tempSelectedResellers,
                      _tempSelectedServiceTypes,
                      (_tempSelectedServiceTypes != null &&
                              _tempSelectedServiceTypes!.contains(
                                ServiceCategory.energy,
                              ))
                          ? _tempSelectedEnergyTypes
                          : null,
                    );
                    Navigator.pop(context);
                  },
                  child: Text('Aplicar'), // Replaced l10n.commonApply
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW: Cupertino Checkbox Tile Builder ---
  Widget _buildCupertinoCheckboxTile(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
    TextStyle? textStyle, // Optional text style
  }) {
    final theme = CupertinoTheme.of(context);
    return CupertinoListTile(
      // Use standard list tile
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      title: Text(
        title,
        style:
            textStyle ??
            theme.textTheme.textStyle, // Use provided or default style
      ),
      leading: CupertinoCheckbox(
        value: value,
        onChanged: onChanged,
        activeColor: theme.primaryColor, // Use theme's primary color
      ),
      onTap: () => onChanged(!value), // Toggle checkbox on tap
    );
  }
}
