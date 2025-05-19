import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For potential date formatting
import 'package:go_router/go_router.dart'; // Import GoRouter
import 'package:file_picker/file_picker.dart'; // Ensure file_picker is imported
import 'package:flutter/cupertino.dart'; // For CupertinoIcons
import 'package:url_launcher/url_launcher.dart';
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
import '../../../../presentation/widgets/app_loading_indicator.dart'; // Import AppLoadingIndicator
import '../../../../presentation/widgets/logo.dart'; // Import LogoWidget
import '../../../../presentation/widgets/success_dialog.dart'; // Import SuccessDialog
import '../../../../presentation/widgets/simple_list_item.dart'; // Import SimpleListItem

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
    'dataDePrevisaoDeFechoC': 'Data_de_Previs_o_de_Fecho__c', // Added date field
    'dataUltimaAtualizacaoFase': 'Data_da_ltima_actualiza_o_de_Fase__c', // Added date field
    'tipoDeOportunidadeC': 'Tipo_de_Oportunidade__c', // Added tipo de oportunidade field
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

  // Add picklist options for new editable fields
  final List<String> _tipoOportunidadeOptions = const [
    '--Nenhum --',
    'Fidelizada',
    'Cross',
    'Angariada',
    'Angariada Energia',
    'Angariada GN',
    'Angariada Solar',
    'Renovação',
  ];
  final List<String> _motivoDaPerdaOptions = const [
    '--Nenhum --',
    'Não quer ser contactado',
    'Não quer alterações',
    'Serviços vão passar para outro NIF',
    'Vai mudar de Operadora',
    'Empresa encerrou',
  ];

  // Add picklist options for Segmento de Cliente and Solução
  final List<String> _segmentoDeClienteOptions = const [
    '--Nenhum --',
    'Cessou Actividade',
    'Ouro',
    'Prata',
    'Bronze',
    'Lata',
  ];
  final List<String> _solucaoOptions = const [
    '--Nenhum --',
    'LEC',
    'PAP',
    'PP',
    'Energia',
    'Gás',
  ];

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
          // If changing away from '6 - Conclusão Desistência Cliente', clear motivoDaPerda
          if (value != '6 - Conclusão Desistência Cliente') {
            _editedOpportunity = _editedOpportunity!.copyWith(motivoDaPerda: null);
          }
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
      setState(() => _isSaving = false);
      return;
    }

    final authNotifier = ref.read(salesforceAuthProvider.notifier);
    final authState = ref.read(salesforceAuthProvider);

    if (authState != SalesforceAuthState.authenticated) {
      setState(() => _isSaving = false);
      return;
    }

    final String? accessToken = await authNotifier.getValidAccessToken();
    final String? instanceUrl = authNotifier.currentInstanceUrl;

    if (accessToken == null || instanceUrl == null) {
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

    // Compare date fields
    final originalDataDePrevisaoDeFechoC = _originalOpportunity!.dataDePrevisaoDeFechoC;
    final editedDataDePrevisaoDeFechoC = _editedOpportunity!.dataDePrevisaoDeFechoC;
    final dataDePrevisaoDeFechoCApiName = _fieldApiNameMapping['dataDePrevisaoDeFechoC'];
    if (dataDePrevisaoDeFechoCApiName != null && originalDataDePrevisaoDeFechoC != editedDataDePrevisaoDeFechoC) {
      fieldsToUpdate[dataDePrevisaoDeFechoCApiName] = editedDataDePrevisaoDeFechoC;
    }

    final originalDataUltimaAtualizacaoFase = _originalOpportunity!.dataUltimaAtualizacaoFase;
    final editedDataUltimaAtualizacaoFase = _editedOpportunity!.dataUltimaAtualizacaoFase;
    final dataUltimaAtualizacaoFaseApiName = _fieldApiNameMapping['dataUltimaAtualizacaoFase'];
    if (dataUltimaAtualizacaoFaseApiName != null && originalDataUltimaAtualizacaoFase != editedDataUltimaAtualizacaoFase) {
      fieldsToUpdate[dataUltimaAtualizacaoFaseApiName] = editedDataUltimaAtualizacaoFase;
    }

    // Compare tipo de oportunidade field
    final originalTipoDeOportunidadeC = _originalOpportunity!.tipoDeOportunidadeC;
    final editedTipoDeOportunidadeC = _editedOpportunity!.tipoDeOportunidadeC;
    final tipoDeOportunidadeCApiName = _fieldApiNameMapping['tipoDeOportunidadeC'];
    if (tipoDeOportunidadeCApiName != null && originalTipoDeOportunidadeC != editedTipoDeOportunidadeC) {
      fieldsToUpdate[tipoDeOportunidadeCApiName] = editedTipoDeOportunidadeC;
    }
    // --- END NEW ---

    // --- Check if anything changed --- //
    final bool filesChanged = filesToAdd.isNotEmpty || filesToDelete.isNotEmpty;
    if (fieldsToUpdate.isEmpty && !filesChanged) {
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

      // Refresh the data and exit edit mode
      await showSuccessDialog(
        context: context,
        message: 'Alterações guardadas com sucesso!',
        onDismissed: () {
      ref.refresh(opportunityDetailsProvider(widget.opportunityId));
      setState(() {
        _isEditing = false;
      });
        },
      );
    } catch (e) {
      // --- Handle Error --- //
        setState(() => _isSaving = false);
      }
    }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing && _originalOpportunity != null) {
        _initializeEditState(_originalOpportunity!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detailsAsync = ref.watch(
      opportunityDetailsProvider(widget.opportunityId),
    );
    final isDark = theme.brightness == Brightness.dark;

    return detailsAsync.when(
      loading: () => const AppLoadingIndicator(),
      error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
            'Error loading details: \n$error',
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        data: (opportunityDetails) {
          // Initialize state when data first loads or if it changes
          if (!_isEditing &&
              (_originalOpportunity == null ||
                  opportunityDetails.id != _originalOpportunity!.id)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _initializeEditState(opportunityDetails);
                if (_isEditing) setState(() {});
              }
            });
          }

          final DetailedSalesforceOpportunity displayOpportunity =
              (_isEditing ? _editedOpportunity : opportunityDetails) ??
              opportunityDetails;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(CupertinoIcons.chevron_left, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: LogoWidget(height: 60, darkMode: isDark),
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
                    padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Detalhes da Oportunidade',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.left,
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isEditing ? Icons.close : CupertinoIcons.pencil,
                                color: _isEditing ? theme.colorScheme.error : theme.colorScheme.onSurface,
                                size: 28,
                              ),
                              tooltip: _isEditing ? 'Cancelar Edição' : 'Editar',
                              onPressed: _toggleEdit,
                            ),
                            if (_isEditing)
                              const SizedBox(width: 8),
                            if (_isEditing)
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: IconButton(
                                  icon: _isSaving
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                          ),
                                        )
                                      : Icon(
                                          Icons.save_outlined,
                                          color: theme.colorScheme.primary,
                                          size: 28,
                                        ),
                                  onPressed: _isSaving ? null : _saveEdit,
                                  tooltip: 'Guardar',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    shape: const CircleBorder(),
                                    padding: const EdgeInsets.all(0),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        // --- Section 1: Informação da Oportunidade (now with meta fields) ---
                        _buildDetailSectionTwoColumn(context, 'Informação da Oportunidade', [
                          // LEFT COLUMN
                          [
                            _isEditing
                              ? _buildEditableTextField('Oportunidade', _controllers['name']!)
                              : _buildDetailItem('Oportunidade', displayOpportunity.name, 'name'),
                            _isEditing
                              ? _buildEditableTextField('Entidade', TextEditingController(text: displayOpportunity.accountName ?? ''), readOnly: true)
                              : _buildDetailItem('Entidade', displayOpportunity.accountName),
                            _isEditing
                              ? _buildEditableTextField('Owner', TextEditingController(text: displayOpportunity.ownerName ?? ''), readOnly: true)
                              : _buildDetailItem('Owner', displayOpportunity.ownerName),
                            _isEditing
                              ? _buildEditableDropdownField('Tipo de Oportunidade', displayOpportunity.tipoDeOportunidadeC, _tipoOportunidadeOptions, (newValue) {
                                  setState(() {
                                    _editedOpportunity = _editedOpportunity?.copyWith(tipoDeOportunidadeC: newValue);
                                  });
                                })
                              : _buildDetailItem('Tipo de Oportunidade', displayOpportunity.tipoDeOportunidadeC),
                            _isEditing
                              ? _buildEditableTextField('Observações', _controllers['observacoes']!, maxLines: 5)
                              : _buildDetailItem('Observações', displayOpportunity.observacoes, 'observacoes', _isEditing ? 5 : null),
                            // Motivo da Perda: only show if Fase is '6 - Conclusão Desistência Cliente'
                            if ((_isEditing && (_selectedFaseC == '6 - Conclusão Desistência Cliente')) ||
                                (!_isEditing && displayOpportunity.faseC == '6 - Conclusão Desistência Cliente' && (displayOpportunity.motivoDaPerda?.isNotEmpty ?? false)))
                              _isEditing
                                ? _buildEditableDropdownField('Motivo da Perda', displayOpportunity.motivoDaPerda, _motivoDaPerdaOptions, (newValue) {
                                    setState(() {
                                      _editedOpportunity = _editedOpportunity?.copyWith(motivoDaPerda: newValue);
                                    });
                                  })
                                : _buildDetailItem('Motivo da Perda', displayOpportunity.motivoDaPerda),
                            _isEditing
                              ? _buildEditableTextField('Qualificação concluída', TextEditingController(text: _formatBool(displayOpportunity.qualificacaoConcluida)), readOnly: true)
                              : _buildDetailItem('Qualificação concluída', _formatBool(displayOpportunity.qualificacaoConcluida)),
                            if (!_isEditing)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 150,
                                      child: Text('Red Flag:', style: TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      _buildRedFlagIndicator(displayOpportunity.redFlag),
                    ],
                  ),
                ),
                          ],
                          // RIGHT COLUMN
                          [
                            _isEditing
                              ? _buildEditableTextField('Data de Criação da Oportunidade', TextEditingController(text: _formatDate(displayOpportunity.dataDeCriacaoDaOportunidadeC)), readOnly: true)
                              : _buildDetailItem('Data de Criação da Oportunidade', _formatDate(displayOpportunity.dataDeCriacaoDaOportunidadeC)),
                            _isEditing
                              ? _buildEditableTextField('NIF', _controllers['nifC']!)
                              : _buildDetailItem('NIF', displayOpportunity.nifC, 'nifC'),
                            _isEditing
                              ? _buildEditableDropdownField('Fase', _selectedFaseC, _faseOptions, (newValue) { _updateEditedOpportunityDropdownField('faseC', newValue); })
                              : _buildDetailItem('Fase', displayOpportunity.faseC),
                            _isEditing
                              ? _buildEditableDropdownField('Fase LDF', _selectedFaseLDF, _faseLdfOptions, (newValue) { _updateEditedOpportunityDropdownField('faseLDF', newValue); })
                              : _buildDetailItem('Fase LDF', displayOpportunity.faseLDF),
                          ],
              ]),
              const SizedBox(height: 16),
                        // --- Section 2: Twogether Retail ---
              _buildDetailSection(context, 'Twogether Retail', [
                          _isEditing
                            ? _buildEditableDropdownField('Segmento de Cliente', displayOpportunity.segmentoDeClienteC, _segmentoDeClienteOptions, (newValue) {
                                setState(() {
                                  _editedOpportunity = _editedOpportunity?.copyWith(segmentoDeClienteC: newValue);
                                });
                              })
                            : _buildDetailItem('Segmento de Cliente', displayOpportunity.segmentoDeClienteC),
                          _isEditing
                            ? _buildEditableDropdownField('Solução', displayOpportunity.soluOC, _solucaoOptions, (newValue) {
                                setState(() {
                                  _editedOpportunity = _editedOpportunity?.copyWith(soluOC: newValue);
                                });
                              })
                            : _buildDetailItem('Solução', displayOpportunity.soluOC),
                          _isEditing
                            ? _buildEditableTextField('Agente Retail', TextEditingController(text: displayOpportunity.resellerName ?? ''), readOnly: true)
                            : _buildDetailItem('Agente Retail', displayOpportunity.resellerName),
              ]),
              const SizedBox(height: 16),
                        // --- Section 3: Fases ---
              _buildDetailSectionTwoColumn(context, 'Fases', [
                [
                  _isEditing
                    ? _buildEditableTextField('Data do Contacto', TextEditingController(text: _formatDate(displayOpportunity.dataContacto)), readOnly: true)
                    : _buildDetailItem('Data do Contacto', _formatDate(displayOpportunity.dataContacto)),
                  _isEditing
                    ? _buildEditableTextField('Data da Proposta', TextEditingController(text: _formatDate(displayOpportunity.dataProposta)), readOnly: true)
                    : _buildDetailItem('Data da Proposta', _formatDate(displayOpportunity.dataProposta)),
                  _isEditing
                    ? _buildEditableDateField('Data de Previsão de Fecho', displayOpportunity.dataDePrevisaoDeFechoC, (picked) {
                        setState(() {
                          _editedOpportunity = _editedOpportunity?.copyWith(dataDePrevisaoDeFechoC: picked?.toIso8601String());
                        });
                      })
                    : _buildDetailItem('Data de Previsão de Fecho', _formatDate(displayOpportunity.dataDePrevisaoDeFechoC)),
                  _isEditing
                    ? _buildEditableTextField('Back Office', TextEditingController(text: displayOpportunity.backOffice ?? ''), readOnly: true)
                    : _buildDetailItem('Back Office', displayOpportunity.backOffice, 'backOffice'),
                ],
                [
                  _isEditing
                    ? _buildEditableTextField('Data da Reunião', TextEditingController(text: _formatDate(displayOpportunity.dataReuniao)), readOnly: true)
                    : _buildDetailItem('Data da Reunião', _formatDate(displayOpportunity.dataReuniao)),
                  _isEditing
                    ? _buildEditableTextField('Data do Fecho', TextEditingController(text: _formatDate(displayOpportunity.dataFecho)), readOnly: true)
                    : _buildDetailItem('Data do Fecho', _formatDate(displayOpportunity.dataFecho)),
                  _isEditing
                    ? _buildEditableDateField('Data da última atualização de Fase', displayOpportunity.dataUltimaAtualizacaoFase, (picked) {
                        setState(() {
                          _editedOpportunity = _editedOpportunity?.copyWith(dataUltimaAtualizacaoFase: picked?.toIso8601String());
                        });
                      })
                    : _buildDetailItem('Data da última atualização de Fase', _formatDate(displayOpportunity.dataUltimaAtualizacaoFase)),
                  _isEditing
                    ? _buildEditableTextField('Ciclo do Ganho', TextEditingController(text: displayOpportunity.cicloDoGanhoName ?? ''), readOnly: true)
                    : _buildDetailItem('Ciclo do Ganho', displayOpportunity.cicloDoGanhoName),
                ],
              ]),
              const SizedBox(height: 24),
                        // --- Section 4: Files ---
              _buildFilesSection(context, displayOpportunity.files),
              const SizedBox(height: 24),
                        // --- Section 5: Proposals ---
              _buildProposalsSection(context, displayOpportunity),
            ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          );
        },
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
                  'Ficheiros',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Adicionar Ficheiro',
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
                    'Sem ficheiros associados a esta oportunidade.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: displayedItems.map((item) {
                  return _buildFilePreview(context, item);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreview(BuildContext context, dynamic item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
                  String title;
                  String subtitle = '';
                  VoidCallback? onTapAction;
                  bool isMarkedForDeletion = false;
    String? fileType;
    String? fileExtension;
    Widget iconWidget;

                  if (item is SalesforceFile) {
                    final file = item;
      fileType = file.fileType.toLowerCase();
                    title = file.title;
                    subtitle = file.fileType.toUpperCase();
                    isMarkedForDeletion = _filesToDelete.contains(file);
      final isImage = ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp', 'heic'].contains(fileType);
      final isPdf = fileType == 'pdf';
      if (isImage) {
        iconWidget = Icon(Icons.image_outlined, color: colorScheme.primary, size: 30);
      } else if (isPdf) {
        iconWidget = Icon(Icons.picture_as_pdf, color: colorScheme.error, size: 30);
      } else {
        iconWidget = Icon(Icons.insert_drive_file, color: colorScheme.onSurfaceVariant, size: 30);
      }
                    onTapAction = () {
                      if (isMarkedForDeletion) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
            builder: (_) => SecureFileViewer(
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
      fileExtension = (file.extension ?? '').toLowerCase();
                    title = file.name;
                    subtitle = '${((file.size / 1024 * 100).round() / 100)} KB';
      if (["png", "jpg", "jpeg", "gif", "bmp", "webp", "heic"].contains(fileExtension)) {
        iconWidget = Icon(Icons.image_outlined, color: colorScheme.primary, size: 30);
      } else if (fileExtension == "pdf") {
        iconWidget = Icon(Icons.picture_as_pdf, color: colorScheme.error, size: 30);
      } else {
        iconWidget = Icon(Icons.insert_drive_file, color: colorScheme.onSurfaceVariant, size: 30);
      }
                    onTapAction = null;
                  } else {
                    return const SizedBox.shrink();
                  }

    return Container(
      width: 70,
      height: 70,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha((255 * 0.7).round()),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: Colors.black.withAlpha((255 * 0.1).round()),
          width: 0.5,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: InkWell(
              onTap: onTapAction,
              borderRadius: BorderRadius.circular(8.0),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    iconWidget,
                    const SizedBox(height: 4),
                    Text(
                        title,
                      style: textTheme.bodySmall?.copyWith(fontSize: 8),
                      maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                      ),
              ),
            ),
          ),
          if (_isEditing && !isMarkedForDeletion && item is SalesforceFile)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: colorScheme.error,
                  tooltip: 'Remover ficheiro',
                                onPressed: () {
                                  setState(() {
                                        _filesToDelete.add(item);
                                  });
                                },
                ),
                    ),
            ),
          if (_isEditing && item is PlatformFile)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 2,
              ),
          ],
        ),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: colorScheme.error,
                  tooltip: 'Remover ficheiro',
                  onPressed: () {
                    setState(() {
                      _filesToAdd.remove(item);
                    });
                  },
                ),
              ),
            ),
        ],
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
          // No snackbar for file read error
        }
      } else {
        // No snackbar for file picking cancelled
      }
    } catch (e) {
      print("Error picking files: $e");
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
              'Propostas',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 24),
              tooltip: 'Criar Proposta',
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
                'Não existem propostas associadas a esta oportunidade.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          Column(
            children: proposals.map((proposal) {
              final proposalId = getProposalId(proposal);
              return SimpleListItem(
                leading: Icon(Icons.description_outlined, size: 20, color: theme.colorScheme.secondary),
                title: proposal.name,
                onTap: (proposalId == null)
                  ? null
                  : () {
                      final path = '/admin/proposal/$proposalId';
                      context.push(path);
                    },
              );
            }).toList(),
          ),
      ],
    );
  }

  // --- NEW: Two-column section builder ---
  Widget _buildDetailSectionTwoColumn(BuildContext context, String title, List<List<Widget>> columns) {
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: columns[0],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: columns[1],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- NEW: Date picker item builder ---
  Widget _buildDatePickerItem(String label, String? currentValue, ValueChanged<DateTime?> onDatePicked) {
    final theme = Theme.of(context);
    DateTime? parsedDate;
    if (currentValue != null) {
      try {
        parsedDate = DateTime.parse(currentValue);
      } catch (_) {}
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: parsedDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                  initialEntryMode: DatePickerEntryMode.calendarOnly,
                  builder: (context, child) {
                    final theme = Theme.of(context);
                    return Theme(
                      data: theme.copyWith(
                        colorScheme: theme.colorScheme.copyWith(
                          primary: theme.colorScheme.primary,
                          surface: theme.colorScheme.surface,
                        ),
                        dialogBackgroundColor: theme.colorScheme.surface,
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                onDatePicked(picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  parsedDate != null ? DateFormat('dd MMM yyyy').format(parsedDate) : 'Selecionar data',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
      ],
      ),
    );
  }

  // --- SHARED INPUT DECORATION (from admin_opportunity_submission_page.dart) ---
  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return InputDecoration(
      labelText: label,
      labelStyle: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
      hintText: hint,
      hintStyle: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
      filled: true,
      fillColor: readOnly ? colorScheme.surfaceVariant.withOpacity(0.7) : colorScheme.surfaceVariant,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.08)),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: suffixIcon,
    );
  }

  // --- REFACTOR: Editable text field builder ---
  Widget _buildEditableTextField(String label, TextEditingController controller, {int? maxLines, String? hint, bool readOnly = false, Widget? suffixIcon}) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines ?? 1,
        minLines: 1,
        readOnly: readOnly,
        style: readOnly ? theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor) : theme.textTheme.bodySmall,
        decoration: _inputDecoration(label: label, hint: hint, readOnly: readOnly, suffixIcon: suffixIcon),
      ),
    );
  }

  // --- REFACTOR: Editable dropdown field builder ---
  Widget _buildEditableDropdownField(String label, String? value, List<String> options, ValueChanged<String?> onChanged) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: DropdownButtonFormField<String>(
        value: options.contains(value) ? value : options.first,
        decoration: _inputDecoration(label: label),
        items: options.map((String v) {
          return DropdownMenuItem<String>(
            value: v,
            child: Text(v, style: theme.textTheme.bodySmall),
          );
        }).toList(),
        onChanged: onChanged,
        style: theme.textTheme.bodySmall,
        isExpanded: true,
      ),
    );
  }

  // --- REFACTOR: Editable date picker field builder ---
  Widget _buildEditableDateField(String label, String? value, ValueChanged<DateTime?> onDatePicked) {
    final theme = Theme.of(context);
    DateTime? parsedDate;
    if (value != null) {
      try {
        parsedDate = DateTime.parse(value);
      } catch (_) {}
    }
    final controller = TextEditingController(text: parsedDate != null ? DateFormat('dd/MM/yyyy').format(parsedDate) : '');
    return SizedBox(
      height: 56,
      child: TextFormField(
        controller: controller,
        style: theme.textTheme.bodySmall,
        decoration: _inputDecoration(
          label: label,
          hint: 'Selecionar data',
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        readOnly: true,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: parsedDate ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2101),
            initialEntryMode: DatePickerEntryMode.calendarOnly,
            builder: (context, child) {
              final theme = Theme.of(context);
              return Theme(
                data: theme.copyWith(
                  colorScheme: theme.colorScheme.copyWith(
                    primary: theme.colorScheme.primary,
                    surface: theme.colorScheme.surface,
                  ),
                  dialogBackgroundColor: theme.colorScheme.surface,
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
                child: child!,
              );
            },
          );
          onDatePicked(picked);
        },
      ),
    );
  }
}
