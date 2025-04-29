import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:twogether/l10n/l10n.dart'; // Import l10n
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Add missing import
import 'package:file_picker/file_picker.dart'; // Import file_picker
// TODO: Import other necessary providers/models

// --- Helper Class for CPE Input Data --- //
class _CpeInputData {
  final TextEditingController cpeController = TextEditingController();
  final TextEditingController nifController = TextEditingController();
  final TextEditingController consumoController = TextEditingController();
  final TextEditingController fidelizacaoController = TextEditingController();
  final TextEditingController cicloController = TextEditingController();
  final TextEditingController comissaoController = TextEditingController();
  List<PlatformFile> attachedFiles = []; // List to hold files for this CPE

  // Call this when removing a block to prevent memory leaks
  void dispose() {
    cpeController.dispose();
    nifController.dispose();
    consumoController.dispose();
    fidelizacaoController.dispose();
    cicloController.dispose();
    comissaoController.dispose();
    // attachedFiles doesn't need disposal
  }
}
// --- End Helper Class --- //

class ProposalCreationPage extends ConsumerStatefulWidget {
  final String salesforceOpportunityId;
  final String salesforceAccountId;
  final String accountName;
  final String resellerSalesforceId;
  final String resellerName;
  final String nif;
  final String opportunityName;

  const ProposalCreationPage({
    super.key,
    required this.salesforceOpportunityId,
    required this.salesforceAccountId,
    required this.accountName,
    required this.resellerSalesforceId,
    required this.resellerName,
    required this.nif,
    required this.opportunityName,
  });

  @override
  ConsumerState<ProposalCreationPage> createState() =>
      _ProposalCreationPageState();
}

class _ProposalCreationPageState extends ConsumerState<ProposalCreationPage> {
  final _formKey = GlobalKey<FormState>();

  // --- Controllers for Informação da Entidade --- //
  late TextEditingController _nifController;
  late TextEditingController _responsavelNegocioController;

  // --- Controllers & State for Informação da Proposta --- //
  late TextEditingController _proposalNameController;
  late TextEditingController _solutionController;
  late TextEditingController _validityDateController;
  late TextEditingController _bundleController;
  late TextEditingController _solarInvestmentController;
  late TextEditingController _creationDateController; // For read-only display

  bool _energiaChecked = false;
  bool _solarChecked = false;
  DateTime? _selectedValidityDate;
  // --- End Proposal State --- //

  // --- State for Dynamic CPE List --- //
  List<_CpeInputData> _cpeItems = [];
  // --- End CPE State --- //

  @override
  void initState() {
    super.initState();
    // Initialize Entidade controllers
    _nifController = TextEditingController(text: widget.nif);
    _responsavelNegocioController = TextEditingController();

    // Initialize Proposta controllers
    _proposalNameController = TextEditingController();
    _solutionController = TextEditingController();
    _validityDateController = TextEditingController();
    _bundleController = TextEditingController();
    _solarInvestmentController = TextEditingController();
    _creationDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    // Initialize checkbox states
    _energiaChecked = false;
    _solarChecked = false;

    // Initialize CPE list with one default item
    _addCpeBlock(); // Add the initial block
  }

  @override
  void dispose() {
    // Dispose Entidade controllers
    _nifController.dispose();
    _responsavelNegocioController.dispose();

    // Dispose Proposta controllers
    _proposalNameController.dispose();
    _solutionController.dispose();
    _validityDateController.dispose();
    _bundleController.dispose();
    _solarInvestmentController.dispose();
    _creationDateController.dispose();

    // Dispose CPE controllers
    for (var item in _cpeItems) {
      item.dispose();
    }
    super.dispose();
  }

  // Helper widget for read-only fields to reduce repetition
  Widget _buildReadOnlyField(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        decoration: InputDecoration(
          labelText: label,
          // Uses InputDecorator theme from AppTheme
        ),
      ),
    );
  }

  // Date Picker Logic
  Future<void> _selectValidityDate(BuildContext context) async {
    final theme = Theme.of(context); // Get theme for picker styling
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedValidityDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        // Apply theme to date picker
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary, // header background color
              onPrimary: theme.colorScheme.onPrimary, // header text color
              onSurface: theme.colorScheme.onSurface, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedValidityDate) {
      setState(() {
        _selectedValidityDate = picked;
        _validityDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // --- Add/Remove CPE Block Logic --- //
  void _addCpeBlock() {
    setState(() {
      final newCpeData = _CpeInputData();
      // Pre-fill NIF in new blocks with the main NIF
      newCpeData.nifController.text = _nifController.text;
      _cpeItems.add(newCpeData);
    });
  }

  void _removeCpeBlock(int index) {
    if (_cpeItems.length > 1) {
      setState(() {
        // Dispose controllers before removing
        _cpeItems[index].dispose();
        _cpeItems.removeAt(index);
      });
    } else {
      // Optional: Show a message if trying to remove the last item
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one CPE block is required.'),
        ), // TODO: l10n
      );
    }
  }
  // --- End Add/Remove Logic --- //

  // --- File Picker Logic --- //
  Future<void> _pickFilesForCpe(int index) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type:
            FileType
                .any, // Or specify types: FileType.custom, allowedExtensions: [...]
      );

      if (result != null) {
        setState(() {
          // Add picked files to the existing list for this specific CPE block
          _cpeItems[index].attachedFiles.addAll(result.files);
        });
      } else {
        // User canceled the picker
      }
    } catch (e) {
      print("Error picking files: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking files: ${e.toString()}'),
        ), // TODO: l10n
      );
    }
  }

  void _removeFileFromCpe(int cpeIndex, int fileIndex) {
    setState(() {
      if (cpeIndex < _cpeItems.length &&
          fileIndex < _cpeItems[cpeIndex].attachedFiles.length) {
        _cpeItems[cpeIndex].attachedFiles.removeAt(fileIndex);
      }
    });
  }
  // --- End File Picker Logic --- //

  // --- Widget Builder for a single CPE Block --- //
  Widget _buildCpeInputBlock(int index, _CpeInputData cpeData) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Card(
      // Use CardTheme from AppTheme
      margin: const EdgeInsets.only(bottom: 20.0), // Increased spacing
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CPE #${index + 1}', // TODO: l10n
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_cpeItems.length > 1)
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: colorScheme.error,
                    ),
                    tooltip: 'Remove CPE #${index + 1}', // TODO: l10n
                    onPressed: () => _removeCpeBlock(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const Divider(height: 24),

            // --- CPE Fields --- //
            TextFormField(
              controller: cpeData.cpeController,
              decoration: const InputDecoration(labelText: 'CPE'), // TODO: l10n
              validator:
                  (value) =>
                      (value?.trim().isEmpty ?? true)
                          ? 'CPE is required'
                          : null, // TODO: l10n
            ),
            const SizedBox(height: 16),
            _buildReadOnlyField('Entity', widget.accountName), // TODO: l10n
            TextFormField(
              controller: cpeData.nifController,
              decoration: const InputDecoration(labelText: 'NIF'), // TODO: l10n
              validator:
                  (value) =>
                      (value?.trim().isEmpty ?? true)
                          ? 'NIF is required for CPE #${index + 1}'
                          : null, // TODO: l10n
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: cpeData.consumoController,
              decoration: const InputDecoration(
                labelText: 'Consumption or Peak Power',
              ), // TODO: l10n
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              validator:
                  (value) =>
                      (value?.trim().isEmpty ?? true)
                          ? 'Consumption/Power is required'
                          : null, // TODO: l10n
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: cpeData.fidelizacaoController,
              decoration: const InputDecoration(
                labelText: 'Loyalty Period (Fidelização)', // TODO: l10n
                hintText: 'e.g., 12 months, None', // TODO: l10n
              ),
              validator:
                  (value) =>
                      (value?.trim().isEmpty ?? true)
                          ? 'Loyalty period is required'
                          : null, // TODO: l10n
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: cpeData.cicloController,
              decoration: const InputDecoration(
                labelText: 'Activation Cycle (Ciclo)',
              ), // TODO: l10n
              validator:
                  (value) =>
                      (value?.trim().isEmpty ?? true)
                          ? 'Activation cycle is required'
                          : null, // TODO: l10n
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: cpeData.comissaoController,
              decoration: const InputDecoration(
                labelText: 'Retail Commission',
                prefixText: '€ ',
              ), // TODO: l10n
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator:
                  (value) =>
                      (value?.trim().isEmpty ?? true)
                          ? 'Retail commission is required'
                          : null, // TODO: l10n
            ),
            const SizedBox(height: 24),

            // --- File Upload Section for CPE --- //
            Text('Attached Files', style: textTheme.titleSmall), // TODO: l10n
            const SizedBox(height: 8),
            // Display selected files
            if (cpeData.attachedFiles.isNotEmpty)
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: List.generate(cpeData.attachedFiles.length, (
                  fileIndex,
                ) {
                  final file = cpeData.attachedFiles[fileIndex];
                  return Chip(
                    avatar: CircleAvatar(
                      child: Icon(Icons.insert_drive_file_outlined, size: 16),
                    ), // Generic file icon
                    label: Text(file.name, style: textTheme.bodySmall),
                    onDeleted: () => _removeFileFromCpe(index, fileIndex),
                    deleteIconColor: colorScheme.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  );
                }),
              ),

            if (cpeData.attachedFiles.isNotEmpty) const SizedBox(height: 8),
            // Add files button
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file, size: 18),
              label: const Text('Add Files'), // TODO: l10n
              onPressed: () => _pickFilesForCpe(index),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                textStyle: textTheme.labelMedium,
              ),
            ),
            // --- End File Upload --- //
          ],
        ),
      ),
    );
  }
  // --- End CPE Block Builder --- //

  @override
  Widget build(BuildContext context) {
    // final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Consistent padding value
    const double sectionSpacing = 24.0;
    const double fieldSpacing = 16.0;

    return Scaffold(
      appBar: AppBar(
        // title: Text(l10n.createProposalTitle), // Use l10n
        title: const Text('Create New Proposal'), // TODO: l10n
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 20.0,
        ), // Adjusted padding
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Entity Information Section --- //
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Entity Information',
                  style: textTheme.headlineSmall,
                ), // TODO: l10n
              ),
              _buildReadOnlyField('Entity', widget.accountName), // TODO: l10n
              TextFormField(
                controller: _nifController,
                decoration: const InputDecoration(
                  labelText: 'NIF',
                ), // TODO: l10n
                keyboardType: TextInputType.text,
                validator:
                    (value) =>
                        (value?.trim().isEmpty ?? true)
                            ? 'NIF is required'
                            : null, // TODO: l10n
              ),
              const SizedBox(height: fieldSpacing),
              _buildReadOnlyField(
                'Opportunity',
                widget.opportunityName,
              ), // TODO: l10n
              _buildReadOnlyField(
                'Retail Agent',
                widget.resellerName,
              ), // TODO: l10n
              TextFormField(
                controller: _responsavelNegocioController,
                decoration: const InputDecoration(
                  labelText: 'Retail Business Manager', // TODO: l10n
                  hintText: 'Enter manager name', // TODO: l10n
                ),
                validator: (value) => null, // Optional field
              ),
              const SizedBox(height: sectionSpacing),
              const Divider(),
              const SizedBox(height: sectionSpacing),

              // --- Proposal Information Section --- //
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Proposal Information',
                  style: textTheme.headlineSmall,
                ), // TODO: l10n
              ),
              TextFormField(
                controller: _proposalNameController,
                decoration: const InputDecoration(
                  labelText: 'Proposal Name',
                ), // TODO: l10n
                validator:
                    (value) =>
                        (value?.trim().isEmpty ?? true)
                            ? 'Proposal name is required'
                            : null, // TODO: l10n
              ),
              const SizedBox(height: fieldSpacing),
              TextFormField(
                controller: _solutionController,
                decoration: const InputDecoration(
                  labelText: 'Solution',
                ), // TODO: l10n
                validator:
                    (value) =>
                        (value?.trim().isEmpty ?? true)
                            ? 'Solution is required'
                            : null, // TODO: l10n
              ),
              const SizedBox(height: fieldSpacing),
              Row(
                // Group checkboxes
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Energia'), // TODO: l10n
                      value: _energiaChecked,
                      onChanged:
                          (v) => setState(() => _energiaChecked = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: fieldSpacing),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Solar'), // TODO: l10n
                      value: _solarChecked,
                      onChanged:
                          (v) => setState(() => _solarChecked = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: fieldSpacing),
              Row(
                // Group date fields
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _creationDateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Creation Date', // TODO: l10n
                        // Uses theme
                      ),
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: fieldSpacing),
                  Expanded(
                    child: TextFormField(
                      controller: _validityDateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Validity Date', // TODO: l10n
                        hintText: 'Select date', // TODO: l10n
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () => _selectValidityDate(context),
                      validator:
                          (value) =>
                              (value?.isEmpty ?? true)
                                  ? 'Validity date is required'
                                  : null, // TODO: l10n
                    ),
                  ),
                ],
              ),
              const SizedBox(height: fieldSpacing),
              TextFormField(
                controller: _bundleController,
                decoration: const InputDecoration(
                  labelText: 'Bundle (Optional)',
                ), // TODO: l10n
              ),
              const SizedBox(height: fieldSpacing),
              // Conditionally show Solar Investment
              if (_solarChecked)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 8.0,
                  ), // Add space when it appears
                  child: TextFormField(
                    controller: _solarInvestmentController,
                    decoration: const InputDecoration(
                      labelText: 'Solar Investment Value', // TODO: l10n
                      prefixText: '€ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    validator:
                        (value) =>
                            (_solarChecked && (value?.trim().isEmpty ?? true))
                                ? 'Investment value is required for Solar' // TODO: l10n
                                : null,
                  ),
                ),
              const SizedBox(height: sectionSpacing),
              const Divider(),
              const SizedBox(height: sectionSpacing),

              // --- Dynamic CPE Section --- //
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'CPE Details',
                  style: textTheme.headlineSmall,
                ), // TODO: l10n
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cpeItems.length,
                itemBuilder:
                    (context, index) =>
                        _buildCpeInputBlock(index, _cpeItems[index]),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add CPE'), // TODO: l10n
                  onPressed: _addCpeBlock,
                  // Style inherited from TextButtonTheme
                ),
              ),
              const SizedBox(height: sectionSpacing),
              const Divider(),
              const SizedBox(height: sectionSpacing),

              // --- Submit Button --- //
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ), // Example padding
                    textStyle: textTheme.labelLarge,
                  ),
                  onPressed: () {
                    if (_formKey.currentState?.validate() ?? false) {
                      print('Form is valid. Submitting...');
                      // --- Collect and Print Data --- //
                      final proposalData = {
                        'proposalName': _proposalNameController.text,
                        'solution': _solutionController.text,
                        'energiaChecked': _energiaChecked,
                        'creationDate': _creationDateController.text,
                        'validityDate': _validityDateController.text,
                        'bundle': _bundleController.text,
                        'solarChecked': _solarChecked,
                        'solarInvestment':
                            _solarChecked
                                ? _solarInvestmentController.text
                                : null,
                        // Include Entidade fields
                        'nif': _nifController.text,
                        'responsavelNegocio':
                            _responsavelNegocioController.text,
                      };
                      print("--- Proposal Data ---");
                      print(proposalData);

                      final cpeDataList =
                          _cpeItems.map((cpeData) {
                            return {
                              'cpe': cpeData.cpeController.text,
                              'nif': cpeData.nifController.text,
                              'consumo': cpeData.consumoController.text,
                              'fidelizacao': cpeData.fidelizacaoController.text,
                              'ciclo': cpeData.cicloController.text,
                              'comissao': cpeData.comissaoController.text,
                              'files':
                                  cpeData.attachedFiles
                                      .map((f) => f.name)
                                      .toList(), // Get file names
                            };
                          }).toList();
                      print("--- CPE Data List ---");
                      print(cpeDataList);
                      print("---------------------");
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Data collected (see console). Backend call pending.',
                          ),
                        ), // TODO: l10n
                      );
                    } else {
                      print('Form is invalid.');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please correct the errors in the form.',
                          ),
                        ), // TODO: l10n
                      );
                    }
                  },
                  child: const Text('Submit Proposal'), // TODO: l10n
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
