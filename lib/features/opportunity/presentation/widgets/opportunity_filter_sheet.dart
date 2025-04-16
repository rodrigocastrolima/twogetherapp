import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/service_types.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Callback type for applying filters
typedef ApplyFiltersCallback =
    void Function(
      String? reseller,
      ServiceCategory? serviceType,
      EnergyType? energyType,
    );

class OpportunityFilterSheet extends StatefulWidget {
  final String? initialReseller;
  final ServiceCategory? initialServiceType;
  final EnergyType? initialEnergyType;
  final List<String> availableResellers;
  final ApplyFiltersCallback onApplyFilters;

  const OpportunityFilterSheet({
    super.key,
    required this.initialReseller,
    required this.initialServiceType,
    required this.initialEnergyType,
    required this.availableResellers,
    required this.onApplyFilters,
  });

  @override
  State<OpportunityFilterSheet> createState() => _OpportunityFilterSheetState();
}

class _OpportunityFilterSheetState extends State<OpportunityFilterSheet> {
  late String? _tempSelectedReseller;
  late ServiceCategory? _tempSelectedServiceType;
  late EnergyType? _tempSelectedEnergyType;

  @override
  void initState() {
    super.initState();
    // Initialize temporary state with initial values from the parent page
    _tempSelectedReseller = widget.initialReseller;
    _tempSelectedServiceType = widget.initialServiceType;
    _tempSelectedEnergyType = widget.initialEnergyType;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16).copyWith(
        bottom:
            MediaQuery.of(context).viewInsets.bottom + 16, // Handle keyboard
        top: 8, // Add space for handle
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                _buildFilterSectionTitle(context, 'Reseller'), // TODO: l10n
                _buildRadioListTile<String?>(
                  title: 'All Resellers', // TODO: l10n
                  value: null,
                  groupValue: _tempSelectedReseller,
                  onChanged:
                      (val) => setState(() => _tempSelectedReseller = val),
                ),
                ...widget.availableResellers.map(
                  (reseller) => _buildRadioListTile<String?>(
                    title: reseller,
                    value: reseller,
                    groupValue: _tempSelectedReseller,
                    onChanged:
                        (val) => setState(() => _tempSelectedReseller = val),
                  ),
                ),
                Divider(height: 24, thickness: 0.5),

                _buildFilterSectionTitle(context, 'Service Type'), // TODO: l10n
                _buildRadioListTile<ServiceCategory?>(
                  title: 'All Service Types', // TODO: l10n
                  value: null,
                  groupValue: _tempSelectedServiceType,
                  onChanged:
                      (val) => setState(() => _tempSelectedServiceType = val),
                ),
                ...ServiceCategory.values.map(
                  (type) => _buildRadioListTile<ServiceCategory?>(
                    title: type.displayName,
                    value: type,
                    groupValue: _tempSelectedServiceType,
                    onChanged:
                        (val) => setState(() => _tempSelectedServiceType = val),
                  ),
                ),
                Divider(height: 24, thickness: 0.5),

                _buildFilterSectionTitle(context, 'Energy Type'), // TODO: l10n
                _buildRadioListTile<EnergyType?>(
                  title: 'All Energy Types', // TODO: l10n
                  value: null,
                  groupValue: _tempSelectedEnergyType,
                  onChanged:
                      (val) => setState(() => _tempSelectedEnergyType = val),
                ),
                ...EnergyType.values.map(
                  (type) => _buildRadioListTile<EnergyType?>(
                    title: type.displayName,
                    value: type,
                    groupValue: _tempSelectedEnergyType,
                    onChanged:
                        (val) => setState(() => _tempSelectedEnergyType = val),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  // Call callback with nulls to clear filters and close sheet
                  widget.onApplyFilters(null, null, null);
                  Navigator.pop(context);
                },
                child: Text(l10n.commonClear), // TODO: l10n for Clear
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  // Call callback with selected values and close sheet
                  widget.onApplyFilters(
                    _tempSelectedReseller,
                    _tempSelectedServiceType,
                    _tempSelectedEnergyType,
                  );
                  Navigator.pop(context);
                },
                child: Text(l10n.commonApply), // TODO: l10n for Apply
              ),
            ],
          ),
        ],
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

  // Generic RadioListTile builder
  Widget _buildRadioListTile<T>({
    required String title,
    required T value,
    required T groupValue,
    required ValueChanged<T?> onChanged,
  }) {
    return RadioListTile<T>(
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}
