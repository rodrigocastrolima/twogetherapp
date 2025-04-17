import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/service_types.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    const allEnergyTypes = EnergyType.values;
    const allServiceCategories = ServiceCategory.values;

    // Determine checkbox state for "All" options
    bool isAllResellersSelected =
        _tempSelectedResellers == null ||
        _tempSelectedResellers!.isEmpty; // Treat empty set as 'All'
    bool isAllServiceTypesSelected =
        _tempSelectedServiceTypes == null ||
        _tempSelectedServiceTypes!.isEmpty; // Treat empty set as 'All'

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

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(
        16,
      ).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 16, top: 8),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Filters', // TODO: l10n
                style: theme.textTheme.titleLarge,
              ),
            ),

            // Scrollable Filter Options
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // --- Reseller Filter (Checkboxes) ---
                  _buildFilterSectionTitle(
                    context,
                    l10n.resellerRole,
                  ), // Use existing l10n key
                  _buildCheckboxListTile(
                    context,
                    title: 'All Resellers', // TODO: l10n
                    value: isAllResellersSelected,
                    onChanged:
                        (selected) => handleAllSelection(
                          selected,
                          _tempSelectedResellers,
                          (newSet) => _tempSelectedResellers = newSet,
                        ),
                  ),
                  ...widget.availableResellers.map((reseller) {
                    return _buildCheckboxListTile(
                      context,
                      title: reseller,
                      value:
                          !isAllResellersSelected &&
                          (_tempSelectedResellers?.contains(reseller) ?? false),
                      onChanged:
                          (selected) => handleItemSelection(
                            selected,
                            reseller,
                            _tempSelectedResellers,
                            (newSet) => _tempSelectedResellers = newSet,
                          ),
                    );
                  }).toList(),
                  Divider(height: 24, thickness: 0.5),

                  // --- Service Type Filter (Checkboxes with Inline Energy) ---
                  _buildFilterSectionTitle(
                    context,
                    l10n.servicesSelectType,
                  ), // Use existing l10n key
                  _buildCheckboxListTile(
                    context,
                    title: 'All Service Types', // TODO: l10n
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
                      _buildCheckboxListTile(
                        context,
                        title: serviceType.displayName,
                        value: isSelected,
                        onChanged:
                            (selected) => handleItemSelection(
                              selected,
                              serviceType,
                              _tempSelectedServiceTypes,
                              (newSet) => _tempSelectedServiceTypes = newSet,
                            ),
                      ),
                      // --- Inline Energy Type Checkboxes ---
                      if (serviceType == ServiceCategory.energy && isSelected)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 24.0,
                            top: 0,
                            bottom: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- Energy Type Sub-section (Checkboxes) ---
                              ...allEnergyTypes.map((energyType) {
                                // Determine if this energy type should be checked
                                // It's checked if the main set is null (meaning all implicitly selected *within* the Energy category)
                                // OR if the set is not null and contains the type.
                                final isEnergyTypeChecked =
                                    _tempSelectedEnergyTypes == null ||
                                    (_tempSelectedEnergyTypes?.contains(
                                          energyType,
                                        ) ??
                                        false);

                                return _buildCheckboxListTile(
                                  context,
                                  title: energyType.displayName,
                                  value: isEnergyTypeChecked,
                                  onChanged: (bool? selected) {
                                    setState(() {
                                      // When an individual energy type is toggled,
                                      // initialize the set from ALL types if it was null (implicit all).
                                      _tempSelectedEnergyTypes ??=
                                          Set<EnergyType>.from(allEnergyTypes);

                                      if (selected == true) {
                                        _tempSelectedEnergyTypes!.add(
                                          energyType,
                                        );
                                      } else {
                                        _tempSelectedEnergyTypes!.remove(
                                          energyType,
                                        );
                                        // If the set becomes empty, revert to implicit 'All' (null)
                                        if (_tempSelectedEnergyTypes!.isEmpty) {
                                          _tempSelectedEnergyTypes = null;
                                        }
                                      }
                                    });
                                  },
                                  isDense:
                                      true, // Make nested items more compact
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                    ];
                  }).toList(),
                ],
              ),
            ),

            // Action Buttons (Apply logic needs to handle null sets correctly)
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // Reset temporary selections to null (meaning "All")
                    setState(() {
                      _tempSelectedResellers = null;
                      _tempSelectedServiceTypes = null;
                      _tempSelectedEnergyTypes = null;
                    });
                    // Apply cleared filters immediately
                    widget.onApplyFilters(null, null, null);
                    Navigator.pop(context);
                  },
                  child: Text(l10n.commonClear),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    // Apply the temporary selections
                    widget.onApplyFilters(
                      _tempSelectedResellers, // null means All
                      _tempSelectedServiceTypes, // null means All
                      // If Energy service type is not selected, energy selection is irrelevant (pass null)
                      (_tempSelectedServiceTypes != null &&
                              _tempSelectedServiceTypes!.contains(
                                ServiceCategory.energy,
                              ))
                          ? _tempSelectedEnergyTypes // Pass the actual selection (null means All Energy Types)
                          : null,
                    );
                    Navigator.pop(context);
                  },
                  child: Text(l10n.commonApply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // Updated CheckboxListTile builder
  Widget _buildCheckboxListTile(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
    bool isDense = false, // Added optional density parameter
  }) {
    return CheckboxListTile(
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      value: value,
      onChanged: onChanged,
      dense: isDense, // Use parameter
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      visualDensity: isDense ? VisualDensity.compact : VisualDensity.standard, // Adjust density
    );
  }
}
