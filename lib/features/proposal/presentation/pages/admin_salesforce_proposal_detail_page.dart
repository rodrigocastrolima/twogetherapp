import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For date/number formatting
import 'package:go_router/go_router.dart'; // If needed later for navigation
import 'package:file_picker/file_picker.dart'; // <-- RESTORED IMPORT
import 'package:flutter/cupertino.dart'; // For CupertinoIcons
import 'package:cloud_functions/cloud_functions.dart';

import '../providers/proposal_providers.dart'; // Provider for proposal details
import '../../data/models/detailed_salesforce_proposal.dart';
import '../../data/models/proposal_file.dart';
import '../../data/models/cpe_proposal_link.dart';
import '../../../../presentation/widgets/secure_file_viewer.dart'; // For viewing files
import '../../../../core/services/salesforce_auth_service.dart'; // For getting credentials on save
import '../widgets/add_cpe_to_proposal_dialog.dart'; // <-- ADDED IMPORT for dialog
import '../../../../presentation/widgets/full_screen_pdf_viewer.dart';
import '../../../../presentation/widgets/full_screen_image_viewer.dart';
import '../../../../presentation/widgets/logo.dart'; // Import LogoWidget
import '../../../../presentation/widgets/app_loading_indicator.dart'; // Import AppLoadingIndicator
import '../../../../presentation/widgets/success_dialog.dart'; // Import SuccessDialog
import '../../../../presentation/widgets/simple_list_item.dart'; // Import SimpleListItem
import '../../../../presentation/widgets/app_input_field.dart'; // Import AppInputField

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
                fileName: file.name!,
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
                    padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Detalhes da Proposta',
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
                              onPressed: _isEditing ? _cancelEdit : _startEdit,
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
                        const SizedBox(height: 16),
                        // --- Section 2: Informação da Proposta (Double Column in Edit Mode) ---
                        _buildUserDetailSectionTwoColumn(context, 'Informação da Proposta', [
                          [
                            AppInputField(controller: TextEditingController(text: displayProposal.name ?? 'N/A'), label: 'Proposta', readOnly: true),
                            AppDropdownField<String>(
                              label: 'Status',
                              value: _statusOptions.contains(_selectedStatus) ? _selectedStatus : _statusOptions.first,
                              items: _statusOptions.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                              onChanged: (v) { setState(() { _selectedStatus = v; _updateEditedProposalDropdownField('statusC', v); }); },
                            ),
                            AppDropdownField<String>(
                              label: 'Solução',
                              value: _solucaoOptions.contains(_selectedSolution) ? _selectedSolution : _solucaoOptions.first,
                              items: _solucaoOptions.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                              onChanged: (v) { setState(() { _selectedSolution = v; _updateEditedProposalDropdownField('soluOC', v); }); },
                            ),
                            AppInputField(controller: _controllers['consumoPeriodoContratoKwhC']!, label: 'Consumo para o período do contrato (KWh)', readOnly: false, onChanged: (v) => _updateEditedProposalField('consumoPeriodoContratoKwhC', v)),
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, bottom: 0.0),
                              child: Row(
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
                            ),
                          ],
                          [
                            AppInputField(controller: _controllers['valorInvestimentoSolarC']!, label: 'Valor de Investimento Solar', readOnly: false, onChanged: (v) => _updateEditedProposalField('valorInvestimentoSolarC', v)),
                            AppInputField(controller: TextEditingController(text: displayProposal.dataValidadeC != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(displayProposal.dataValidadeC!)) : 'N/A'), label: 'Data de Validade', readOnly: true),
                            AppInputField(controller: TextEditingController(text: displayProposal.dataInicioContratoC != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(displayProposal.dataInicioContratoC!)) : 'N/A'), label: 'Data de Início do Contrato', readOnly: true),
                            AppInputField(controller: TextEditingController(text: displayProposal.dataFimContratoC != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(displayProposal.dataFimContratoC!)) : 'N/A'), label: 'Data de Fim do Contrato', readOnly: true),
                            AppInputField(controller: TextEditingController(text: displayProposal.bundleC ?? 'N/A'), label: 'Bundle', readOnly: true),
                            AppInputField(controller: TextEditingController(text: displayProposal.dataCriacaoPropostaC ?? 'N/A'), label: 'Data de Criação da Proposta', readOnly: true),
                          ],
                        ]),
                        const SizedBox(height: 16),
                        // --- Section: Contrato Inserido (Separate Card) ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
                          child: Text(
                            'Marque esta opção quando o contrato estiver inserido no Salesforce.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: theme.dividerColor.withAlpha(25)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Contrato inserido',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      displayProposal.contratoInseridoC == true ? 'Sim' : 'Não',
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        color: displayProposal.contratoInseridoC == true ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_isEditing)
                                  Checkbox(
                                    value: _editedProposal?.contratoInseridoC ?? false,
                                    onChanged: (val) => _updateEditedProposalField('contratoInseridoC', val),
                                  )
                                else if (!(displayProposal.contratoInseridoC == true))
                                  Switch(
                                    value: displayProposal.contratoInseridoC == true,
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
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // --- Section 3: Files (before CPEs) ---
                        _buildFilesSection(context, displayProposal.files),
                        const SizedBox(height: 24),
                        // --- Section 4: Related CPEs ---
                        _buildCpeProposalsSection(context, displayProposal.cpeLinks),
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
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 20, color: theme.colorScheme.primary),
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
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
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
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
                  String title;
                  String subtitle = '';
                  VoidCallback? onTapAction;
                  bool isMarkedForDeletion = false;
    String? fileType;
    String? fileExtension;
    Widget iconWidget;

                  if (item is ProposalFile) {
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
        color: theme.colorScheme.surfaceVariant.withAlpha((255 * 0.7).round()),
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
    List<CpeProposalLink> cpeLinks,
  ) {
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
                leading: Icon(Icons.link, size: 20, color: theme.colorScheme.secondary),
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
    ref.refresh(proposalDetailsProvider(widget.proposalId));
  }

  // Add missing methods
  Widget _buildDetailItem(
    String label,
    dynamic value, {
    String? fieldKey,
    bool isNumeric = false,
    bool isCurrency = false,
  }) {
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
            child: Text(
              displayValue,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    String fieldKey,
    List<String> options,
    String? selectedValue,
  ) {
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
              value ?? 'N/A',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateContratoInserido(String proposalId) async {
    try {
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
      
      // Refresh the data from provider
      ref.refresh(proposalDetailsProvider(widget.proposalId)); // ignore: unused_result
      
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
}
