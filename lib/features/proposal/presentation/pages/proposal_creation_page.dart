import 'dart:io'; // For File (mobile)
import 'dart:convert'; // For jsonEncode debug logging

import 'package:cloud_functions/cloud_functions.dart'; // <-- ADDED IMPORT
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'package:firebase_auth/firebase_auth.dart'; // For UID
import 'package:firebase_storage/firebase_storage.dart'; // For Storage
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // <-- ADDED IMPORT
import 'package:intl/intl.dart'; // For date formatting
import 'package:path/path.dart' as p; // For basename
import 'package:twogether/core/services/salesforce_auth_service.dart'; // For notifier provider
import 'package:twogether/features/proposal/domain/salesforce_ciclo.dart'; // Import Ciclo model
import 'package:twogether/features/proposal/presentation/providers/proposal_providers.dart'; // Import provider
import 'package:twogether/features/opportunity/presentation/providers/opportunity_providers.dart'; // Import proposal provider
// import 'package:twogether/l10n/l10n.dart'; // TODO: Re-enable l10n
// import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // TODO: Re-enable l10n

// --- Helper Class for CPE Input Data --- //
class _CpeInputData {
  final TextEditingController cpeController = TextEditingController();
  final TextEditingController nifController = TextEditingController();
  final TextEditingController consumoController = TextEditingController();
  final TextEditingController fidelizacaoController = TextEditingController();
  String? selectedCicloId; // NEW: Store the selected Salesforce ID
  final TextEditingController comissaoController = TextEditingController();
  List<PlatformFile> attachedFiles = []; // List to hold files for this CPE

  // Call this when removing a block to prevent memory leaks
  void dispose() {
    cpeController.dispose();
    nifController.dispose();
    consumoController.dispose();
    fidelizacaoController.dispose();
    comissaoController.dispose();
    // selectedCicloId doesn't need disposal
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
  bool _isSubmitting = false; // Add state variable for loading indicator

  // --- Controllers for Informação da Entidade --- //
  late TextEditingController _nifController;
  late TextEditingController _responsavelNegocioController;

  // --- Controllers & State for Informação da Proposta --- //
  late TextEditingController _proposalNameController;
  late TextEditingController _validityDateController;
  late TextEditingController _bundleController;
  late TextEditingController _solarInvestmentController;
  late TextEditingController _creationDateController; // For read-only display

  // --- NEW: State for Solution Dropdown ---
  String? _selectedSolution;
  // --- END NEW ---

  bool _energiaChecked = false;
  bool _solarChecked = false;
  DateTime? _selectedValidityDate;
  // --- End Proposal State ---

  // --- State for Dynamic CPE List --- //
  List<_CpeInputData> _cpeItems = [];
  // --- End CPE State --- //

  // --- NEW: Picklist Options for Solution ---
  final List<String> _solucaoOptions = const [
    '--None--',
    'LEC',
    'PAP',
    'PP',
    'Energia',
    'Gás',
  ];
  // --- END NEW ---

  @override
  void initState() {
    super.initState();
    // Initialize Entidade controllers
    _nifController = TextEditingController(text: widget.nif);
    _responsavelNegocioController = TextEditingController();

    // Initialize Proposta controllers
    _proposalNameController = TextEditingController();
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
        type: FileType.any,
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

  // --- NEW File Upload Helper ---
  Future<String> _uploadFile(PlatformFile file, String storagePath) async {
    final storageRef = FirebaseStorage.instance.ref(storagePath);
    UploadTask uploadTask;

    if (kIsWeb) {
      // Web uses bytes directly
      if (file.bytes == null) {
        // This might happen if file picker on web fails to read bytes, though unlikely with default picker
        throw Exception('File bytes are null on web for ${file.name}');
      }
      uploadTask = storageRef.putData(
        file.bytes!,
        // Optional: Set content type based on extension for better handling
        // You might need a function to map extension to MIME type
        // SettableMetadata(contentType: _getMimeType(file.extension)),
      );
    } else {
      // Mobile uses file path
      if (file.path == null) {
        throw Exception('File path is null on mobile for ${file.name}');
      }
      uploadTask = storageRef.putFile(File(file.path!));
    }

    // Await completion and get URL
    final snapshot = await uploadTask.whenComplete(() => {});
    final downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  // --- NEW Submit Logic with File Upload & Function Call ---
  Future<void> _uploadFilesAndSubmit() async {
    if (_isSubmitting) return; // Prevent double submission

    // Validate form first
    if (!(_formKey.currentState?.validate() ?? false)) {
      if (kDebugMode) {
        print('Form is invalid.');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the errors in the form.'), // TODO: l10n
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Submitting Proposal...')), // TODO: l10n
    );

    // --- Get Salesforce Credentials ---
    final sfAuthNotifier = ref.read(salesforceAuthNotifierProvider.notifier);
    final accessToken = sfAuthNotifier.currentAccessToken;
    final instanceUrl = sfAuthNotifier.currentInstanceUrl;
    final authState = ref.read(salesforceAuthNotifierProvider);

    if (authState != SalesforceAuthState.authenticated ||
        accessToken == null ||
        instanceUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Salesforce authentication error. Please log out and back in.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSubmitting = false;
      });
      return;
    }
    // --- End Get Credentials ---

    try {
      final String opportunityId = widget.salesforceOpportunityId;

      // Map to store CPE data with file URLs
      List<Map<String, dynamic>> processedCpeDataList = [];

      // Upload files for each CPE item
      for (int i = 0; i < _cpeItems.length; i++) {
        final cpeData = _cpeItems[i];
        List<String> fileUrls = [];
        final String cpeBasePath = 'proposals/$opportunityId/$i';

        for (final file in cpeData.attachedFiles) {
          try {
            final String safeFileName = p
                .basename(file.name)
                .replaceAll(RegExp(r'[^\w\.-]+'), '_');
            final String storagePath = '$cpeBasePath/$safeFileName';
            if (kDebugMode) print("Uploading ${file.name} to $storagePath...");
            final downloadUrl = await _uploadFile(file, storagePath);
            fileUrls.add(downloadUrl);
            if (kDebugMode) print("Upload success: $downloadUrl");
          } catch (e) {
            if (kDebugMode) print("Error uploading file ${file.name}: $e");
            throw Exception(
              "Failed to upload file: ${file.name}. Please try again.",
            );
          }
        }

        processedCpeDataList.add({
          'cpe': cpeData.cpeController.text.trim(),
          'nif': cpeData.nifController.text.trim(),
          'consumo': cpeData.consumoController.text.trim(),
          'fidelizacao': cpeData.fidelizacaoController.text.trim(),
          'cicloId': cpeData.selectedCicloId,
          'comissao': cpeData.comissaoController.text.trim(),
          'fileUrls': fileUrls,
        });
      } // End of file upload loop

      // --- Collect Proposal Data --- //
      final proposalPayload = {
        // Credentials
        'accessToken': accessToken,
        'instanceUrl': instanceUrl,
        // Linking IDs
        'salesforceOpportunityId': widget.salesforceOpportunityId,
        'salesforceAccountId': widget.salesforceAccountId,
        'resellerSalesforceId': widget.resellerSalesforceId,
        // Proposal Fields
        'proposalName': _proposalNameController.text.trim(),
        'solution':
            (_selectedSolution == '--None--') ? null : _selectedSolution,
        'energiaChecked': _energiaChecked,
        'validityDate': _validityDateController.text,
        'bundle':
            _bundleController.text.trim().isEmpty
                ? null
                : _bundleController.text.trim(),
        'solarChecked': _solarChecked,
        'solarInvestment':
            _solarChecked ? _solarInvestmentController.text.trim() : null,
        'mainNif': _nifController.text.trim(),
        'responsavelNegocio':
            _responsavelNegocioController.text.trim().isEmpty
                ? null
                : _responsavelNegocioController.text.trim(),
        // CPE Items
        'cpeItems': processedCpeDataList,
      };

      if (kDebugMode) {
        print("--- Uploads Complete. Calling Cloud Function... ---");
        // Avoid logging full payload which might contain sensitive info like tokens
        // print("Payload: ${jsonEncode(proposalPayload)}");
      }

      // --- Call Cloud Function ---
      final functions = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ); // Use correct region
      final callable = functions.httpsCallable('createSalesforceProposal');
      final result = await callable.call<Map<String, dynamic>>(proposalPayload);

      if (kDebugMode) {
        print("Cloud Function Result: ${result.data}");
      }

      // --- Process Result ---
      if (result.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Proposal created successfully! ID: ${result.data['proposalId']}',
            ),
          ), // TODO: l10n
        );

        // --- START: Invalidate Provider for Refresh ---
        // Invalidate the provider that holds the data for the opportunity detail page
        // This assumes the user returns to the opportunity detail page.
        ref.invalidate(
          opportunityDetailsProvider(widget.salesforceOpportunityId),
        );
        // --- END: Invalidate Provider for Refresh ---

        // Navigate back using GoRouter
        if (GoRouter.of(context).canPop()) {
          // <-- Use GoRouter
          GoRouter.of(context).pop(); // <-- Pops the current page
        } else {
          // Handle case where it can't pop (e.g., deep link) - maybe go home?
          // context.go('/home'); // Example using GoRouter
          if (kDebugMode) {
            print("Cannot pop, maybe navigated directly?");
          }
        }
      } else {
        // Handle failure (check for session expiry specifically)
        bool sessionExpired = result.data['sessionExpired'] == true;
        String errorMessage =
            result.data['error']?.toString() ?? 'Unknown error occurred.';

        if (sessionExpired) {
          // Handle session expiry: Show message, potentially log out
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage), // Use message from function
              backgroundColor: Colors.orange,
            ),
          );
          // Consider calling sfAuthNotifier.logout() or navigating to login
          // context.go('/login');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting proposal: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (kDebugMode) {
          print("Error during submission process: $errorMessage");
        }
      }
    } catch (e) {
      // Catch errors from file upload or function call
      String errorMessage =
          (e is FirebaseFunctionsException)
              ? (e.message ?? e.code)
              : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during submission process: $errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
      if (kDebugMode) {
        print("Error during submission process: $errorMessage");
        if (e is FirebaseFunctionsException) {
          print("Function Error Code: ${e.code}");
          print("Function Error Details: ${e.details}");
        }
      }
    } finally {
      // Ensure loading indicator is turned off
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // --- Widget Builder for a single CPE Block --- //
  Widget _buildCpeInputBlock(int index, _CpeInputData cpeData) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final activationCyclesAsync = ref.watch(
      activationCyclesProvider,
    ); // Watch provider

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
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^[0-9]*[\.,]?[0-9]*$'),
                ),
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
                labelText: 'Loyalty Period (Years)', // Changed Label TODO: l10n
                hintText: 'e.g., 1, 2, 0', // Changed Hint TODO: l10n
              ),
              keyboardType: TextInputType.number, // Changed to number
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ], // Allow only digits
              validator:
                  (value) =>
                      (value?.trim().isEmpty ?? true)
                          ? 'Loyalty period (years) is required' // Changed message TODO: l10n
                          : null,
            ),
            const SizedBox(height: 16),
            // --- Activation Cycle Dropdown ---
            activationCyclesAsync.when(
              data:
                  (cycles) => DropdownButtonFormField<String>(
                    value: cpeData.selectedCicloId,
                    hint: const Text('Select Activation Cycle'), // TODO: l10n
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Activation Cycle', // TODO: l10n
                      border: OutlineInputBorder(), // Consistent styling
                    ),
                    items:
                        cycles.map((SalesforceCiclo ciclo) {
                          return DropdownMenuItem<String>(
                            value: ciclo.id,
                            child: Text(ciclo.name),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      // Update the state for THIS specific CPE block
                      setState(() {
                        cpeData.selectedCicloId = newValue;
                      });
                    },
                    validator:
                        (value) =>
                            (value == null || value.isEmpty)
                                ? 'Activation cycle is required'
                                : null, // TODO: l10n
                  ),
              loading:
                  () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error:
                  (err, stack) => TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Activation Cycle', // TODO: l10n
                      hintText: 'Error loading cycles', // TODO: l10n
                      errorText: err.toString(),
                      border: const OutlineInputBorder(),
                      // Style error state maybe?
                      // errorStyle: TextStyle(color: colorScheme.error),
                    ),
                  ),
            ),
            // --- End Activation Cycle ---
            const SizedBox(height: 16),
            TextFormField(
              controller: cpeData.comissaoController,
              decoration: const InputDecoration(
                labelText: 'Retail Commission',
                prefixText: '€ ',
              ), // TODO: l10n
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^[0-9]*[\.,]?[0-9]{0,2}$'),
                ),
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
    // final l10n = AppLocalizations.of(context)!; // TODO: Re-enable l10n
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
              DropdownButtonFormField<String>(
                value: _selectedSolution,
                items:
                    _solucaoOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedSolution = newValue;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Solution', // TODO: l10n
                ),
                validator: (value) {
                  if (value == null || value == '--None--') {
                    return 'Solution is required'; // TODO: l10n
                  }
                  return null;
                },
                hint: const Text('Select a solution'), // TODO: l10n
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
                    top: fieldSpacing, // Use consistent spacing
                  ),
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
                        // Allow numbers, optional dot/comma, up to 2 decimals
                        RegExp(r'^[0-9]*[\.,]?[0-9]{0,2}$'),
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
                  onPressed:
                      _isSubmitting
                          ? null
                          : _uploadFilesAndSubmit, // Disable while submitting
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('Submit Proposal'), // TODO: l10n
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
