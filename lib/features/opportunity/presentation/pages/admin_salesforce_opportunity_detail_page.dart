import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For potential date formatting
import 'package:go_router/go_router.dart'; // Import GoRouter
import 'package:file_picker/file_picker.dart'; // Ensure file_picker is imported
import 'package:flutter/cupertino.dart'; // For CupertinoIcons
import '../../../../core/services/file_icon_service.dart'; // Import FileIconService

import '../../data/models/detailed_salesforce_opportunity.dart';
import '../../data/models/salesforce_proposal.dart';
import '../../data/models/salesforce_file.dart'; // <-- Import SalesforceFile
import '../providers/opportunity_providers.dart';
import '../../../../core/services/salesforce_auth_service.dart'; // Import the service which defines the provider
import '../../../../presentation/widgets/secure_file_viewer.dart'; // Import SecureFileViewer
import '../../../../presentation/widgets/app_loading_indicator.dart'; // Import AppLoadingIndicator
import '../../../../presentation/widgets/logo.dart'; // Import LogoWidget
import '../../../../presentation/widgets/success_dialog.dart'; // Import SuccessDialog
import '../../../../presentation/widgets/simple_list_item.dart'; // Import SimpleListItem
import '../../../../presentation/widgets/app_input_field.dart'; // Import AppDropdownField

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
        case 'dataUltimaAtualizacaoFase':
          _editedOpportunity = _editedOpportunity!.copyWith(dataUltimaAtualizacaoFase: value);
          break;
        case 'dataDePrevisaoDeFechoC':
          _editedOpportunity = _editedOpportunity!.copyWith(dataDePrevisaoDeFechoC: value);
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
        case 'tipoDeOportunidadeC':
          _editedOpportunity = _editedOpportunity!.copyWith(tipoDeOportunidadeC: valueToSave);
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
      // Use Portuguese locale if available, fallback to just dd/MM/yyyy
      return DateFormat('dd/MM/yyyy', 'pt_PT').format(dateTime.toLocal());
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
        if (kDebugMode) {
          print("Warning: No API name mapping found for field '$fieldKey'");
        }
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
        if (kDebugMode) {
          print("Deleting ${filesToDelete.length} files...");
        }
        await Future.wait(
          filesToDelete.map((file) async {
            try {
              await opportunityService.deleteFile(
                accessToken: accessToken,
                instanceUrl: instanceUrl,
                contentDocumentId: file.id,
              );
              if (kDebugMode) {
                print("Deleted file: ${file.title}");
              }
            } catch (e) {
              if (kDebugMode) {
                print("Error deleting file ${file.title}: $e");
              }
            }
          }),
        );
      }

      // --- Process File Uploads --- //
      if (filesToAdd.isNotEmpty) {
        if (kDebugMode) {
          print("Uploading ${filesToAdd.length} files...");
        }
        await Future.wait(
          filesToAdd.map((file) async {
            if (file.bytes == null) {
              if (kDebugMode) {
                print("Skipping upload for ${file.name}, bytes are missing.");
              }
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
                if (kDebugMode) {
                  print("Uploaded file: ${file.name} (ID: $contentDocId)");
                }
              } else {
                if (kDebugMode) {
                  print(
                    "Upload failed for file: ${file.name} (Service returned null)",
                  );
                }
              }
            } catch (e) {
              if (kDebugMode) {
                print("Error uploading file ${file.name}: $e");
              }
            }
          }),
        );
      }

      // --- Update Opportunity Fields (if changed) --- //
      if (fieldsToUpdate.isNotEmpty) {
        if (kDebugMode) {
          print(
            "Updating opportunity fields: $fieldsToUpdate",
          ); // Log fields being updated
        }
        await opportunityService.updateOpportunity(
          accessToken: accessToken,
          instanceUrl: instanceUrl,
          opportunityId: widget.opportunityId,
          fieldsToUpdate: fieldsToUpdate,
        );
        if (kDebugMode) {
          print("Opportunity fields updated.");
        }
      } else {
        if (kDebugMode) {
          print("No opportunity fields to update.");
        }
      }

      // Refresh the data and exit edit mode
      if (!mounted) return;
      await showSuccessDialog(
        context: context,
        message: 'Alterações guardadas com sucesso!',
        onDismissed: () {
          ref.invalidate(opportunityDetailsProvider(widget.opportunityId));
          setState(() {
            _isEditing = false;
            _isSaving = false;
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
      _isSaving = false;
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
                    padding: const EdgeInsets.only(top: 32, left: 24, right: 24, bottom: 16),
                    child: Row(
                      children: [
                        // Left spacer for symmetry
                        SizedBox(width: _isEditing ? 100 : 56), // Account for button width
                        // Title in the center with flex
                        Expanded(
                          child: Text(
                            displayOpportunity.name ?? 'Detalhes da Oportunidade',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                              fontSize: 28,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2, // Allow 2 lines for long titles
                          ),
                        ),
                        // Right side buttons
                        Container(
                          width: _isEditing ? 100 : 56, // Fixed width for buttons
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                                ? AppInputField(
                                    controller: _controllers['name']!,
                                    label: 'Oportunidade',
                                    readOnly: false,
                                    onChanged: (String value) => _updateEditedOpportunityTextField('name', value),
                                  )
                                : AppInputField(
                                    controller: _controllers['name']!,
                                    label: 'Oportunidade',
                                    readOnly: true,
                                  ),
                            const SizedBox(height: 8),
                            AppInputField(
                              controller: TextEditingController(text: displayOpportunity.accountName ?? ''),
                              label: 'Entidade',
                              readOnly: true,
                            ),
                            const SizedBox(height: 8),
                            AppInputField(
                              controller: TextEditingController(text: displayOpportunity.ownerName ?? ''),
                              label: 'Owner',
                              readOnly: true,
                            ),
                            const SizedBox(height: 8),
                            _isEditing
                              ? AppDropdownField<String>(
                                  label: 'Tipo de Oportunidade',
                                  value: _tipoOportunidadeOptions.contains(_editedOpportunity?.tipoDeOportunidadeC)
                                      ? _editedOpportunity?.tipoDeOportunidadeC
                                      : _tipoOportunidadeOptions.first,
                                  items: _tipoOportunidadeOptions.map((v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
                                  onChanged: (String? value) {
                                    if (value != null) {
                                      _updateEditedOpportunityDropdownField('tipoDeOportunidadeC', value);
                                    }
                                  },
                                )
                              : AppInputField(
                                  controller: TextEditingController(text: displayOpportunity.tipoDeOportunidadeC ?? 'N/A'),
                                  label: 'Tipo de Oportunidade',
                                  readOnly: true,
                                ),
                            const SizedBox(height: 8),
                            _isEditing
                              ? AppInputField(
                                  controller: _controllers['observacoes']!,
                                  label: 'Observações',
                                  maxLines: 5,
                                  readOnly: false,
                                  onChanged: (String value) => _updateEditedOpportunityTextField('observacoes', value),
                                )
                              : AppInputField(
                                  controller: _controllers['observacoes']!,
                                  label: 'Observações',
                                  maxLines: 5,
                                  readOnly: true,
                                ),
                            // Motivo da Perda: only show if Fase is '6 - Conclusão Desistência Cliente'
                            if ((_isEditing && (_selectedFaseC == '6 - Conclusão Desistência Cliente')) ||
                                (!_isEditing && displayOpportunity.faseC == '6 - Conclusão Desistência Cliente' && (displayOpportunity.motivoDaPerda?.isNotEmpty ?? false))) ...[
                              const SizedBox(height: 8),
                              _isEditing
                                ? AppDropdownField<String>(
                                    label: 'Motivo da Perda',
                                    value: _motivoDaPerdaOptions.contains(_editedOpportunity?.motivoDaPerda)
                                        ? _editedOpportunity?.motivoDaPerda
                                        : _motivoDaPerdaOptions.first,
                                    items: _motivoDaPerdaOptions.map((v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
                                    onChanged: (String? value) {
                                      if (value != null) {
                                        _updateEditedOpportunityTextField('motivoDaPerda', value);
                                      }
                                    },
                                  )
                                : AppInputField(
                                    controller: TextEditingController(text: displayOpportunity.motivoDaPerda ?? 'N/A'),
                                    label: 'Motivo da Perda',
                                    readOnly: true,
                                  ),
                            ],
                          ],
                          // RIGHT COLUMN
                          [
                            // Date field: Data de Criação da Oportunidade (always read-only)
                            AppInputField(
                              controller: TextEditingController(text: _formatDate(displayOpportunity.dataDeCriacaoDaOportunidadeC)),
                              label: 'Data de Criação da Oportunidade',
                              readOnly: true,
                            ),
                            const SizedBox(height: 8),
                            AppInputField(
                              controller: _controllers['nifC']!,
                              label: 'NIF',
                              readOnly: true,
                            ),
                            const SizedBox(height: 8),
                            _isEditing
                              ? AppDropdownField<String>(
                                  label: 'Fase',
                                  value: _faseOptions.contains(_editedOpportunity?.faseC)
                                      ? _editedOpportunity?.faseC
                                      : _faseOptions.first,
                                  items: _faseOptions.map((v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
                                  onChanged: (String? value) {
                                    if (value != null) {
                                      _updateEditedOpportunityDropdownField('faseC', value);
                                    }
                                  },
                                )
                              : AppInputField(
                                  controller: TextEditingController(text: displayOpportunity.faseC ?? 'N/A'),
                                  label: 'Fase',
                                  readOnly: true,
                                ),
                            const SizedBox(height: 8),
                            AppInputField(
                              controller: TextEditingController(text: _formatBool(displayOpportunity.qualificacaoConcluida)),
                              label: 'Qualificação concluída',
                              readOnly: true,
                            ),
                            const SizedBox(height: 8),
                            if (!_isEditing)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Red Flag', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      _buildRedFlagIndicator(displayOpportunity.redFlag),
                    ],
                  ),
                ),
                          ],
              ]),
              const SizedBox(height: 16),
                        // --- Section 2: Twogether Retail ---
              _buildDetailSectionTwoColumn(context, 'Twogether Retail', [
                          [
                            _isEditing
                              ? AppDropdownField<String>(
                                  label: 'Segmento de Cliente',
                                  value: _segmentoDeClienteOptions.contains(_editedOpportunity?.segmentoDeClienteC)
                                      ? _editedOpportunity?.segmentoDeClienteC
                                      : _segmentoDeClienteOptions.first,
                                  items: _segmentoDeClienteOptions.map((v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
                                  onChanged: (String? value) {
                                    if (value != null) {
                                      _updateEditedOpportunityTextField('segmentoDeClienteC', value);
                                    }
                                  },
                                )
                              : AppInputField(
                                  controller: TextEditingController(text: displayOpportunity.segmentoDeClienteC ?? 'N/A'),
                                  label: 'Segmento de Cliente',
                                  readOnly: true,
                                ),
                            const SizedBox(height: 8),
                            _isEditing
                              ? AppDropdownField<String>(
                                  label: 'Solução',
                                  value: _solucaoOptions.contains(_editedOpportunity?.soluOC)
                                      ? _editedOpportunity?.soluOC
                                      : _solucaoOptions.first,
                                  items: _solucaoOptions.map((v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
                                  onChanged: (String? value) {
                                    if (value != null) {
                                      _updateEditedOpportunityTextField('soluOC', value);
                                    }
                                  },
                                )
                              : AppInputField(
                                  controller: TextEditingController(text: displayOpportunity.soluOC ?? 'N/A'),
                                  label: 'Solução',
                                  readOnly: true,
                                ),
                          ],
                          [
                            AppInputField(
                              controller: TextEditingController(text: displayOpportunity.resellerName ?? ''),
                              label: 'Agente Retail',
                              readOnly: true,
                            ),
                          ],
              ]),
              const SizedBox(height: 16),
                        // --- Section 3: Fases ---
              _buildDetailSectionTwoColumn(context, 'Fases', [
                [
                  AppInputField(
                    controller: TextEditingController(text: _formatDate(displayOpportunity.dataContacto)),
                    label: 'Data do Contacto',
                    readOnly: true,
                  ),
                  const SizedBox(height: 8),
                  AppInputField(
                    controller: TextEditingController(text: _formatDate(displayOpportunity.dataProposta)),
                    label: 'Data da Proposta',
                    readOnly: true,
                  ),
                  const SizedBox(height: 8),
                  _isEditing
                    ? AppDateInputField(
                        label: 'Data de Previsão de Fecho',
                        value: _editedOpportunity?.dataDePrevisaoDeFechoC != null && _editedOpportunity!.dataDePrevisaoDeFechoC!.isNotEmpty
                            ? DateTime.tryParse(_editedOpportunity!.dataDePrevisaoDeFechoC!)
                            : null,
                        onChanged: (DateTime? date) => _updateEditedOpportunityTextField('dataDePrevisaoDeFechoC', date?.toIso8601String() ?? ''),
                        lastDate: DateTime(2101),
                      )
                    : AppInputField(
                        controller: TextEditingController(text: _formatDate(displayOpportunity.dataDePrevisaoDeFechoC)),
                        label: 'Data de Previsão de Fecho',
                        readOnly: true,
                      ),
                  const SizedBox(height: 8),
                  AppInputField(
                    controller: TextEditingController(text: displayOpportunity.backOffice ?? ''),
                    label: 'Back Office',
                    readOnly: true,
                  ),
                ],
                [
                  AppInputField(
                    controller: TextEditingController(text: _formatDate(displayOpportunity.dataReuniao)),
                    label: 'Data da Reunião',
                    readOnly: true,
                  ),
                  const SizedBox(height: 8),
                  AppInputField(
                    controller: TextEditingController(text: _formatDate(displayOpportunity.dataFecho)),
                    label: 'Data do Fecho',
                    readOnly: true,
                  ),
                  const SizedBox(height: 8),
                  _isEditing
                    ? AppDateInputField(
                        label: 'Data da última atualização de Fase',
                        value: _editedOpportunity?.dataUltimaAtualizacaoFase != null && _editedOpportunity!.dataUltimaAtualizacaoFase!.isNotEmpty
                            ? DateTime.tryParse(_editedOpportunity!.dataUltimaAtualizacaoFase!)
                            : null,
                        onChanged: (DateTime? date) => _updateEditedOpportunityTextField('dataUltimaAtualizacaoFase', date?.toIso8601String() ?? ''),
                        lastDate: DateTime(2101),
                      )
                    : AppInputField(
                        controller: TextEditingController(text: _formatDate(displayOpportunity.dataUltimaAtualizacaoFase)),
                        label: 'Data da última atualização de Fase',
                        readOnly: true,
                      ),
                  const SizedBox(height: 8),
                  AppInputField(
                    controller: TextEditingController(text: displayOpportunity.cicloDoGanhoName ?? ''),
                    label: 'Ciclo do Ganho',
                    readOnly: true,
                  ),
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
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 16),
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
      padding: const EdgeInsets.symmetric(vertical: 4.0), // Less vertical spacing
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 190, // Fixed width for the label
            alignment: Alignment.centerRight,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(217),
            ),
              textAlign: TextAlign.right,
          ),
          ),
          const SizedBox(width: 24),
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
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                        textAlign: TextAlign.left,
                    ),
          ),
        ],
      ),
    );
  }

  // --- NEW: Files Section Builder ---
  Widget _buildFilesSection(BuildContext context, List<SalesforceFile> files) {
    final theme = Theme.of(context);
    final List<dynamic> displayedItems = [
      ...files.where((f) => !_filesToDelete.contains(f)),
      if (_isEditing) ..._filesToAdd,
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
              children: [
                Text(
                  'Ficheiros',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.left,
                ),
                Spacer(),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Adicionar Ficheiro',
                    onPressed: _pickFiles,
                  ),
              ],
            ),
            const SizedBox(height: 16),
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
      final iconAsset = FileIconService.getIconAssetPath(fileType);
      iconWidget = Image.asset(
        iconAsset,
        width: 30,
        height: 30,
        fit: BoxFit.contain,
      );
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
      final iconAsset = FileIconService.getIconAssetPath(fileExtension);
      iconWidget = Image.asset(
        iconAsset,
        width: 30,
        height: 30,
        fit: BoxFit.contain,
      );
                    onTapAction = null;
                  } else {
                    return const SizedBox.shrink();
                  }

    return Tooltip(
      message: title,
      child: Container(
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
                      color: Colors.black.withAlpha(20),
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
                      color: Colors.black.withAlpha(20),
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
      if (kDebugMode) {
        print("Error picking files: $e");
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
        const SizedBox(height: 16),
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
                leading: Icon(Icons.description_outlined, size: 20, color: theme.colorScheme.onSurface),
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
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 16),
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
                        dialogTheme: DialogTheme(
                          backgroundColor: theme.colorScheme.surface,
                        ),
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
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  parsedDate != null ? DateFormat('dd/MM/yyyy', 'pt_PT').format(parsedDate) : 'Selecionar data',
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
      hintStyle: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withAlpha(179)),
      filled: true,
      fillColor: readOnly ? colorScheme.surfaceContainerHighest.withAlpha(179) : colorScheme.surfaceContainerHighest,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline.withAlpha(51)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline.withAlpha(20)),
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
                  dialogTheme: DialogTheme(
                    backgroundColor: theme.colorScheme.surface,
                  ),
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

  void _handleTipoDeOportunidadeChanged(String? value) { if (value != null) _updateEditedOpportunityDropdownField('tipoDeOportunidadeC', value); }
  void _handleMotivoDaPerdaChanged(String? value) { if (value != null) _updateEditedOpportunityTextField('motivoDaPerda', value); }
  void _handleFaseCChanged(String? value) { if (value != null) _updateEditedOpportunityDropdownField('faseC', value); }
}
