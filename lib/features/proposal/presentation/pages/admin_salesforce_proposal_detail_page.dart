import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For date/number formatting
import 'package:go_router/go_router.dart'; // If needed later for navigation
import 'package:file_picker/file_picker.dart'; // <-- RESTORED IMPORT

import '../providers/proposal_providers.dart'; // Provider for proposal details
import '../../data/models/detailed_salesforce_proposal.dart';
import '../../data/models/proposal_file.dart';
import '../../data/models/cpe_proposal_link.dart';
import '../../../../presentation/widgets/secure_file_viewer.dart'; // For viewing files
import '../../../../core/services/salesforce_auth_service.dart'; // For getting credentials on save
import '../widgets/add_cpe_to_proposal_dialog.dart'; // <-- ADDED IMPORT for dialog
import '../../../../presentation/widgets/full_screen_pdf_viewer.dart';
import '../../../../presentation/widgets/full_screen_image_viewer.dart';

// Convert to ConsumerStatefulWidget
class AdminSalesforceProposalDetailPage extends ConsumerStatefulWidget {
  final String proposalId;

  const AdminSalesforceProposalDetailPage({
    required this.proposalId,
    super.key,
  });

  @override
  ConsumerState<AdminSalesforceProposalDetailPage> createState() =>
      _AdminSalesforceProposalDetailPageState();
}

// Create the State class
class _AdminSalesforceProposalDetailPageState
    extends ConsumerState<AdminSalesforceProposalDetailPage> {
  bool _isEditing = false;
  bool _isSaving = false; // Add saving state flag
  DetailedSalesforceProposal? _originalProposal; // Store the original
  DetailedSalesforceProposal? _editedProposal; // Holds changes
  final Map<String, TextEditingController> _controllers = {};
  final List<PlatformFile> _filesToAdd = []; // Files picked by user
  final List<ProposalFile> _filesToDelete =
      []; // Existing files marked for deletion

  // --- Define Editable Fields (Using Model Property Names) ---
  // Based on previous plan, excluding lookups and picklists for now
  final List<String> _editableFields = [
    'name',
    'nifC',
    'responsavelNegocioRetailC',
    'responsavelNegocioExclusivoC',
    'consumoPeriodoContratoKwhC',
    'valorInvestimentoSolarC',
    // Boolean fields handled by Switches/Checkboxes directly in UI build
    // Date fields handled by Date Pickers directly in UI build
  ];

  // --- Map Model Fields to Salesforce API Names ---
  final Map<String, String> _fieldApiNameMapping = {
    'name': 'Name',
    'nifC': 'NIF__c',
    'responsavelNegocioRetailC': 'Responsavel_de_Negocio_Retail__c',
    'responsavelNegocioExclusivoC': 'Responsavel_de_Negocio_Exclusivo__c',
    'consumoPeriodoContratoKwhC': 'Consumo_para_o_per_odo_do_contrato_KWh__c',
    'energiaC': 'Energia__c',
    'solarC': 'Solar__c',
    'valorInvestimentoSolarC': 'Valor_de_Investimento_Solar__c',
    'dataValidadeC': 'Data_de_Validade__c',
    'dataInicioContratoC': 'Data_de_In_o_do_Contrato__c',
    'dataFimContratoC': 'Data_de_fim_do_Contrato__c',
    'contratoInseridoC': 'Contrato_inserido__c',
    'soluOC': 'Solu_o__c',
    'statusC': 'Status__c',
    'backOffice': 'Back_Office__c', // Added
    'faseC': 'Fase__c', // ASSUMED API Name for Fase
    'faseLDF': 'Fase_LDF__c', // ASSUMED API Name for Fase LDF
    // Add mappings for other editable fields as needed
    // Example: 'stageName': 'StageName' (Standard field)
  };

  // --- NEW: State variables for dropdowns ---
  String? _selectedSolution;
  String? _selectedStatus;
  // --- END NEW ---

  // --- NEW: Picklist Options --- //
  final List<String> _solucaoOptions = const [
    '--None--',
    'LEC',
    'PAP',
    'PP',
    'Energia',
    'Gás',
  ];

  final List<String> _statusOptions = const [
    '--None--',
    'Criação',
    'Risco Crédito Revisto',
    'A Aguardar Pricing',
    'Pricing Finalizado',
    'Enviada',
    'Em Aprovação',
    'Aprovada',
    'Não Aprovada',
    'Aceite',
    'Expirada',
    'Cancelada',
  ];
  // --- END NEW ---

  @override
  void initState() {
    super.initState();
    // Initial setup of controllers for text fields
    for (final field in _editableFields) {
      // Only create controllers for fields that use them (e.g., text, number)
      if ([
        // Add fields that use TextEditingController here
        'name',
        'nifC',
        'responsavelNegocioRetailC',
        'responsavelNegocioExclusivoC',
        'consumoPeriodoContratoKwhC',
        'valorInvestimentoSolarC',
      ].contains(field)) {
        _controllers[field] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  // --- Formatting Helpers (remain the same) ---
  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(dateTime.toLocal());
    } catch (e) {
      return dateString; // Return original if parsing fails
    }
  }

  String _formatBool(bool? value) {
    if (value == null) return 'N/A';
    return value ? 'Yes' : 'No';
  }

  String _formatCurrency(double? value) {
    if (value == null) return 'N/A';
    // TODO: Adjust locale and symbol as needed
    final format = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    return format.format(value);
  }

  String _formatNumber(double? value) {
    if (value == null) return 'N/A';
    // TODO: Adjust locale as needed
    final format = NumberFormat.decimalPattern('pt_PT');
    return format.format(value);
  }
  // --- End Formatting Helpers ---

  // --- State Initialization and Update Helpers (Adapted from Opportunity Page) ---
  void _initializeEditState(DetailedSalesforceProposal proposal) {
    _originalProposal = proposal; // Store the original for cancellation
    _editedProposal = proposal.copyWith(); // Create editable copy

    // Initialize dropdown state variables from the editable copy
    _selectedSolution = _editedProposal?.soluOC;
    _selectedStatus = _editedProposal?.statusC;

    // Initialize any text controllers if added later
    _controllers.forEach((field, controller) {
      final initialValue = _editedProposal?.toJson()[field] as String?;
      controller.text = initialValue ?? '';
      // Add listeners if needed
    });
  }

  // Update the _editedProposal state immutably
  void _updateEditedProposalField(String field, dynamic value) {
    if (!_isEditing || _editedProposal == null) return;

    setState(() {
      // Use copyWith based on field key
      switch (field) {
        case 'name':
          _editedProposal = _editedProposal!.copyWith(name: value as String);
          break;
        case 'nifC':
          _editedProposal = _editedProposal!.copyWith(nifC: value as String?);
          break;
        case 'responsavelNegocioRetailC':
          _editedProposal = _editedProposal!.copyWith(
            responsavelNegocioRetailC: value as String?,
          );
          break;
        case 'responsavelNegocioExclusivoC':
          _editedProposal = _editedProposal!.copyWith(
            responsavelNegocioExclusivoC: value as String?,
          );
          break;
        case 'consumoPeriodoContratoKwhC':
          _editedProposal = _editedProposal!.copyWith(
            consumoPeriodoContratoKwhC: _parseDouble(value),
          );
          break;
        case 'valorInvestimentoSolarC':
          _editedProposal = _editedProposal!.copyWith(
            valorInvestimentoSolarC: _parseDouble(value),
          );
          break;
        // --- Handle non-controller fields directly from UI interactions ---
        case 'energiaC':
          _editedProposal = _editedProposal!.copyWith(energiaC: value as bool?);
          break;
        case 'solarC':
          _editedProposal = _editedProposal!.copyWith(solarC: value as bool?);
          break;
        case 'contratoInseridoC':
          _editedProposal = _editedProposal!.copyWith(
            contratoInseridoC: value as bool?,
          );
          break;
        case 'dataValidadeC':
          _editedProposal = _editedProposal!.copyWith(
            dataValidadeC: value as String?,
          );
          break;
        case 'dataInicioContratoC':
          _editedProposal = _editedProposal!.copyWith(
            dataInicioContratoC: value as String?,
          );
          break;
        case 'dataFimContratoC':
          _editedProposal = _editedProposal!.copyWith(
            dataFimContratoC: value as String?,
          );
          break;
        // Add other cases as needed
      }
    });
  }

  // --- NEW: Helper to update _editedProposal state for DROPDOWN fields ---
  void _updateEditedProposalDropdownField(String field, String? value) {
    if (!_isEditing || _editedProposal == null) return;
    final valueToSave = (value == '--None--') ? null : value;

    setState(() {
      switch (field) {
        case 'soluOC':
          _selectedSolution = value;
          _editedProposal = _editedProposal!.copyWith(soluOC: valueToSave);
          break;
        case 'statusC':
          _selectedStatus = value;
          _editedProposal = _editedProposal!.copyWith(statusC: valueToSave);
          break;
      }
    });
  }
  // --- END NEW ---

  // --- ADDED: Helper to get current provider data (used in _saveEdit) ---
  DetailedSalesforceProposal? _getCurrentProviderData() {
    return ref.read(proposalDetailsProvider(widget.proposalId)).asData?.value;
  }
  // --- END ADDED Helper ---

  // --- Move helper function inside State class ---
  double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // --- Action Handlers (Placeholders for now) ---
  void _startEdit() {
    // Get the current data before entering edit mode
    final currentData =
        ref.read(proposalDetailsProvider(widget.proposalId)).asData?.value;
    if (currentData != null) {
      // Ensure copyWith and toJson are implemented in DetailedSalesforceProposal
      try {
        _initializeEditState(currentData);
        setState(() {
          _isEditing = true;
        });
      } catch (e) {
        // Likely means copyWith or toJson is not implemented yet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error entering edit mode: Model methods missing? $e',
            ),
          ),
        );
      }
    } else {
      // Handle case where data isn't loaded yet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data not loaded yet. Please wait.')),
      );
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      if (_originalProposal != null) {
        _initializeEditState(_originalProposal!); // Reset to original
      }
      // No need to re-initialize controllers from original, just clear changes
      _filesToAdd.clear();
      _filesToDelete.clear();
    });
  }

  // --- Implement Save Logic ---
  Future<void> _saveEdit() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    // Basic Validation (Example: Name cannot be empty)
    final nameController = _controllers['name'];
    if (nameController != null && nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proposal Name cannot be empty.')),
      );
      setState(() => _isSaving = false);
      return;
    }

    // Get the *current* data from the provider to compare against _editedProposal
    final DetailedSalesforceProposal? originalProposalFromProvider =
        _getCurrentProviderData();

    // Ensure we have data to compare and edited data to save
    if (originalProposalFromProvider == null || _editedProposal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Data not available to save.')),
      );
      setState(() => _isSaving = false);
      return;
    }

    // Get auth state and notifier
    final authNotifier = ref.read(salesforceAuthProvider.notifier);
    final authState = ref.read(salesforceAuthProvider);

    if (authState != SalesforceAuthState.authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Not authenticated with Salesforce.'),
        ),
      );
      setState(() => _isSaving = false);
      return;
    }

    // Get tokens via notifier
    final String? accessToken = await authNotifier.getValidAccessToken();
    final String? instanceUrl = authNotifier.currentInstanceUrl;

    if (accessToken == null || instanceUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Could not retrieve Salesforce credentials.'),
        ),
      );
      setState(() => _isSaving = false);
      return;
    }

    // Prepare data for update
    final Map<String, dynamic> fieldsToUpdate = {};
    final originalJson =
        originalProposalFromProvider.toJson(); // Use data from provider
    final editedJson =
        _editedProposal!.toJson(); // Requires toJson implementation

    // Use copies of the file lists for processing
    final List<ProposalFile> filesToDelete = List.from(_filesToDelete);
    final List<PlatformFile> filesToAdd = List.from(_filesToAdd);

    // Clear state lists immediately
    _filesToDelete.clear();
    _filesToAdd.clear();

    // Compare editable fields (Text, Numeric, Currency, Bool, Date)
    // NOTE: Requires _fieldApiNameMapping to be complete and toJson/copyWith in model
    _fieldApiNameMapping.forEach((modelFieldKey, apiName) {
      final originalValue = originalJson[modelFieldKey];
      final editedValue = editedJson[modelFieldKey];

      // Simple comparison (consider deep equality for lists/maps if needed elsewhere)
      // Handle nulls carefully - treat empty string from controller as null for comparison/update?
      final effectiveEditedValue =
          (editedValue is String && editedValue.isEmpty) ? null : editedValue;
      final effectiveOriginalValue =
          (originalValue is String && originalValue.isEmpty)
              ? null
              : originalValue;

      if (effectiveOriginalValue != effectiveEditedValue) {
        // Handle specific formatting if necessary (e.g., Date to YYYY-MM-DD)
        // For now, pass the value as obtained from the edited model\'s toJson
        fieldsToUpdate[apiName] = effectiveEditedValue;
      }
    });

    // Check if anything changed
    final bool fieldsChanged = fieldsToUpdate.isNotEmpty;
    final bool filesChanged = filesToAdd.isNotEmpty || filesToDelete.isNotEmpty;

    if (!fieldsChanged && !filesChanged) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No changes detected.')));
      setState(() {
        _isEditing = false; // Exit edit mode even if no changes
        _isSaving = false;
        _editedProposal = null; // Clear edited data
      });
      return;
    }

    // Call the repository methods (which call Cloud Functions)
    try {
      final proposalService = ref.read(salesforceProposalServiceProvider);

      // --- Process File Deletions --- //
      if (filesToDelete.isNotEmpty) {
        print("Deleting ${filesToDelete.length} files...");
        await Future.wait(
          filesToDelete.map((file) async {
            try {
              await proposalService.deleteFile(
                accessToken: accessToken,
                instanceUrl: instanceUrl,
                contentDocumentId:
                    file.id, // Use ProposalFile ID (which is ContentDocumentId)
              );
              print("Deleted file: ${file.title}");
            } catch (e) {
              print("Error deleting file ${file.title}: $e");
              // Decide how to handle partial failures - maybe re-add to list?
              // Show specific error?
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to delete file: ${file.title}'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }),
        );
      }

      // --- Process File Uploads --- //
      if (filesToAdd.isNotEmpty) {
        print("Uploading ${filesToAdd.length} files...");
        await Future.wait(
          filesToAdd.map((file) async {
            if (file.bytes == null) {
              print("Skipping upload for ${file.name}, bytes are missing.");
              return;
            }
            try {
              final contentDocId = await proposalService.uploadFile(
                accessToken: accessToken,
                instanceUrl: instanceUrl,
                parentId: widget.proposalId, // Link to this proposal
                fileName: file.name!,
                fileBytes: file.bytes!,
              );
              if (contentDocId != null) {
                print("Uploaded file: ${file.name} (ID: $contentDocId)");
              } else {
                print(
                  "Upload failed for file: ${file.name} (Service returned null)",
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to upload file: ${file.name}'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            } catch (e) {
              print("Error uploading file ${file.name}: $e");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error uploading file: ${file.name}'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }),
        );
      }

      // --- Update Proposal Fields (if changed) --- //
      if (fieldsChanged) {
        print("Updating proposal fields...");
        await proposalService.updateProposal(
          accessToken: accessToken,
          instanceUrl: instanceUrl,
          proposalId: widget.proposalId,
          fieldsToUpdate: fieldsToUpdate,
        );
        print("Proposal fields update requested.");
      } else {
        print("No proposal fields to update.");
      }

      // Handle Success (assuming partial failures were handled above)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved successfully!')),
      );

      // Refresh the data and exit edit mode
      ref.refresh(proposalDetailsProvider(widget.proposalId));
      setState(() {
        _isEditing = false;
        _editedProposal = null; // Clear the edited copy
        // The UI will now use the refreshed provider data in the next build
      });
    } catch (e) {
      // Handle Overall Error (e.g., failure in updateProposal call)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save changes: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      // Always reset saving state
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  // --- End Action Handlers ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detailsAsync = ref.watch(proposalDetailsProvider(widget.proposalId));

    return Scaffold(
      appBar: AppBar(
        title: detailsAsync.when(
          data: (proposal) => Text(proposal.name ?? 'Proposal Details'),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Proposal Details'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isEditing)
            // Save and Cancel buttons
            Row(
              children: [
                IconButton(
                  icon:
                      _isSaving
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.cancel),
                  tooltip: 'Cancel',
                  onPressed: _isSaving ? null : _cancelEdit,
                ),
                IconButton(
                  icon:
                      _isSaving
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.save),
                  tooltip: 'Save',
                  onPressed: _isSaving ? null : _saveEdit,
                ),
              ],
            )
          else
            // Edit button
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: _startEdit,
            ),
        ],
      ),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading proposal details:\n$error',
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        data: (proposalFromProvider) {
          // Initialize state when data first loads IF NOT ALREADY EDITING
          if (!_isEditing &&
              (_originalProposal == null ||
                  proposalFromProvider.id != _originalProposal!.id)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _initializeEditState(proposalFromProvider);
              }
            });
          }

          // Determine which data to display
          final DetailedSalesforceProposal displayProposal =
              (_isEditing ? _editedProposal : proposalFromProvider) ??
              proposalFromProvider; // Fallback to provider data

          // --- Build UI using displayProposal and _isEditing flag ---
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- Section 1: Informação da Entidade ---
              _buildDetailSection(context, 'Informação da Entidade', [
                _buildDetailItem(
                  'Entidade',
                  displayProposal.entidadeName ?? displayProposal.entidadeId,
                ),
                _buildDetailItem('NIF', displayProposal.nifC, fieldKey: 'nifC'),
                _buildDetailItem(
                  'Oportunidade',
                  displayProposal.oportunidadeName ??
                      displayProposal.oportunidadeId,
                ),
                _buildDetailItem(
                  'Agente Retail',
                  displayProposal.agenteRetailName ??
                      displayProposal.agenteRetailId,
                ),
                _buildDetailItem(
                  'Responsável de Negócio – Retail',
                  displayProposal.responsavelNegocioRetailC,
                  fieldKey: 'responsavelNegocioRetailC',
                ),
                _buildDetailItem(
                  'Responsável de Negócio – Exclusivo',
                  displayProposal.responsavelNegocioExclusivoC,
                  fieldKey: 'responsavelNegocioExclusivoC',
                ),
              ]),
              const SizedBox(height: 16),

              // --- Section 2: Informação da Proposta ---
              _buildDetailSection(context, 'Informação da Proposta', [
                _buildDetailItem(
                  'Proposta',
                  displayProposal.name,
                  fieldKey: 'name',
                ),
                _buildDetailItem('Status', displayProposal.statusC),
                _buildDetailItem('Solução', displayProposal.soluOC),
                _buildDetailItem(
                  'Consumo para o período do contrato (KWh)',
                  displayProposal.consumoPeriodoContratoKwhC,
                  fieldKey: 'consumoPeriodoContratoKwhC',
                  isNumeric: true,
                ),
                _buildBooleanField(
                  'Energia',
                  displayProposal.energiaC,
                  'energiaC',
                ),
                _buildBooleanField('Solar', displayProposal.solarC, 'solarC'),
                _buildDetailItem(
                  'Valor de Investimento Solar',
                  displayProposal.valorInvestimentoSolarC,
                  fieldKey: 'valorInvestimentoSolarC',
                  isCurrency: true,
                ),
                _buildDetailItem(
                  'Data de Criação da Proposta',
                  _formatDate(displayProposal.dataCriacaoPropostaC),
                ),
                _buildDateField(
                  'Data de Início do Contrato',
                  displayProposal.dataInicioContratoC,
                  'dataInicioContratoC',
                ),
                _buildDateField(
                  'Data de Validade',
                  displayProposal.dataValidadeC,
                  'dataValidadeC',
                ),
                _buildDateField(
                  'Data de Fim do Contrato',
                  displayProposal.dataFimContratoC,
                  'dataFimContratoC',
                ),
                _buildDetailItem('Bundle', displayProposal.bundleC),
                _buildBooleanField(
                  'Contrato inserido',
                  displayProposal.contratoInseridoC,
                  'contratoInseridoC',
                ),
              ]),
              const SizedBox(height: 24),

              // --- Section 3: Related CPEs ---
              _buildCpeProposalsSection(context, displayProposal.cpeLinks),
              const SizedBox(height: 24),

              // --- Section 4: Related Files ---
              _buildFilesSection(context, displayProposal.files),
            ],
          );
        },
      ),
    );
  }

  // --- UI Helper Widgets (Modified for Edit Mode) ---

  Widget _buildDetailSection(
    BuildContext context,
    String title,
    List<Widget> items,
  ) {
    final theme = Theme.of(context);
    return Card(
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
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...items,
          ],
        ),
      ),
    );
  }

  // Updated to handle edit state for text/numeric fields
  Widget _buildDetailItem(
    String label,
    dynamic value, {
    String? fieldKey,
    bool isNumeric = false,
    bool isCurrency = false,
  }) {
    final controller = fieldKey != null ? _controllers[fieldKey] : null;
    final bool isFieldActuallyEditable =
        fieldKey != null && _editableFields.contains(fieldKey);
    final bool isEditableModeAndField = _isEditing && isFieldActuallyEditable;

    String displayValue = 'N/A';
    if (value is String) {
      displayValue = value;
    } else if (isCurrency && value is num) {
      displayValue = _formatCurrency(value.toDouble());
    } else if (isNumeric && value is num) {
      displayValue = _formatNumber(value.toDouble());
    } else if (value != null) {
      displayValue = value.toString();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                isEditableModeAndField && controller != null
                    ? TextFormField(
                      controller: controller,
                      keyboardType:
                          (isNumeric || isCurrency)
                              ? TextInputType.numberWithOptions(decimal: true)
                              : TextInputType.text,
                      maxLines: 1,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.all(8.0),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (fieldKey == 'name' &&
                            (val == null || val.isEmpty)) {
                          return 'Proposal Name cannot be empty';
                        }
                        return null;
                      },
                    )
                    : Text(
                      displayValue,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
          ),
        ],
      ),
    );
  }

  // Widget for Boolean fields (Checkbox/Switch)
  Widget _buildBooleanField(String label, bool? value, String fieldKey) {
    final bool isEditableField = _isEditing;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 2.0,
      ), // Less padding for switches
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 150, // Match label width
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          isEditableField
              ? Switch(
                value:
                    _editedProposal?.toJson()[fieldKey] ??
                    false, // Get current edited value
                onChanged: (newValue) {
                  _updateEditedProposalField(fieldKey, newValue);
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )
              : Text(
                _formatBool(value),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
        ],
      ),
    );
  }

  // Widget for Date fields
  Widget _buildDateField(String label, String? value, String fieldKey) {
    final bool isEditableField = _isEditing;
    DateTime? currentDate = DateTime.tryParse(value ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _formatDate(value),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (isEditableField)
            IconButton(
              icon: const Icon(Icons.calendar_today, size: 18),
              tooltip: 'Select Date',
              onPressed: () async {
                final DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: currentDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );
                if (pickedDate != null) {
                  // Format date back to 'YYYY-MM-DD' for consistency with Salesforce
                  String formattedDate = DateFormat(
                    'yyyy-MM-dd',
                  ).format(pickedDate);
                  _updateEditedProposalField(fieldKey, formattedDate);
                }
              },
            ),
        ],
      ),
    );
  }

  // --- Files Section Builder (Modified for Edit Mode) ---
  Widget _buildFilesSection(BuildContext context, List<ProposalFile> files) {
    final theme = Theme.of(context);

    IconData getFileIcon(String? fileTypeOrExtension) {
      final type = (fileTypeOrExtension ?? '').toLowerCase();
      if (type == 'pdf') return Icons.picture_as_pdf_outlined;
      if (['png', 'jpg', 'jpeg', 'gif', 'bmp'].contains(type))
        return Icons.image_outlined;
      if (['doc', 'docx'].contains(type)) return Icons.description_outlined;
      if (['xls', 'xlsx'].contains(type)) return Icons.table_chart_outlined;
      if (['ppt', 'pptx'].contains(type)) return Icons.slideshow_outlined;
      if (type == 'zip') return Icons.folder_zip_outlined;
      return Icons.insert_drive_file_outlined;
    }

    final List<dynamic> displayedItems = [
      ...files.where((f) => !_filesToDelete.contains(f)),
      ..._filesToAdd,
    ];

    return Card(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Files', // TODO: l10n
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add File', // TODO: l10n
                    onPressed: _pickFiles,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (displayedItems.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    'No files linked to this proposal.', // TODO: l10n
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayedItems.length,
                itemBuilder: (context, index) {
                  final item = displayedItems[index];
                  IconData icon;
                  String title;
                  String subtitle = '';
                  VoidCallback? onTapAction;
                  bool isMarkedForDeletion = false;

                  if (item is ProposalFile) {
                    final file = item;
                    icon = getFileIcon(file.fileExtension ?? file.fileType);
                    title = file.title;
                    subtitle = file.fileType.toUpperCase();
                    isMarkedForDeletion = _filesToDelete.contains(file);
                    onTapAction = () {
                      if (isMarkedForDeletion) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => SecureFileViewer(
                                contentVersionId: file.contentVersionId,
                                title: file.title,
                                fileType: file.fileType,
                              ),
                          fullscreenDialog: true,
                        ),
                      );
                    };
                  } else if (item is PlatformFile) {
                    final file = item;
                    icon = getFileIcon(file.extension ?? '');
                    title = file.name;
                    subtitle = '${((file.size / 1024 * 100).round() / 100)} KB';
                    onTapAction = null;
                  } else {
                    return const SizedBox.shrink();
                  }

                  return Opacity(
                    opacity: isMarkedForDeletion ? 0.5 : 1.0,
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        icon,
                        size: 24,
                        color:
                            isMarkedForDeletion
                                ? Colors.grey
                                : theme.colorScheme.secondary,
                      ),
                      title: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style:
                            isMarkedForDeletion
                                ? const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                )
                                : null,
                      ),
                      subtitle: Text(subtitle),
                      onTap: _isEditing ? null : onTapAction,
                      trailing:
                          _isEditing
                              ? IconButton(
                                icon:
                                    item is ProposalFile
                                        ? Icon(
                                          isMarkedForDeletion
                                              ? Icons.undo
                                              : Icons.delete_outline,
                                          color:
                                              isMarkedForDeletion
                                                  ? Colors.orange
                                                  : Colors.red,
                                        )
                                        : const Icon(
                                          Icons.cancel_outlined,
                                          color: Colors.red,
                                        ),
                                tooltip:
                                    item is ProposalFile
                                        ? (isMarkedForDeletion
                                            ? 'Undo Delete'
                                            : 'Mark for Deletion')
                                        : 'Remove File',
                                onPressed: () {
                                  setState(() {
                                    if (item is ProposalFile) {
                                      if (isMarkedForDeletion) {
                                        _filesToDelete.remove(item);
                                      } else {
                                        _filesToDelete.add(item);
                                      }
                                    } else if (item is PlatformFile) {
                                      _filesToAdd.remove(item);
                                    }
                                  });
                                },
                              )
                              : null,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // --- File Picker Logic (Adapted from Opportunity Page) ---
  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.any,
      );

      // Check mounted *after* the await
      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _filesToAdd.addAll(result.files.where((file) => file.bytes != null));
        });
        if (result.files.any((file) => file.bytes == null)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Some files could not be read.')),
          );
        }
      } else {
        // Already checked mounted, safe to use context here
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File picking cancelled.')),
        );
      }
    } catch (e) {
      print("Error picking files: $e");
      // Check mounted again before showing snackbar in catch block
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking files: $e')));
      }
    }
  }

  // --- CPE Proposals Section Builder (Remains Read-Only) ---
  Widget _buildCpeProposalsSection(
    BuildContext context,
    List<CpeProposalLink> cpeLinks,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- MODIFIED: Row for Title and Add Button --- //
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Related CPE Links', // TODO: l10n
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            // --- ADDED: Add CPE Link Button --- //
            IconButton(
              icon: const Icon(Icons.add_link),
              tooltip: 'Add CPE Link', // TODO: l10n
              color: theme.colorScheme.primary,
              onPressed:
                  () => _showAddCpeDialog(
                    context,
                    cpeLinks.isNotEmpty ? cpeLinks[0] : null,
                  ), // Pass first link for potential defaults?
              // Disable if required data is missing?
              // onPressed: (proposalId != null && accountId != null && resellerId != null)
              //              ? () => _showAddCpeDialog(context)
              //              : null,
            ),
            // --- END: Add CPE Link Button --- //
          ],
        ),
        // --- END MODIFIED Row --- //
        const SizedBox(height: 12),
        if (cpeLinks.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                'No CPEs linked to this proposal.', // TODO: l10n
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: theme.dividerColor.withAlpha(25)),
            ),
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cpeLinks.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final cpeLink = cpeLinks[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.link, // Simple link icon for now
                    size: 20,
                    color: theme.colorScheme.secondary,
                  ),
                  title: Text(
                    cpeLink.cpeName ?? 'CPE Name Unavailable',
                  ), // Display CPE Name
                  subtitle: Text(
                    'ID: ${cpeLink.id}',
                  ), // Display CPE_Proposta__c ID
                  onTap: null, // No action for now
                  // Example if navigating later:
                  // onTap: () {
                  //   ScaffoldMessenger.of(context).showSnackBar(
                  //     SnackBar(content: Text('CPE detail view TBD (ID: ${cpeLink.cpeRecordId})')),
                  //   );
                  // },
                );
              },
            ),
          ),
      ],
    );
  }

  // --- ADDED: Function to show the dialog --- //
  Future<void> _showAddCpeDialog(
    BuildContext context,
    CpeProposalLink? firstLink,
  ) async {
    final currentData = _getCurrentProviderData();
    if (currentData == null ||
        currentData.entidadeId == null ||
        currentData.agenteRetailId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposal data incomplete. Cannot add CPE link.'),
        ),
      );
      return;
    }

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must explicitly cancel or submit
      builder: (BuildContext dialogContext) {
        return AddCpeToProposalDialog(
          proposalId: widget.proposalId,
          accountId: currentData.entidadeId!, // We checked for null
          resellerSalesforceId:
              currentData.agenteRetailId!, // We checked for null
          // Pass NIF from first CPE link as a potential default? Or maybe from Account?
          // defaultNif: firstLink?.nif ?? currentData.nifC,
        );
      },
    );

    // If the dialog returned true (meaning success), refresh the proposal details
    if (result == true) {
      ref.refresh(proposalDetailsProvider(widget.proposalId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CPE link added successfully. Refreshing...'),
        ), // TODO: l10n
      );
    }
  }

  // --- END: Function to show the dialog --- //
}
