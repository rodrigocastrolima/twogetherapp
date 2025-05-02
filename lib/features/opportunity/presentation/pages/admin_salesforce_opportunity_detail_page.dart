import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For potential date formatting
import 'package:go_router/go_router.dart'; // Import GoRouter
import 'package:file_picker/file_picker.dart'; // Ensure file_picker is imported
// TODO: Add import for file_picker if needed later
// import 'package:file_picker/file_picker.dart';

import '../../data/models/detailed_salesforce_opportunity.dart';
import '../../data/models/salesforce_proposal.dart';
import '../../data/models/salesforce_file.dart'; // <-- Import SalesforceFile
import '../providers/opportunity_providers.dart';
import '../../../../presentation/widgets/full_screen_pdf_viewer.dart'; // Correct Relative Path
import '../../../../presentation/widgets/full_screen_image_viewer.dart'; // Correct Relative Path
import '../../../../core/services/salesforce_auth_service.dart'; // Import the service which defines the provider
import '../../../../presentation/widgets/secure_file_viewer.dart'; // Import SecureFileViewer

// Convert to ConsumerStatefulWidget
class AdminSalesforceOpportunityDetailPage extends ConsumerStatefulWidget {
  final String opportunityId;

  const AdminSalesforceOpportunityDetailPage({
    required this.opportunityId,
    super.key,
  });

  @override
  ConsumerState<AdminSalesforceOpportunityDetailPage> createState() =>
      _AdminSalesforceOpportunityDetailPageState();
}

// Create the State class
class _AdminSalesforceOpportunityDetailPageState
    extends ConsumerState<AdminSalesforceOpportunityDetailPage> {
  bool _isEditing = false;
  bool _isSaving = false; // Add saving state flag
  DetailedSalesforceOpportunity? _originalOpportunity; // Store the original
  DetailedSalesforceOpportunity? _editedOpportunity; // Holds changes
  final Map<String, TextEditingController> _controllers = {};
  // --- Add File State Variables ---
  final List<PlatformFile> _filesToAdd = []; // Files picked by user
  final List<SalesforceFile> _filesToDelete =
      []; // Existing files marked for deletion
  // --- End File State Variables ---

  // --- NEW: State variables for dropdowns ---
  String? _selectedFaseC;
  String? _selectedFaseLDF;
  // --- END NEW ---

  // List of editable TEXT fields (using model property names) - REMOVED faseC and faseLDF
  final List<String> _editableTextFields = [
    'name',
    // 'accountName', // Let's assume this comes from the Account and isn't directly editable here
    'observacoes',
    'motivoDaPerda',
    'segmentoDeClienteC',
    'soluOC',
    'nifC',
    'backOffice',
    // Add other simple text fields as needed
  ];

  // --- ADDED: Field Mapping --- //
  // Map model field names to Salesforce API names
  final Map<String, String> _fieldApiNameMapping = {
    'name': 'Name', // Standard field
    'observacoes': 'Observa_es__c', // Corrected API Name
    'motivoDaPerda': 'Motivo_da_Perda__c', // Custom field
    'segmentoDeClienteC': 'Segmento_de_Cliente__c', // Custom field
    'soluOC': 'Solu_o__c', // Custom field
    'nifC': 'NIF__c', // Added
    'backOffice': 'Back_Office__c', // Added
    'faseC': 'Fase__c', // ASSUMED API Name for Fase
    'faseLDF': 'Fase_LDF__c', // ASSUMED API Name for Fase LDF
    // Add mappings for other editable fields as needed
    // Example: 'stageName': 'StageName' (Standard field)
  };
  // --- END: Field Mapping --- //

  // --- NEW: Picklist Options ---
  final List<String> _faseOptions = const [
    '--None--',
    'Outro Agente',
    '0 - Oportunidade Identificada',
    '1 - Cliente Contactado',
    '2 - Visita Marcada',
    '3 - Oportunidade Qualificada',
    '4 - Proposta Apresentada',
    '5 - Negociação Final',
    '6 - Conclusão Ganho',
    '6 - Conclusão Perdido Futuro',
    '6 - Conclusão Desistência Cliente',
  ];

  final List<String> _faseLdfOptions = const [
    '--None--',
    'Oportunidade Identificada',
    'Contacto',
    'Reunião',
    'Proposta',
    'Fecho',
  ];
  // --- END NEW ---

  @override
  void initState() {
    super.initState();
    // Initial setup of TEXT controllers - they will be updated with data when it loads
    for (final field in _editableTextFields) {
      _controllers[field] = TextEditingController();
    }
  }

  @override
  void dispose() {
    // Dispose all text controllers
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  // Helper to initialize or update controllers and the edited copy
  // Also manages listeners and dropdown state
  void _initializeEditState(DetailedSalesforceOpportunity opportunity) {
    _originalOpportunity = opportunity; // Store the original for cancellation
    _editedOpportunity = opportunity.copyWith();

    // Initialize dropdown state variables
    _selectedFaseC = _editedOpportunity?.faseC;
    _selectedFaseLDF = _editedOpportunity?.faseLDF;

    // Update TEXT controllers with current values and add listeners
    _controllers.forEach((field, controller) {
      final initialValue = _editedOpportunity?.toJson()[field] as String?;
      controller.text = initialValue ?? ''; // Set text, default to empty string

      // Listener function to update the state
      void listener() {
        final currentValue =
            _editedOpportunity?.toJson()[field] as String? ?? '';
        if (_isEditing && controller.text != currentValue) {
          _updateEditedOpportunityTextField(field, controller.text);
        }
      }

      // Remove any existing listener first
      try {
        controller.removeListener(listener);
      } catch (_) {
        /* Ignore */
      }

      // Add the listener
      controller.addListener(listener);
    });
  }

  // Separate helper to update the _editedOpportunity state for TEXT fields
  // Called by controller listeners
  void _updateEditedOpportunityTextField(String field, String value) {
    if (!_isEditing || _editedOpportunity == null) return;
    setState(() {
      switch (field) {
        case 'name':
          _editedOpportunity = _editedOpportunity!.copyWith(name: value);
          break;
        case 'observacoes':
          _editedOpportunity = _editedOpportunity!.copyWith(observacoes: value);
          break;
        case 'motivoDaPerda':
          _editedOpportunity = _editedOpportunity!.copyWith(
            motivoDaPerda: value,
          );
          break;
        case 'segmentoDeClienteC':
          _editedOpportunity = _editedOpportunity!.copyWith(
            segmentoDeClienteC: value,
          );
          break;
        case 'soluOC':
          _editedOpportunity = _editedOpportunity!.copyWith(soluOC: value);
          break;
        case 'nifC':
          _editedOpportunity = _editedOpportunity!.copyWith(nifC: value);
          break;
        case 'backOffice':
          _editedOpportunity = _editedOpportunity!.copyWith(backOffice: value);
          break;
        // Add cases for other editable TEXT fields
      }
    });
  }

  // --- NEW: Helper to update _editedOpportunity state for DROPDOWN fields ---
  void _updateEditedOpportunityDropdownField(String field, String? value) {
    if (!_isEditing || _editedOpportunity == null) return;
    // Handle '--None--' selection -> should be saved as null in Salesforce
    final valueToSave = (value == '--None--') ? null : value;

    setState(() {
      switch (field) {
        case 'faseC':
          // Update the state variable for the dropdown UI
          _selectedFaseC = value;
          // Update the model copy that will be saved
          _editedOpportunity = _editedOpportunity!.copyWith(faseC: valueToSave);
          break;
        case 'faseLDF':
          _selectedFaseLDF = value;
          _editedOpportunity = _editedOpportunity!.copyWith(
            faseLDF: valueToSave,
          );
          break;
        // Add cases for other dropdown fields if needed
      }
    });
  }
  // --- END NEW ---

  // Keep helper methods within the State class
  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(dateTime.toLocal());
    } catch (e) {
      return dateString; // Return original string if parsing fails
    }
  }

  // Helper to format boolean
  String _formatBool(bool? value) {
    if (value == null) return 'N/A';
    return value ? 'Yes' : 'No';
  }

  // --- ADDED: Red Flag Indicator Helper ---
  Widget _buildRedFlagIndicator(String? redFlagHtml) {
    Color indicatorColor = Colors.grey.shade400; // Default color

    if (redFlagHtml != null && redFlagHtml.isNotEmpty) {
      final RegExp regex = RegExp(r'color_([a-zA-Z]+)\\.gif');
      final match = regex.firstMatch(redFlagHtml);
      if (match != null && match.groupCount >= 1) {
        final colorName = match.group(1)?.toLowerCase();
        switch (colorName) {
          case 'green':
            indicatorColor = Colors.green.shade600;
            break;
          case 'red':
            indicatorColor = Colors.red.shade600;
            break;
          case 'yellow': // Assuming yellow might exist
            indicatorColor = Colors.amber.shade600;
            break;
        }
      }
    }

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: indicatorColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black54, width: 0.5),
      ),
    );
  }

  // --- ADDED: Navigation Helper --- //
  void _navigateToCreateProposal(
    BuildContext context,
    DetailedSalesforceOpportunity opp,
  ) {
    if (opp.accountId == null ||
        opp.resellerSalesforceId == null ||
        opp.nifC == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing required data to create a proposal.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    context.push(
      '/proposal/create',
      extra: {
        'salesforceOpportunityId': opp.id,
        'salesforceAccountId': opp.accountId,
        'accountName': opp.accountName ?? 'N/A',
        'resellerSalesforceId': opp.resellerSalesforceId,
        'resellerName': opp.resellerName ?? 'N/A',
        'nif': opp.nifC,
        'opportunityName': opp.name,
      },
    );
  }

  // --- ADDED: Cancel Edit --- //
  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      // Restore original data and update controllers/dropdown state
      if (_originalOpportunity != null) {
        _initializeEditState(_originalOpportunity!); // Reset to original
      }
      // --- Clear file changes ---
      _filesToAdd.clear();
      _filesToDelete.clear();
      // --- End Clear file changes ---
    });
  }

  // --- ADDED: Save Edit --- //
  Future<void> _saveEdit() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    if (_originalOpportunity == null || _editedOpportunity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Data not available to save.')),
      );
      setState(() => _isSaving = false);
      return;
    }

    final authNotifier = ref.read(salesforceAuthProvider.notifier);
    final authState = ref.read(salesforceAuthProvider);

    if (authState != SalesforceAuthState.authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Not authenticated.')),
      );
      setState(() => _isSaving = false);
      return;
    }

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

    // --- Prepare data for update --- //
    final Map<String, dynamic> fieldsToUpdate = {};
    final originalJson = _originalOpportunity!.toJson();
    final editedJson = _editedOpportunity!.toJson();
    final List<SalesforceFile> filesToDelete = List.from(_filesToDelete);
    final List<PlatformFile> filesToAdd = List.from(_filesToAdd);

    // Clear the state lists immediately
    _filesToDelete.clear();
    _filesToAdd.clear();

    // Compare editable TEXT fields
    for (final fieldKey in _editableTextFields) {
      final apiName = _fieldApiNameMapping[fieldKey];
      if (apiName == null) {
        print("Warning: No API name mapping found for field '$fieldKey'");
        continue;
      }

      final originalValue = originalJson[fieldKey];
      final editedValue = editedJson[fieldKey];
      final effectiveEditedValue =
          (editedValue is String && editedValue.isEmpty) ? null : editedValue;

      if (originalValue != effectiveEditedValue) {
        if (apiName == 'Name' && effectiveEditedValue == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opportunity Name cannot be empty.')),
          );
          setState(() => _isSaving = false);
          return;
        }
        fieldsToUpdate[apiName] = effectiveEditedValue;
      }
    }

    // --- NEW: Compare editable DROPDOWN fields ---
    // Fase__c
    final originalFaseC = _originalOpportunity!.faseC;
    final editedFaseC =
        _editedOpportunity!.faseC; // Already handles '--None--' to null
    final faseCApiName = _fieldApiNameMapping['faseC'];
    if (faseCApiName != null && originalFaseC != editedFaseC) {
      fieldsToUpdate[faseCApiName] =
          editedFaseC; // Add null or the selected value
    }

    // Fase_LDF__c
    final originalFaseLDF = _originalOpportunity!.faseLDF;
    final editedFaseLDF =
        _editedOpportunity!.faseLDF; // Already handles '--None--' to null
    final faseLdfApiName = _fieldApiNameMapping['faseLDF'];
    if (faseLdfApiName != null && originalFaseLDF != editedFaseLDF) {
      fieldsToUpdate[faseLdfApiName] =
          editedFaseLDF; // Add null or the selected value
    }
    // --- END NEW ---

    // --- Check if anything changed --- //
    final bool filesChanged = filesToAdd.isNotEmpty || filesToDelete.isNotEmpty;
    if (fieldsToUpdate.isEmpty && !filesChanged) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No changes detected.')));
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      return;
    }

    // --- Call the service --- //
    try {
      final opportunityService = ref.read(salesforceOpportunityServiceProvider);

      // --- Process File Deletions --- //
      if (filesToDelete.isNotEmpty) {
        print("Deleting ${filesToDelete.length} files...");
        await Future.wait(
          filesToDelete.map((file) async {
            try {
              await opportunityService.deleteFile(
                accessToken: accessToken,
                instanceUrl: instanceUrl,
                contentDocumentId: file.id,
              );
              print("Deleted file: ${file.title}");
            } catch (e) {
              print("Error deleting file ${file.title}: $e");
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
              final contentDocId = await opportunityService.uploadFile(
                accessToken: accessToken,
                instanceUrl: instanceUrl,
                parentId: widget.opportunityId,
                fileName: file.name,
                fileBytes: file.bytes!,
              );
              if (contentDocId != null) {
                print("Uploaded file: ${file.name} (ID: $contentDocId)");
              } else {
                print(
                  "Upload failed for file: ${file.name} (Service returned null)",
                );
              }
            } catch (e) {
              print("Error uploading file ${file.name}: $e");
            }
          }),
        );
      }

      // --- Update Opportunity Fields (if changed) --- //
      if (fieldsToUpdate.isNotEmpty) {
        print(
          "Updating opportunity fields: $fieldsToUpdate",
        ); // Log fields being updated
        await opportunityService.updateOpportunity(
          accessToken: accessToken,
          instanceUrl: instanceUrl,
          opportunityId: widget.opportunityId,
          fieldsToUpdate: fieldsToUpdate,
        );
        print("Opportunity fields updated.");
      } else {
        print("No opportunity fields to update.");
      }

      // --- Handle Success --- //
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved successfully!')),
      );

      // Refresh the data and exit edit mode
      ref.refresh(opportunityDetailsProvider(widget.opportunityId));
      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      // --- Handle Error --- //
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update opportunity: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      // --- Always reset saving state --- //
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detailsAsync = ref.watch(
      opportunityDetailsProvider(widget.opportunityId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Opportunity' : 'Opportunity Details'),
        actions: [
          if (_isEditing) ...[
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
          ] else ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: () {
                final currentData =
                    ref
                        .read(opportunityDetailsProvider(widget.opportunityId))
                        .asData
                        ?.value;
                if (currentData != null) {
                  _initializeEditState(currentData);
                  setState(() => _isEditing = true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Data not loaded yet. Please wait.'),
                    ),
                  );
                }
              },
            ),
          ],
        ],
      ),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading details: \\n$error',
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        data: (opportunityDetails) {
          // Initialize state when data first loads or if it changes
          // Avoid re-initializing if already editing
          if (!_isEditing &&
              (_originalOpportunity == null ||
                  opportunityDetails.id != _originalOpportunity!.id)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _initializeEditState(opportunityDetails);
                // Force a rebuild if needed after state init (might not be necessary)
                if (_isEditing) setState(() {});
              }
            });
          }

          final DetailedSalesforceOpportunity displayOpportunity =
              (_isEditing ? _editedOpportunity : opportunityDetails) ??
              opportunityDetails;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- Section 1: Informação da Oportunidade ---
              _buildDetailSection(context, 'Informação da Oportunidade', [
                _buildDetailItem(
                  'Oportunidade',
                  displayOpportunity.name,
                  'name',
                ),
                _buildDetailItem('Entidade', displayOpportunity.accountName),
                _buildDetailItem(
                  'Nome Entidade',
                  displayOpportunity.accountName,
                ),
                _buildDetailItem('Owner', displayOpportunity.ownerName),
                _buildDetailItem(
                  'Tipo de Oportunidade',
                  displayOpportunity.tipoDeOportunidadeC,
                ),
                _buildDetailItem(
                  'Observações',
                  displayOpportunity.observacoes,
                  'observacoes',
                  _isEditing ? 5 : null,
                ),
                _buildDetailItem(
                  'Motivo da Perda',
                  displayOpportunity.motivoDaPerda,
                  'motivoDaPerda',
                ),
                _buildDetailItem(
                  'Qualificação concluída',
                  _formatBool(displayOpportunity.qualificacaoConcluida),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 150,
                        child: Text(
                          'Red Flag:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      _buildRedFlagIndicator(displayOpportunity.redFlag),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // --- Section 2: Metainformação da Oportunidade ---
              _buildDetailSection(context, 'Metainformação da Oportunidade', [
                _buildDetailItem(
                  'Data de Criação da Oportunidade',
                  _formatDate(displayOpportunity.dataDeCriacaoDaOportunidadeC),
                ),
                _buildDetailItem('NIF', displayOpportunity.nifC, 'nifC'),
                // --- MODIFIED: Use Dropdown Builder for Fase ---
                _buildDropdownItem(
                  'Fase',
                  displayOpportunity.faseC,
                  _faseOptions,
                  _selectedFaseC,
                  (newValue) {
                    _updateEditedOpportunityDropdownField('faseC', newValue);
                  },
                ),
                // --- MODIFIED: Use Dropdown Builder for Fase LDF ---
                _buildDropdownItem(
                  'Fase LDF',
                  displayOpportunity.faseLDF,
                  _faseLdfOptions,
                  _selectedFaseLDF,
                  (newValue) {
                    _updateEditedOpportunityDropdownField('faseLDF', newValue);
                  },
                ),
                _buildDetailItem(
                  'Última Lista de Ciclo',
                  displayOpportunity.ultimaListaCicloName,
                ),
              ]),
              const SizedBox(height: 16),

              // --- Section 3: Twogether Retail ---
              _buildDetailSection(context, 'Twogether Retail', [
                _buildDetailItem(
                  'Segmento de Cliente',
                  displayOpportunity.segmentoDeClienteC,
                  'segmentoDeClienteC',
                ),
                _buildDetailItem(
                  'Solução',
                  displayOpportunity.soluOC,
                  'soluOC',
                ),
                _buildDetailItem(
                  'Agente Retail',
                  displayOpportunity.resellerName,
                ),
              ]),
              const SizedBox(height: 16),

              // --- Section 4: Fases ---
              _buildDetailSection(context, 'Fases', [
                _buildDetailItem(
                  'Data do Contacto',
                  _formatDate(displayOpportunity.dataContacto),
                ),
                _buildDetailItem(
                  'Data da Reunião',
                  _formatDate(displayOpportunity.dataReuniao),
                ),
                _buildDetailItem(
                  'Data da Proposta',
                  _formatDate(displayOpportunity.dataProposta),
                ),
                _buildDetailItem(
                  'Data do Fecho',
                  _formatDate(displayOpportunity.dataFecho),
                ),
                _buildDetailItem(
                  'Data de Previsão de Fecho',
                  _formatDate(displayOpportunity.dataDePrevisaoDeFechoC),
                ),
                _buildDetailItem(
                  'Data da última atualização de Fase',
                  _formatDate(displayOpportunity.dataUltimaAtualizacaoFase),
                ),
                _buildDetailItem(
                  'Back Office',
                  displayOpportunity.backOffice,
                  'backOffice',
                ),
                _buildDetailItem(
                  'Ciclo do Ganho',
                  displayOpportunity.cicloDoGanhoName,
                ),
              ]),
              const SizedBox(height: 24),

              // --- Section 5: Files ---
              _buildFilesSection(context, displayOpportunity.files),
              const SizedBox(height: 24),

              // --- Section 6: Proposals (Pass full details object) ---
              _buildProposalsSection(context, displayOpportunity),
            ],
          );
        },
      ),
    );
  }

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

  // Helper widget to display a label and TEXT value, or a TextField if editing
  Widget _buildDetailItem(
    String label,
    String? value, [
    String? fieldKey,
    int? maxLines,
  ]) {
    final controller =
        (fieldKey != null &&
                _editableTextFields.contains(
                  fieldKey,
                )) // Check if it's an editable TEXT field
            ? _controllers[fieldKey]
            : null;

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
                (_isEditing && controller != null)
                    ? TextFormField(
                      controller: controller,
                      maxLines: maxLines,
                      minLines: 1,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.all(8.0),
                        border: OutlineInputBorder(),
                      ),
                    )
                    : Text(
                      value ?? 'N/A',
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: maxLines,
                      overflow: TextOverflow.visible,
                    ),
          ),
        ],
      ),
    );
  }

  // --- NEW: Helper widget for DROPDOWN fields ---
  Widget _buildDropdownItem(
    String label,
    String?
    currentValue, // Value from the displayed opportunity (original or edited)
    List<String> options,
    String?
    selectedValueState, // Value from the state variable used by the dropdown
    ValueChanged<String?> onChanged, // Callback to update state and model
  ) {
    // --- ADDED: Check if the state value is valid within the options --- //
    final String? dropdownValue =
        (selectedValueState != null && options.contains(selectedValueState))
            ? selectedValueState
            : null; // If state is null or not in options, pass null to DropdownButton
    // --- END ADDED Check --- //

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align label top
        children: [
          SizedBox(
            width: 150, // Consistent width for labels
            child: Padding(
              padding: const EdgeInsets.only(top: 12.0), // Align label
              child: Text(
                '$label:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                _isEditing
                    ? DropdownButtonFormField<String>(
                      // --- MODIFIED: Use the validated dropdownValue --- //
                      value: dropdownValue,
                      // --- END MODIFICATION ---
                      isExpanded: true,
                      items:
                          options.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                      onChanged: onChanged,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 10.0,
                        ),
                        border: OutlineInputBorder(),
                      ),
                    )
                    : Padding(
                      padding: const EdgeInsets.only(
                        top: 12.0,
                      ), // Match padding
                      child: Text(
                        currentValue ?? 'N/A',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
  // --- END NEW ---

  // --- NEW: Files Section Builder ---
  Widget _buildFilesSection(BuildContext context, List<SalesforceFile> files) {
    final theme = Theme.of(context);
    final List<dynamic> displayedItems = [
      ...files.where((f) => !_filesToDelete.contains(f)),
      ..._filesToAdd,
    ];

    IconData getFileIcon(String fileTypeOrExtension) {
      final type = fileTypeOrExtension.toLowerCase();
      if (type == 'pdf') return Icons.picture_as_pdf_outlined;
      if (['png', 'jpg', 'jpeg', 'gif', 'bmp'].contains(type))
        return Icons.image_outlined;
      if (['doc', 'docx'].contains(type)) return Icons.description_outlined;
      if (['xls', 'xlsx'].contains(type)) return Icons.table_chart_outlined;
      if (['ppt', 'pptx'].contains(type)) return Icons.slideshow_outlined;
      if (type == 'zip') return Icons.folder_zip_outlined;
      return Icons.insert_drive_file_outlined;
    }

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
                  'Files',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add File',
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
                    'No files linked to this opportunity.',
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

                  if (item is SalesforceFile) {
                    final file = item;
                    icon = getFileIcon(file.fileType);
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
                                    item is SalesforceFile
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
                                    item is SalesforceFile
                                        ? (isMarkedForDeletion
                                            ? 'Undo Delete'
                                            : 'Mark for Deletion')
                                        : 'Remove File',
                                onPressed: () {
                                  setState(() {
                                    if (item is SalesforceFile) {
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

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.any,
      );
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File picking cancelled.')),
          );
        }
      }
    } catch (e) {
      print("Error picking files: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking files: $e')));
      }
    }
  }

  Widget _buildProposalsSection(
    BuildContext context,
    DetailedSalesforceOpportunity opportunityDetails,
  ) {
    final theme = Theme.of(context);
    final proposals = opportunityDetails.proposals;
    String? getProposalId(SalesforceProposal proposal) {
      try {
        return proposal.id;
      } catch (_) {
        return null;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Related Proposals',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 24),
              tooltip: 'Create Proposal',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              splashRadius: 24,
              color: theme.colorScheme.primary,
              onPressed:
                  () => _navigateToCreateProposal(context, opportunityDetails),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (proposals.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                'No proposals linked to this opportunity.',
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
              itemCount: proposals.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final proposal = proposals[index];
                final proposalId = getProposalId(proposal);
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.description_outlined,
                    size: 20,
                    color: theme.colorScheme.secondary,
                  ),
                  title: Text(proposal.name),
                  onTap:
                      (proposalId == null)
                          ? null
                          : () {
                            final path = '/admin/proposal/$proposalId';
                            context.push(path);
                          },
                );
              },
            ),
          ),
      ],
    );
  }
}
