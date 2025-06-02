import 'dart:io'; // For File (mobile)

import 'package:cloud_functions/cloud_functions.dart'; // <-- ADDED IMPORT
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'package:firebase_storage/firebase_storage.dart'; // For Storage
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // <-- ADDED IMPORT
import 'package:intl/intl.dart'; // For date formatting
import 'package:path/path.dart' as p; // For basename
import 'package:twogether/features/proposal/domain/salesforce_ciclo.dart'; // Import Ciclo model
import 'package:twogether/features/proposal/presentation/providers/proposal_providers.dart'; // Import provider
import 'package:twogether/features/opportunity/presentation/providers/opportunity_providers.dart'; // Import proposal provider
import 'package:flutter/cupertino.dart'; // For CupertinoIcons
import '../../../../presentation/widgets/logo.dart'; // Import LogoWidget
import '../../../../presentation/widgets/app_loading_indicator.dart'; // Import AppLoadingIndicator
import '../../../../presentation/widgets/success_dialog.dart'; // Import SuccessDialog
import '../../../../presentation/widgets/app_input_field.dart'; // Import AppInputField components
import '../../../../core/services/file_icon_service.dart'; // Import FileIconService

// --- Helper Class for CPE Input Data --- //
class _CpeInputData {
  final TextEditingController cpeController = TextEditingController();
  final TextEditingController consumoController = TextEditingController();
  final TextEditingController fidelizacaoController = TextEditingController();
  String? selectedCicloId; // NEW: Store the selected Salesforce ID
  final TextEditingController comissaoController = TextEditingController();
  List<PlatformFile> attachedFiles = []; // List to hold files for this CPE

  // Call this when removing a block to prevent memory leaks
  void dispose() {
    cpeController.dispose();
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
  final List<_CpeInputData> _cpeItems = [];
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

  // --- Add/Remove CPE Block Logic --- //
  void _addCpeBlock() {
    setState(() {
      final newCpeData = _CpeInputData();
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
        ),
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
      if (kDebugMode) {
        print("Error picking files: $e");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking files: ${e.toString()}'),
        ),
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
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

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
          'nif': widget.nif, // Use widget.nif since NIF is now read-only
          'consumo': cpeData.consumoController.text.trim(),
          'fidelizacao': cpeData.fidelizacaoController.text.trim(),
          'cicloId': cpeData.selectedCicloId,
          'comissao': cpeData.comissaoController.text.trim(),
          'fileUrls': fileUrls,
        });
      } // End of file upload loop

      // --- Get Salesforce Credentials ---
      final sfAuthNotifier = ref.read(salesforceAuthNotifierProvider.notifier);
      final accessToken = sfAuthNotifier.currentAccessToken;
      final instanceUrl = sfAuthNotifier.currentInstanceUrl;

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
        'mainNif': widget.nif, // Use widget.nif since NIF is now read-only
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
        // --- START: Invalidate Provider for Refresh ---
        ref.invalidate(
          opportunityDetailsProvider(widget.salesforceOpportunityId),
        );
        // --- END: Invalidate Provider for Refresh ---

        // Show success dialog
        if (!mounted) return;
        await showSuccessDialog(
          context: context,
          message: 'Proposta submetida com sucesso!',
          onDismissed: () {
        if (GoRouter.of(context).canPop()) {
              GoRouter.of(context).pop();
            }
          },
        );
      } else {
        // Handle failure (check for session expiry specifically)
        bool sessionExpired = result.data['sessionExpired'] == true;
        String errorMessage =
            result.data['error']?.toString() ?? 'Unknown error occurred.';

        if (sessionExpired) {
          // Handle session expiry: Show message, potentially log out
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage), // Use message from function
              backgroundColor: Colors.orange,
            ),
          );
          // Consider calling sfAuthNotifier.logout() or navigating to login
          // context.go('/login');
        } else {
          if (!mounted) return;
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
      if (!mounted) return;
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

    // Responsive: Use two columns on wide screens, one column on small screens
    final isWide = MediaQuery.of(context).size.width > 700;

    final leftColumn = <Widget>[
      AppInputField(
        controller: cpeData.cpeController,
        label: 'CPE',
        validator: (value) => (value?.trim().isEmpty ?? true) ? 'CPE é obrigatório' : null,
      ),
      const SizedBox(height: 8),
      AppInputField(
        controller: TextEditingController(text: widget.accountName),
        label: 'Entidade',
        readOnly: true,
      ),
      const SizedBox(height: 8),
      AppInputField(
        controller: cpeData.consumoController,
        label: 'Consumo ou Potência Máxima',
        keyboardType: TextInputType.number,
        validator: (value) => (value?.trim().isEmpty ?? true) ? 'Consumo/Potência é obrigatório' : null,
      ),
      const SizedBox(height: 8),
      activationCyclesAsync.when(
        data: (cycles) => AppDropdownField<String>(
          label: 'Ciclo de Ativação',
          value: cpeData.selectedCicloId,
          items: cycles.map((SalesforceCiclo ciclo) {
            return DropdownMenuItem<String>(
              value: ciclo.id,
              child: Text(ciclo.name),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              cpeData.selectedCicloId = newValue;
            });
          },
          validator: (value) => (value == null || value.isEmpty) ? 'Ciclo de ativação é obrigatório' : null,
          hint: 'Selecione o Ciclo de Ativação',
        ),
        loading: () => const SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => AppInputField(
          controller: TextEditingController(),
          label: 'Ciclo de Ativação',
          hint: 'Erro ao carregar ciclos',
          readOnly: true,
        ),
      ),
    ];

    final rightColumn = <Widget>[
      AppInputField(
        controller: TextEditingController(text: widget.nif),
        label: 'NIF',
        readOnly: true,
      ),
      const SizedBox(height: 8),
      AppInputField(
        controller: cpeData.fidelizacaoController,
        label: 'Período de Fidelização (Anos)',
        hint: 'ex: 1, 2, 0',
        keyboardType: TextInputType.number,
        validator: (value) => (value?.trim().isEmpty ?? true) ? 'Período de fidelização é obrigatório' : null,
      ),
      const SizedBox(height: 8),
      AppInputField(
        controller: cpeData.comissaoController,
        label: 'Comissão Retail',
        keyboardType: TextInputType.number,
        validator: (value) => (value?.trim().isEmpty ?? true) ? 'Comissão Retail é obrigatória' : null,
      ),
      const SizedBox(height: 8),
      // Empty space to align with left column
      const SizedBox(height: 56),
    ];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor.withAlpha(25)),
      ),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CPE #${index + 1}',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (_cpeItems.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: colorScheme.error),
                    tooltip: 'Remover CPE #${index + 1}',
                    onPressed: () => _removeCpeBlock(index),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(children: leftColumn)),
                      const SizedBox(width: 32),
                      Expanded(child: Column(children: rightColumn)),
                    ],
                  )
                : Column(
                    children: [
                      ...leftColumn,
                      ...rightColumn,
                    ],
                  ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ficheiros Anexados',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'Adicionar Ficheiros',
                  onPressed: () => _pickFilesForCpe(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (cpeData.attachedFiles.isNotEmpty)
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: List.generate(cpeData.attachedFiles.length, (fileIndex) {
                  final file = cpeData.attachedFiles[fileIndex];
                  final fileExtension = (file.extension ?? '').toLowerCase();
                  final iconAsset = FileIconService.getIconAssetPath(fileExtension);
                  Widget iconWidget = Image.asset(
                    iconAsset,
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                  );
                  
                  return Container(
                    width: 70,
                    height: 70,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withAlpha((255 * 0.7).round()),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: colorScheme.outline.withAlpha((255 * 0.1).round()),
                        width: 0.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              iconWidget,
                              const SizedBox(height: 4),
                              Text(
                                file.name,
                                style: textTheme.bodySmall?.copyWith(fontSize: 8),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: colorScheme.error,
                            tooltip: 'Remover ficheiro',
                            onPressed: () => _removeFileFromCpe(index, fileIndex),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(CupertinoIcons.chevron_left, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: LogoWidget(height: 60, darkMode: theme.brightness == Brightness.dark),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            scrolledUnderElevation: 0.0,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 32, left: 24, right: 24, bottom: 16),
                    child: Text(
                      'Criar Proposta',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        fontSize: 28,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- Section 1: Informação da Entidade ---
                              Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: theme.dividerColor.withAlpha(25)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Informação da Entidade',
                                        style: textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 20,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              children: [
                                                AppInputField(
                                                  controller: TextEditingController(text: widget.accountName),
                                                  label: 'Entidade',
                                                  readOnly: true,
                                                ),
                                                const SizedBox(height: 8),
                                                AppInputField(
                                                  controller: TextEditingController(text: widget.opportunityName),
                                                  label: 'Oportunidade',
                                                  readOnly: true,
                                                ),
                                                const SizedBox(height: 8),
                                                AppInputField(
                                                  controller: _responsavelNegocioController,
                                                  label: 'Gestor de Negócio Retail',
                                                  hint: 'Introduza o nome do gestor',
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 32),
                                          Expanded(
                                            child: Column(
                                              children: [
                                                AppInputField(
                                                  controller: TextEditingController(text: widget.nif),
                                                  label: 'NIF',
                                                  readOnly: true,
                                                ),
                                                const SizedBox(height: 8),
                                                AppInputField(
                                                  controller: TextEditingController(text: widget.resellerName),
                                                  label: 'Agente Retail',
                                                  readOnly: true,
                                                ),
                                                const SizedBox(height: 8),
                                                // Empty space for alignment
                                                const SizedBox(height: 56),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // --- Section 2: Informação da Proposta ---
                              Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: theme.dividerColor.withAlpha(25)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Informação da Proposta',
                                        style: textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 20,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              children: [
                                                AppInputField(
                                                  controller: _proposalNameController,
                                                  label: 'Nome da Proposta',
                                                  validator: (value) => (value?.trim().isEmpty ?? true) ? 'Nome da Proposta é obrigatório' : null,
                                                ),
                                                const SizedBox(height: 8),
                                                AppDropdownField<String>(
                                                  label: 'Solução',
                                                  value: _selectedSolution,
                                                  items: _solucaoOptions.map((String value) {
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
                                                  validator: (value) {
                                                    if (value == null || value == '--None--') {
                                                      return 'Solução é obrigatória';
                                                    }
                                                    return null;
                                                  },
                                                  hint: 'Selecione uma solução',
                                                ),
                                                const SizedBox(height: 16),
                                                AppInputField(
                                                  controller: _creationDateController,
                                                  label: 'Data de Criação',
                                                  readOnly: true,
                                                ),
                                                const SizedBox(height: 8),
                                                AppInputField(
                                                  controller: _bundleController,
                                                  label: 'Bundle (Opcional)',
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 32),
                                          Expanded(
                                            child: Column(
                                              children: [
                                                AppDateInputField(
                                                  label: 'Data de Validade',
                                                  value: _selectedValidityDate,
                                                  onChanged: (DateTime? newDate) {
                                                    setState(() {
                                                      _selectedValidityDate = newDate;
                                                      _validityDateController.text = newDate != null 
                                                          ? DateFormat('yyyy-MM-dd').format(newDate)
                                                          : '';
                                                    });
                                                  },
                                                  validator: (value) => (value == null) ? 'Data de Validade é obrigatória' : null,
                                                  firstDate: DateTime.now(),
                                                  lastDate: DateTime(2101),
                                                  hint: 'Selecione a data de validade',
                                                ),
                                                const SizedBox(height: 8),
                                                if (_solarChecked)
                                                  AppInputField(
                                                    controller: _solarInvestmentController,
                                                    label: 'Valor de Investimento Solar',
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    validator: (value) => (_solarChecked && (value?.trim().isEmpty ?? true)) ? 'Valor de investimento é obrigatório para Solar' : null,
                                                  )
                                                else
                                                  const SizedBox(height: 56),
                                                const SizedBox(height: 8),
                                                // Empty space for alignment
                                                const SizedBox(height: 56),
                                                const SizedBox(height: 8),
                                                // Empty space for alignment
                                                const SizedBox(height: 56),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Checkboxes at the bottom
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Checkbox(
                                            value: _energiaChecked,
                                            onChanged: (v) => setState(() => _energiaChecked = v ?? false),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('Energia', style: theme.textTheme.bodySmall),
                                          const SizedBox(width: 24),
                                          Checkbox(
                                            value: _solarChecked,
                                            onChanged: (v) => setState(() => _solarChecked = v ?? false),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('Solar', style: theme.textTheme.bodySmall),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // --- Section 3: CPE Details ---
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Detalhes CPE',
                                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 24),
                                    tooltip: 'Adicionar CPE',
                                    onPressed: _addCpeBlock,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _cpeItems.length,
                                itemBuilder: (context, index) => _buildCpeInputBlock(index, _cpeItems[index]),
                              ),
                              const SizedBox(height: 24),
                              Center(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                                    textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 2,
                                  ),
                                  onPressed: _isSubmitting ? null : _uploadFilesAndSubmit,
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Submeter Proposta'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isSubmitting)
          const Positioned.fill(
            child: AppLoadingIndicator(),
          ),
      ],
    );
  }
}
