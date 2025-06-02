import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For date/number formatting
import 'package:go_router/go_router.dart'; // If needed later for navigation
import 'package:file_picker/file_picker.dart'; // <-- RESTORED IMPORT
import 'package:flutter/cupertino.dart'; // For CupertinoIcons
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

import '../providers/proposal_providers.dart'; // Provider for proposal details
import '../../data/models/detailed_salesforce_proposal.dart';
import '../../data/models/proposal_file.dart';
import '../../data/models/cpe_proposal_link.dart';
import '../../../../presentation/widgets/secure_file_viewer.dart'; // For viewing files
import '../../../../core/services/salesforce_auth_service.dart'; // For getting credentials on save
import '../widgets/add_cpe_to_proposal_dialog.dart'; // <-- ADDED IMPORT for dialog
import '../../../../presentation/widgets/logo.dart'; // Import LogoWidget
import '../../../../presentation/widgets/app_loading_indicator.dart'; // Import AppLoadingIndicator
import '../../../../presentation/widgets/success_dialog.dart'; // Import SuccessDialog
import '../../../../presentation/widgets/simple_list_item.dart'; // Import SimpleListItem
import '../../../../presentation/widgets/app_input_field.dart'; // Import AppInputField
import '../../../../core/services/file_icon_service.dart'; // Import FileIconService
import '../../../../features/notifications/data/repositories/notification_repository.dart'; // Import NotificationRepository
import '../../../../core/models/notification.dart';

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
  final List<String> _editableFields = [
    'name',
    'nifC',
    'responsavelNegocioRetailC',
    'responsavelNegocioExclusivoC',
    'consumoPeriodoContratoKwhC',
    'valorInvestimentoSolarC',
    'dataValidadeC',
    'dataInicioContratoC',
    'dataFimContratoC',
    // Dropdowns
    'soluOC',
    'statusC',
    // Checkboxes
    'energiaC',
    'solarC',
    'contratoInseridoC',
  ];

  // --- Map Model Fields to Salesforce API Names ---
  final Map<String, String> _fieldApiNameMapping = {
    'name': 'Name',
    'nifC': 'NIF__c',
    'responsavelNegocioRetailC': 'Respons_vel_de_Neg_cio_Retail__c',
    'responsavelNegocioExclusivoC': 'Respons_vel_de_Neg_cio_Exclusivo__c',
    'consumoPeriodoContratoKwhC': 'Consumo_para_o_per_odo_do_contrato_KWh__c',
    'valorInvestimentoSolarC': 'Valor_de_Investimento_Solar__c',
    'dataValidadeC': 'Data_de_Validade__c',
    'dataInicioContratoC': 'Data_de_In_cio_do_Contrato__c',
    'dataFimContratoC': 'Data_de_fim_do_Contrato__c',
    'soluOC': 'Solu_o__c',
    'statusC': 'Status__c',
    'energiaC': 'Energia__c',
    'solarC': 'Solar__c',
    'contratoInseridoC': 'Contrato_inserido__c',
    'bundleC': 'Bundle__c',
    // Add more if needed
  };

  // --- NEW: State variables for dropdowns ---
  String? _selectedSolution;
  String? _selectedStatus;
  // --- END NEW ---

  // --- NEW: Picklist Options --- //
  final List<String> _solucaoOptions = const [
    '--Nenhum --',
    'LEC',
    'PAP',
    'PP',
    'Energia',
    'Gás',
  ];

  final List<String> _statusOptions = const [
    '--Nenhum --',
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
    for (final field in _editableFields) {
      if ([
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
    // Remove listeners before disposing controllers
    _controllers['valorInvestimentoSolarC']?.removeListener(_valorListener);
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  // Listener for valorInvestimentoSolarC
  void _valorListener() {
    if (!_isEditing) return;
    final text = _controllers['valorInvestimentoSolarC']?.text ?? '';
    final value = _parseDouble(text);
    _updateEditedProposalField('valorInvestimentoSolarC', value);
  }

  // --- State Initialization and Update Helpers (Adapted from Opportunity Page) ---
  void _initializeEditState(DetailedSalesforceProposal proposal) {
    _originalProposal = proposal;
    _editedProposal = proposal.copyWith();
    _selectedSolution = _editedProposal?.soluOC ?? '--Nenhum --';
    _selectedStatus = _editedProposal?.statusC ?? '--Nenhum --';
    _controllers.forEach((field, controller) {
      final value = _editedProposal?.toJson()[field];
      controller.text = value?.toString() ?? '';
    });
    // Add listener for valorInvestimentoSolarC
    _controllers['valorInvestimentoSolarC']?.removeListener(_valorListener);
    _controllers['valorInvestimentoSolarC']?.addListener(_valorListener);
  }

  void _updateEditedProposalField(String field, dynamic value) {
    if (!_isEditing || _editedProposal == null) return;
    setState(() {
      switch (field) {
        case 'valorInvestimentoSolarC':
          _editedProposal = _editedProposal!.copyWith(
            valorInvestimentoSolarC: _parseDouble(value),
          );
          break;
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
    final valueToSave = (value == '--Nenhum --') ? null : value;

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

  // --- SHARED INPUT DECORATION (from admin_opportunity_submission_page.dart) ---

  // Update the save method to use success dialog
  Future<void> _saveEdit() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // Basic Validation
    final nameController = _controllers['name'];
    if (nameController != null && nameController.text.trim().isEmpty) {
        if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O nome da proposta não pode estar vazio.')),
      );
      setState(() => _isSaving = false);
      return;
    }

      // Get current data and auth state
      final currentData = _getCurrentProviderData();
      final authNotifier = ref.read(salesforceAuthProvider.notifier);
      final authState = ref.read(salesforceAuthProvider);

      if (currentData == null || _editedProposal == null) {
        if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: Dados não disponíveis para guardar.')),
      );
      setState(() => _isSaving = false);
      return;
    }

    if (authState != SalesforceAuthState.authenticated) {
        if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: Não autenticado com o Salesforce.')),
      );
      setState(() => _isSaving = false);
      return;
    }

      // Get tokens
    final String? accessToken = await authNotifier.getValidAccessToken();
    final String? instanceUrl = authNotifier.currentInstanceUrl;

    if (accessToken == null || instanceUrl == null) {
        if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: Não foi possível obter as credenciais do Salesforce.')),
      );
      setState(() => _isSaving = false);
      return;
    }

      // Process changes
      final proposalService = ref.read(salesforceProposalServiceProvider);
      final filesToDelete = List<ProposalFile>.from(_filesToDelete);
      final filesToAdd = List<PlatformFile>.from(_filesToAdd);

      // Clear state lists
    _filesToDelete.clear();
    _filesToAdd.clear();

      // Process file deletions
      if (filesToDelete.isNotEmpty) {
        await Future.wait(
          filesToDelete.map((file) async {
            try {
              await proposalService.deleteFile(
                accessToken: accessToken,
                instanceUrl: instanceUrl,
                contentDocumentId: file.id,
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Falha ao eliminar ficheiro: ${file.title}'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }),
        );
      }

      // Process file uploads
      if (filesToAdd.isNotEmpty) {
        await Future.wait(
          filesToAdd.map((file) async {
            if (file.bytes == null) return;
            try {
              final contentDocId = await proposalService.uploadFile(
                accessToken: accessToken,
                instanceUrl: instanceUrl,
                parentId: widget.proposalId,
                fileName: file.name,
                fileBytes: file.bytes!,
              );
              if (contentDocId == null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Falha ao carregar ficheiro: ${file.name}'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erro ao carregar ficheiro: ${file.name}'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }),
        );
      }

      // Update proposal fields if changed
      final fieldsToUpdate = _getFieldsToUpdate(currentData);
      if (fieldsToUpdate.isNotEmpty) {
        await proposalService.updateProposal(
          accessToken: accessToken,
          instanceUrl: instanceUrl,
          proposalId: widget.proposalId,
          fieldsToUpdate: fieldsToUpdate,
        );
      }

      // Handle success with dialog
      if (!mounted) return;
      await showSuccessDialog(
        context: context,
        message: 'Alterações guardadas com sucesso!',
        onDismissed: () {
          _refreshData();
      setState(() {
        _isEditing = false;
            _editedProposal = null;
      });
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao guardar alterações: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Helper method to get fields to update
  Map<String, dynamic> _getFieldsToUpdate(DetailedSalesforceProposal original) {
    final Map<String, dynamic> fieldsToUpdate = {};
    final originalJson = original.toJson();
    final editedJson = _editedProposal!.toJson();

    _fieldApiNameMapping.forEach((modelFieldKey, apiName) {
      final originalValue = originalJson[modelFieldKey];
      final editedValue = editedJson[modelFieldKey];

      final effectiveEditedValue = (editedValue is String && editedValue.isEmpty) ? null : editedValue;
      final effectiveOriginalValue = (originalValue is String && originalValue.isEmpty) ? null : originalValue;

      if (effectiveOriginalValue != effectiveEditedValue) {
        fieldsToUpdate[apiName] = effectiveEditedValue;
      }
    });

    return fieldsToUpdate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detailsAsync = ref.watch(proposalDetailsProvider(widget.proposalId));

    // Ensure _selectedSolution and _selectedStatus are initialized
    _selectedSolution ??= '--Nenhum --';
    _selectedStatus ??= '--Nenhum --';

    return detailsAsync.when(
      loading: () => const AppLoadingIndicator(),
      error: (error, stack) => Scaffold(
        body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading proposal details:\n$error',
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
            ),
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

        return Scaffold(
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
                    child: Row(
                      children: [
                        // Left spacer for symmetry
                        SizedBox(width: _isEditing ? 100 : 56), // Account for button width
                        // Title in the center with flex
                        Expanded(
                          child: Text(
                            displayProposal.name,
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
                                  color: _isEditing ? theme.colorScheme.error : theme.colorScheme.primary,
                                  size: 28,
                                ),
                                tooltip: _isEditing ? 'Cancelar Edição' : 'Editar',
                                onPressed: _isEditing ? _cancelEdit : _startEdit,
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
                                        backgroundColor: Colors.transparent,
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
                        // --- Section 1: Informação da Entidade (Double Column in Edit Mode) ---
                        _buildUserDetailSectionTwoColumn(context, 'Informação da Entidade', [
                          [
                            AppInputField(controller: TextEditingController(text: displayProposal.entidadeName ?? displayProposal.entidadeId ?? 'N/A'), label: 'Entidade', readOnly: true),
                            AppInputField(controller: TextEditingController(text: displayProposal.nifC ?? 'N/A'), label: 'NIF', readOnly: true),
                          ],
                          [
                            AppInputField(controller: TextEditingController(text: displayProposal.oportunidadeName ?? displayProposal.oportunidadeId ?? 'N/A'), label: 'Oportunidade', readOnly: true),
                          ],
              ]),
              SizedBox(height: _isEditing ? 16 : 8),
                        // --- Section 2: Informação da Proposta (Double Column in Edit Mode) ---
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
                                        children: [
                                          AppInputField(controller: TextEditingController(text: displayProposal.name), label: 'Proposta', readOnly: true),
                                          const SizedBox(height: 8),
                            _isEditing
                                            ? AppDropdownField<String>(
                                                label: 'Status',
                                                value: _statusOptions.contains(_selectedStatus) ? _selectedStatus : _statusOptions.first,
                                                items: _statusOptions.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                                                onChanged: (v) { setState(() { _selectedStatus = v; _updateEditedProposalDropdownField('statusC', v); }); },
                                              )
                                            : AppInputField(
                                                controller: TextEditingController(text: displayProposal.statusC ?? 'N/A'),
                                                label: 'Status',
                                                readOnly: true,
                                              ),
                                          SizedBox(height: _isEditing ? 16 : 8),
                            _isEditing
                                            ? AppDropdownField<String>(
                                                label: 'Solução',
                                                value: _solucaoOptions.contains(_selectedSolution) ? _selectedSolution : _solucaoOptions.first,
                                                items: _solucaoOptions.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                                                onChanged: (v) { setState(() { _selectedSolution = v; _updateEditedProposalDropdownField('soluOC', v); }); },
                                              )
                                            : AppInputField(
                                                controller: TextEditingController(text: displayProposal.soluOC ?? 'N/A'),
                                                label: 'Solução',
                                                readOnly: true,
                                              ),
                                          SizedBox(height: _isEditing ? 16 : 8),
                                          AppInputField(controller: _controllers['consumoPeriodoContratoKwhC']!, label: 'Consumo para o período do contrato (KWh)', readOnly: false, onChanged: (v) => _updateEditedProposalField('consumoPeriodoContratoKwhC', v)),
                                          SizedBox(height: 8),
                                          AppInputField(controller: TextEditingController(text: displayProposal.bundleC ?? 'N/A'), label: 'Bundle', readOnly: true),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 32),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          AppInputField(controller: _controllers['valorInvestimentoSolarC']!, label: 'Valor de Investimento Solar', readOnly: false, onChanged: (v) => _updateEditedProposalField('valorInvestimentoSolarC', v)),
                                          SizedBox(height: 8),
                                          AppInputField(controller: TextEditingController(text: displayProposal.dataValidadeC != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(displayProposal.dataValidadeC!)) : 'N/A'), label: 'Data de Validade', readOnly: true),
                                          SizedBox(height: 8),
                                          AppInputField(controller: TextEditingController(text: displayProposal.dataInicioContratoC != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(displayProposal.dataInicioContratoC!)) : 'N/A'), label: 'Data de Início do Contrato', readOnly: true),
                                          SizedBox(height: 8),
                                          AppInputField(controller: TextEditingController(text: displayProposal.dataFimContratoC != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(displayProposal.dataFimContratoC!)) : 'N/A'), label: 'Data de Fim do Contrato', readOnly: true),
                                          SizedBox(height: 8),
                                          AppInputField(controller: TextEditingController(text: displayProposal.dataCriacaoPropostaC ?? 'N/A'), label: 'Data de Criação da Proposta', readOnly: true),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: _isEditing ? 16 : 8),
                                // Energia and Solar checkboxes at the bottom
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Checkbox(
                                      value: _isEditing ? (_editedProposal?.energiaC ?? false) : (displayProposal.energiaC ?? false),
                                      onChanged: _isEditing ? (val) => _updateEditedProposalField('energiaC', val) : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Energia', style: Theme.of(context).textTheme.bodySmall),
                                    const SizedBox(width: 24),
                                    Checkbox(
                                      value: _isEditing ? (_editedProposal?.solarC ?? false) : (displayProposal.solarC ?? false),
                                      onChanged: _isEditing ? (val) => _updateEditedProposalField('solarC', val) : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Solar', style: Theme.of(context).textTheme.bodySmall),
                          ],
                                ),
                              ],
                            ),
                          ),
                        ),
              SizedBox(height: _isEditing ? 16 : 8),
                        // --- Section: Ficheiros ---
                        _buildFilesSection(context, displayProposal.files),
                        const SizedBox(height: 24),
                        // --- Section: Contrato Inserido and Marcar como Expirada (Double Column) ---
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Contrato Inserido Card
                              Expanded(
                                child: Card(
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
                                          'Contrato Inserido?',
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 20,
                                            color: theme.colorScheme.primary,
                                          ),
                                          textAlign: TextAlign.left,
                                        ),
                                        SizedBox(height: _isEditing ? 16 : 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              displayProposal.contratoInseridoC == true ? 'Sim' : 'Não',
                                              style: theme.textTheme.bodyLarge?.copyWith(
                                                color: displayProposal.contratoInseridoC == true ? Colors.green : Colors.red,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (_isEditing)
                                              Checkbox(
                                                value: _editedProposal?.contratoInseridoC ?? false,
                                                onChanged: (val) => _updateEditedProposalField('contratoInseridoC', val),
                                              )
                                            else if (!(displayProposal.contratoInseridoC == true))
                                              Switch(
                                                value: displayProposal.contratoInseridoC == true,
                                                activeColor: theme.colorScheme.primary,
                                                inactiveThumbColor: theme.colorScheme.outline,
                                                trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                                                  if (states.contains(WidgetState.selected)) {
                                                    return theme.colorScheme.primary;
                                                  }
                                                  return theme.colorScheme.outline.withAlpha((255 * 0.5).round());
                                                }),
                                                onChanged: (val) async {
                                                  final confirmed = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: const Text('Confirmar'),
                                                      content: const Text('Tem certeza que deseja marcar o contrato como inserido?'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
                                                        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirmar')),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirmed == true) {
                                                    await _updateContratoInserido(displayProposal.id);
                                                  }
                                                },
                                              )
                                            else
                                              // Add spacing when no switch is shown to maintain consistent height
                                              const SizedBox(width: 60, height: 40),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Marcar como Expirada Card
                              Expanded(
                                child: Card(
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
                                          'Proposta Expirada?',
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 20,
                                            color: theme.colorScheme.primary,
                                          ),
                                          textAlign: TextAlign.left,
                                        ),
                                        SizedBox(height: _isEditing ? 16 : 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              displayProposal.statusC == 'Expirada' ? 'Expirada' : 'Ativa',
                                              style: theme.textTheme.bodyLarge?.copyWith(
                                                color: displayProposal.statusC == 'Expirada' ? Colors.red : Colors.green,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (displayProposal.statusC != 'Expirada')
                                              Switch(
                                                value: false,
                                                activeColor: theme.colorScheme.primary,
                                                inactiveThumbColor: theme.colorScheme.outline,
                                                trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                                                  if (states.contains(WidgetState.selected)) {
                                                    return theme.colorScheme.primary;
                                                  }
                                                  return theme.colorScheme.outline.withAlpha((255 * 0.5).round());
                                                }),
                                                onChanged: (val) async {
                                                  if (!val) return; // Only allow marking as expired, not un-expiring
                                                  await _markProposalAsExpired(context, displayProposal);
                                                },
                                              )
                                            else
                                              // Add spacing when no switch is shown to maintain consistent height
                                              const SizedBox(width: 60, height: 40),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // --- Section 4: Related CPEs ---
                        _buildCpeProposalsSection(context, displayProposal.cpeLinks, iconColor: theme.colorScheme.onSurface),
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

  // --- UI Helper Widgets (Modified for Edit Mode) ---

  Widget _buildUserDetailSectionTwoColumn(BuildContext context, String title, List<List<Widget>> columns) {
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
                    children: columns[0].expand((widget) => [widget, const SizedBox(height: 8)]).toList(),
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: columns[1].expand((widget) => [widget, const SizedBox(height: 8)]).toList(),
                  ),
                ),
              ],
              ),
        ],
      ),
      ),
    );
  }

  // --- Files Section Builder (Refactored to match Opportunity Page) ---
  Widget _buildFilesSection(BuildContext context, List<ProposalFile> files) {
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
                if (!_isEditing)
                  Tooltip(
                    message: 'Revisão de Documentos',
                    child: IconButton(
                      icon: const Icon(Icons.rate_review_outlined, size: 22),
                      onPressed: () => _showDocumentReviewDialog(context, _originalProposal ?? _editedProposal!),
                      color: theme.colorScheme.primary,
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
                    'Sem ficheiros associados a esta proposta.',
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
                  String title;
                  VoidCallback? onTapAction;
                  bool isMarkedForDeletion = false;
    String? fileType;
    String? fileExtension;
    Widget iconWidget;

                  if (item is ProposalFile) {
                    final file = item;
      fileType = file.fileType.toLowerCase();
                    title = file.title;
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
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 8),
                      maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                      ),
              ),
            ),
          ),
          // File removal is not allowed in edit mode
        ],
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

      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _filesToAdd.addAll(result.files.where((file) => file.bytes != null));
        });
        if (result.files.any((file) => file.bytes == null)) {
          if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Some files could not be read.')),
          );
        }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File picking cancelled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e')),
        );
      }
    }
  }

  // --- CPE Proposals Section Builder (Static List View) ---
  Widget _buildCpeProposalsSection(
    BuildContext context,
    List<CpeProposalLink> cpeLinks, {
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CPEs Relacionados',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_link),
              tooltip: 'Adicionar CPE',
              color: theme.colorScheme.primary,
              onPressed: () => _showAddCpeDialog(
                    context,
                    cpeLinks.isNotEmpty ? cpeLinks[0] : null,
            ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (cpeLinks.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                'Sem CPEs associados a esta proposta.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          Column(
            children: cpeLinks.map((cpeLink) {
              // Show the CPE-Proposta name/number if available, otherwise fallback to cpeName or short ID
              final displayName = cpeLink.name ?? cpeLink.cpeName ?? 'CPE-Proposta ${cpeLink.id.substring(cpeLink.id.length - 6)}';
              return SimpleListItem(
                leading: Icon(Icons.link, size: 20, color: iconColor ?? theme.colorScheme.secondary),
                title: displayName,
                onTap: () => context.push('/admin/cpe-proposta/${cpeLink.id}'),
              );
            }).toList(),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposal data incomplete. Cannot add CPE link.'),
        ),
      );
      return;
    }

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AddCpeToProposalDialog(
          proposalId: widget.proposalId,
          accountId: currentData.entidadeId!,
          resellerSalesforceId: currentData.agenteRetailId!,
          nif: currentData.nifC,
        );
      },
    );

    if (!mounted) return;

    if (result == true) {
      _refreshData();
    }
  }

  // --- END: Function to show the dialog --- //

  // Fix unused result warnings
  void _refreshData() {
    final _ = ref.refresh(proposalDetailsProvider(widget.proposalId));
  }

  Future<void> _updateContratoInserido(String proposalId) async {
    try {
      // Get current proposal data to access reseller information
      final currentData = _getCurrentProviderData();
      if (currentData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro: Dados da proposta não disponíveis.')),
          );
        }
        return;
      }

      // Get Salesforce credentials
      final authNotifier = ref.read(salesforceAuthProvider.notifier);
      final authState = ref.read(salesforceAuthProvider);
      
      if (authState != SalesforceAuthState.authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro: Não autenticado com o Salesforce.')),
          );
        }
        return;
      }
      
      final String? accessToken = await authNotifier.getValidAccessToken();
      final String? instanceUrl = authNotifier.currentInstanceUrl;
      
      if (accessToken == null || instanceUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro: Não foi possível obter as credenciais do Salesforce.')),
          );
        }
        return;
      }
      
      // Update Salesforce
      await FirebaseFunctions.instance
          .httpsCallable('updateSalesforceProposal')
          .call({
        'proposalId': proposalId,
        'accessToken': accessToken,
        'instanceUrl': instanceUrl,
        'fieldsToUpdate': {
          'Contrato_inserido__c': true,
          'Status__c': 'Aceite',
        },
      });
      
      // Create notification for reseller after successful Salesforce update
      try {
        if (currentData.agenteRetailId != null) {
          final notificationRepo = NotificationRepository();
          await notificationRepo.createContractInsertionNotification(
            salesforceUserId: currentData.agenteRetailId!,
            proposalId: proposalId,
            proposalName: currentData.name,
            entityName: currentData.entidadeName ?? 'Entidade',
            entityNif: currentData.nifC,
            opportunityId: currentData.oportunidadeId,
          );
          
          if (kDebugMode) {
            print('Contract insertion notification sent to reseller Salesforce ID: ${currentData.agenteRetailId}');
          }
        }
      } catch (notificationError) {
        // Log the notification error but don't block the main flow
        if (kDebugMode) {
          print('Error creating contract insertion notification: $notificationError');
        }
      }
      
      // Refresh the data from provider
      _refreshData();
      
      if (mounted) {
        await showSuccessDialog(
          context: context,
          message: 'Contrato marcado como inserido e status alterado para "Aceite" com sucesso!',
          onDismissed: () {
            // Optional: Any additional action after success dialog
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar: $e')),
        );
      }
    }
  }

  Widget _buildDocumentReviewAndExpirationSection(BuildContext context, DetailedSalesforceProposal proposal) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.rate_review_outlined),
          label: const Text('Revisão de Documentos'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          onPressed: () => _showDocumentReviewDialog(context, proposal),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.hourglass_disabled_outlined),
          label: const Text('Marcar como Expirada'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          onPressed: () => _showMarkAsExpiredDialog(context, proposal),
        ),
      ],
    );
  }

  void _showDocumentReviewDialog(BuildContext context, DetailedSalesforceProposal proposal) {
    showDialog(
      context: context,
      builder: (ctx) => _DocumentReviewDialog(
        proposal: proposal,
        onSend: (Map<String, bool> docStates, String motivo) async {
          final notAccepted = docStates.entries.where((e) => !e.value).map((e) => e.key).toList();
          String message;
          if (notAccepted.isEmpty) {
            message = 'Todos os documentos do cliente ${proposal.entidadeName ?? proposal.entidadeId ?? 'N/D'} foram aceites.';
          } else {
            final docNames = notAccepted.map((doc) {
              switch (doc) {
                case 'identificacao': return 'Documento de Identificação';
                case 'residencia': return 'Prova de Residência';
                case 'certidao': return 'Certidão Permanente';
                default: return doc;
              }
            }).join(', ');
            final motivoText = motivo.isNotEmpty ? ' Motivo: $motivo' : '';
            message = 'Os documentos do cliente ${proposal.entidadeName ?? proposal.entidadeId ?? 'N/D'} precisam de correção: $docNames.$motivoText';
          }
          // Send notification to user (reseller)
          try {
            final notificationRepo = NotificationRepository();
            // Look up Firebase UID from Salesforce ID
            final firebaseUid = await notificationRepo.getFirebaseUidFromSalesforceId(proposal.agenteRetailId ?? '');
            if (firebaseUid == null) throw Exception('Não foi possível encontrar o utilizador associado à proposta.');
            
            await notificationRepo.createNotification(
              userId: firebaseUid,
              title: 'Revisão de Documentos',
              message: message,
              type: NotificationType.statusChange,
              metadata: {
                'proposalId': proposal.id,
                'opportunityId': proposal.oportunidadeId,
                'processType': 'document_review',
              },
            );
            
            if (!mounted) return;
            Navigator.of(context).pop();
            await showSuccessDialog(
              context: context,
              message: 'Notificação enviada com sucesso!',
              onDismissed: () {},
            );
          } catch (e) {
            if (!mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao enviar notificação: $e'), backgroundColor: Theme.of(context).colorScheme.error),
            );
          }
        },
      ),
    );
  }

  void _showMarkAsExpiredDialog(BuildContext context, DetailedSalesforceProposal proposal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Expiração'),
        content: const Text('Tem certeza que deseja marcar esta proposta como expirada?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _markProposalAsExpired(context, proposal);
            },
            child: const Text('Confirmar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _markProposalAsExpired(BuildContext context, DetailedSalesforceProposal proposal) async {
    try {
      // Call Salesforce update function
      final authNotifier = ref.read(salesforceAuthProvider.notifier);
      final authState = ref.read(salesforceAuthProvider);
      if (authState != SalesforceAuthState.authenticated) {
        throw Exception('Não autenticado com o Salesforce.');
      }
      final String? accessToken = await authNotifier.getValidAccessToken();
      final String? instanceUrl = authNotifier.currentInstanceUrl;
      if (accessToken == null || instanceUrl == null) {
        throw Exception('Não foi possível obter as credenciais do Salesforce.');
      }
      final proposalService = ref.read(salesforceProposalServiceProvider);
      await proposalService.updateProposal(
        accessToken: accessToken,
        instanceUrl: instanceUrl,
        proposalId: proposal.id,
        fieldsToUpdate: {'Status__c': 'Expirada'},
      );
      // Send notification to user
      final notificationRepo = NotificationRepository();
      final firebaseUid = await notificationRepo.getFirebaseUidFromSalesforceId(proposal.agenteRetailId ?? '');
      if (firebaseUid == null) throw Exception('Não foi possível encontrar o utilizador associado à proposta.');
                await notificationRepo.createNotification(
            userId: firebaseUid,
            title: 'Proposta Expirada',
            message: 'A proposta do cliente ${proposal.entidadeName ?? proposal.entidadeId ?? 'N/D'} foi marcada como expirada.',
            type: NotificationType.statusChange,
            metadata: {
              'proposalId': proposal.id,
              'opportunityId': proposal.oportunidadeId,
              'processType': 'proposal_expired',
            },
          );
      
      // Refresh the data from provider
      _refreshData();
      
      if (!mounted) return;
      await showSuccessDialog(
        context: context,
        message: 'Proposta marcada como expirada e notificação enviada!',
        onDismissed: () {
          // Optional: Any additional action after success dialog
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao marcar como expirada: $e'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }
}

// Move these classes to the top-level, before or after the main widget class
class _DocumentReviewDialog extends StatefulWidget {
  final DetailedSalesforceProposal proposal;
  final Future<void> Function(Map<String, bool> docStates, String motivo) onSend;
  const _DocumentReviewDialog({required this.proposal, required this.onSend});

  @override
  State<_DocumentReviewDialog> createState() => _DocumentReviewDialogState();
}

class _DocumentReviewDialogState extends State<_DocumentReviewDialog> {
  final Map<String, bool?> _docStates = {
    'identificacao': null,
    'residencia': null,
    'certidao': null,
  };
  final TextEditingController _motivoController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    // Check if any document is marked as "Não" to show motivo section
    final hasRejectedDocs = _docStates.values.any((value) => value == false);
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.all(0),
      title: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 60, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Revisão de Documentos',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (!_sending)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(
                  CupertinoIcons.xmark, 
                  color: colorScheme.onSurface.withAlpha(150),
                  size: 22,
                ),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Fechar',
                splashRadius: 20,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Documentos estão corretos?',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              _buildRadioRow('Documento de Identificação', 'identificacao'),
              const SizedBox(height: 20),
              _buildRadioRow('Prova de Residência', 'residencia'),
              const SizedBox(height: 20),
              _buildRadioRow('Certidão Permanente', 'certidao'),
              if (hasRejectedDocs) ...[
                const SizedBox(height: 28),
                Text(
                  'Motivo (opcional):',
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                AppInputField(
                  controller: _motivoController,
                  label: '',
                  hint: 'Descreva o motivo ou comentário sobre a documentação...',
                  maxLines: 3,
                  minLines: 2,
                  readOnly: false,
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: _sending || _docStates.values.any((v) => v == null)
              ? null
              : () async {
                  setState(() => _sending = true);
                  final docStates = _docStates.map((k, v) => MapEntry(k, v ?? false));
                  await widget.onSend(docStates, _motivoController.text.trim());
                  setState(() => _sending = false);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _sending 
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18, 
                      height: 18, 
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Enviando...'),
                  ],
                )
              : const Text('Enviar Notificação'),
        ),
      ],
    );
  }

  Widget _buildRadioRow(String label, String key) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha((255 * 0.5).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withAlpha((255 * 0.1).round())),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              Radio<bool>(
                value: true,
                groupValue: _docStates[key],
                onChanged: (val) => setState(() => _docStates[key] = val),
                activeColor: colorScheme.primary,
              ),
              Text(
                'Sim',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              Radio<bool>(
                value: false,
                groupValue: _docStates[key],
                onChanged: (val) => setState(() => _docStates[key] = val),
                activeColor: colorScheme.primary,
              ),
              Text(
                'Não',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
