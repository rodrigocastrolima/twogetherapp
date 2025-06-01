import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twogether/features/proposal/domain/salesforce_ciclo.dart';
import 'package:twogether/features/proposal/presentation/providers/proposal_providers.dart';
import '../../../../core/services/salesforce_auth_service.dart';
import '../../../../presentation/widgets/success_dialog.dart';
import '../../../../presentation/widgets/app_input_field.dart';
import '../../../../core/services/file_icon_service.dart';

class AddCpeToProposalDialog extends ConsumerStatefulWidget {
  final String proposalId;
  final String accountId;
  final String resellerSalesforceId;
  final String? nif; // Add NIF parameter

  const AddCpeToProposalDialog({
    super.key,
    required this.proposalId,
    required this.accountId,
    required this.resellerSalesforceId,
    this.nif, // Add NIF parameter
  });

  @override
  ConsumerState<AddCpeToProposalDialog> createState() =>
      _AddCpeToProposalDialogState();
}

class _AddCpeToProposalDialogState
    extends ConsumerState<AddCpeToProposalDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Controllers
  late TextEditingController _cpeController;
  late TextEditingController _consumoController;
  late TextEditingController _fidelizacaoController;
  late TextEditingController _comissaoController;

  // State
  String? _selectedCicloId;
  final List<PlatformFile> _attachedFiles = [];

  @override
  void initState() {
    super.initState();
    _cpeController = TextEditingController();
    _consumoController = TextEditingController();
    _fidelizacaoController = TextEditingController();
    _comissaoController = TextEditingController();
  }

  @override
  void dispose() {
    _cpeController.dispose();
    _consumoController.dispose();
    _fidelizacaoController.dispose();
    _comissaoController.dispose();
    super.dispose();
  }

  // --- File Picker Logic ---
  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachedFiles.addAll(
            result.files.where((file) => file.bytes != null),
          );
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error picking files: $e");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar ficheiros: ${e.toString()}')),
        );
      }
    }
  }

  void _removeFile(int fileIndex) {
    if (fileIndex >= 0 && fileIndex < _attachedFiles.length) {
      setState(() {
        _attachedFiles.removeAt(fileIndex);
      });
    }
  }

  // --- File Preview Widget (matching app style) ---
  Widget _buildFilePreview(BuildContext context, PlatformFile file) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    final fileExtension = (file.extension ?? '').toLowerCase();
    final iconAsset = FileIconService.getIconAssetPath(fileExtension);
    final iconWidget = Image.asset(
      iconAsset,
      width: 30,
      height: 30,
      fit: BoxFit.contain,
    );

    return Tooltip(
      message: file.name,
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
              child: Padding(
                padding: const EdgeInsets.all(4.0),
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
            ),
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((255 * 0.08).round()),
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
                  onPressed: () => _removeFile(_attachedFiles.indexOf(file)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Submit Logic ---
  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. Get Auth Tokens
      final sfAuthNotifier = ref.read(salesforceAuthProvider.notifier);
      final authState = ref.read(salesforceAuthProvider);
      
      if (authState != SalesforceAuthState.authenticated) {
        throw Exception('Autenticação Salesforce necessária.');
      }
      
      final accessToken = await sfAuthNotifier.getValidAccessToken();
      final instanceUrl = sfAuthNotifier.currentInstanceUrl;
      
      if (accessToken == null || instanceUrl == null) {
        throw Exception('Credenciais Salesforce não disponíveis.');
      }

      // 2. Prepare file data  
      List<Map<String, String>> filesToUpload = [];
      for (var file in _attachedFiles) {
        if (file.bytes != null) {
          filesToUpload.add({
            'fileName': file.name,
            'fileContentBase64': base64Encode(file.bytes!),
          });
        }
      }

      // 3. Prepare CPE data
      final cpeItemData = {
        'cpe': _cpeController.text.trim(),
        'nif': widget.nif,
        'consumo': _consumoController.text.trim(),
        'fidelizacao': _fidelizacaoController.text.trim(),
        'cicloId': _selectedCicloId,
        'comissao': _comissaoController.text.trim(),
        'files': filesToUpload,
      };

      // 4. Call Repository Method
      final proposalService = ref.read(salesforceProposalServiceProvider);
      final createdCpeIds = await proposalService.createCpeForProposal(
        accessToken: accessToken,
        instanceUrl: instanceUrl,
        proposalId: widget.proposalId,
        accountId: widget.accountId,
        resellerSalesforceId: widget.resellerSalesforceId,
        cpeItems: [cpeItemData],
      );

      if (kDebugMode) {
        print("Successfully created CPE-Proposta IDs: ${createdCpeIds.join(', ')}");
      }

      if (mounted) {
        // Show success dialog
        await showSuccessDialog(
          context: context,
          message: 'CPE adicionado à proposta com sucesso!',
          onDismissed: () {
            // Close the dialog and return true to indicate success
            Navigator.of(context).pop(true);
          },
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error submitting CPE link: $e");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao adicionar CPE: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final activationCyclesAsync = ref.watch(activationCyclesProvider);

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
                'Adicionar CPE à Proposta',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (!_isSubmitting)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(
                  CupertinoIcons.xmark, 
                  color: colorScheme.onSurface.withAlpha(150),
                  size: 22,
                ),
                onPressed: () => Navigator.of(context).pop(false),
                tooltip: 'Fechar',
                splashRadius: 20,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Two-column layout for input fields
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildInputField('CPE', _cpeController, 'Código CPE'),
                          const SizedBox(height: 16),
                          _buildInputField('Consumo ou Potência Pico', _consumoController, 'kWh ou kVA'),
                          const SizedBox(height: 16),
                          _buildDropdownField('Ciclo de Ativação', activationCyclesAsync),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          _buildReadOnlyField('NIF', widget.nif),
                          const SizedBox(height: 16),
                          _buildInputField('Período de Fidelização', _fidelizacaoController, 'Anos'),
                          const SizedBox(height: 16),
                          _buildInputField('Comissão Retail', _comissaoController, '€'),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // --- Files Section (matching app style) ---
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
                            IconButton(
                              icon: const Icon(Icons.add),
                              tooltip: 'Adicionar Ficheiro',
                              onPressed: _pickFiles,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_attachedFiles.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20.0),
                              child: Text(
                                'Nenhum ficheiro selecionado.',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: _attachedFiles.map((file) {
                              return _buildFilePreview(context, file);
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submitForm,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: _isSubmitting
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.onPrimary,
                    ),
                  ),
                )
              : Text(
                  'Submeter',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: colorScheme.onPrimary,
                  ),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String hint) {
    return AppInputField(
      controller: controller,
      label: label,
      hint: hint,
      readOnly: false,
      validator: (val) => (val == null || val.trim().isEmpty) ? 'Campo obrigatório' : null,
    );
  }

  Widget _buildReadOnlyField(String label, String? value) {
    return AppInputField(
      controller: TextEditingController(text: value ?? ''),
      label: label,
      readOnly: true,
    );
  }

  Widget _buildDropdownField(String label, AsyncValue<List<SalesforceCiclo>> asyncOptions) {
    final theme = Theme.of(context);
    return asyncOptions.when(
      data: (options) => AppDropdownField<String>(
        label: label,
        value: _selectedCicloId,
        items: options.map((ciclo) => DropdownMenuItem(
          value: ciclo.id,
          child: Text(ciclo.name),
        )).toList(),
        onChanged: (val) => setState(() => _selectedCicloId = val),
        validator: (val) => val == null ? 'Campo obrigatório' : null,
      ),
      loading: () => const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(
        height: 56,
        child: Center(
          child: Text(
            'Erro ao carregar ciclos',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ),
    );
  }
}
