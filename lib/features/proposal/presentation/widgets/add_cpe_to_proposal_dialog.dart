import 'dart:typed_data';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twogether/features/proposal/domain/salesforce_ciclo.dart';
import 'package:twogether/features/proposal/presentation/providers/proposal_providers.dart';
import '../../../../core/services/salesforce_auth_service.dart';
import '../../../../presentation/widgets/success_dialog.dart';
// TODO: Add imports for repository and auth if needed for final submission

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
  List<PlatformFile> _attachedFiles = [];

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

  // --- INPUT DECORATION (matching app style) ---
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
      labelStyle: textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant, 
        fontWeight: FontWeight.w500
      ),
      hintText: hint,
      hintStyle: textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant.withAlpha((255 * 0.7).round())
      ),
      filled: true,
      fillColor: readOnly 
        ? colorScheme.surfaceVariant.withAlpha((255 * 0.7).round())
        : colorScheme.surfaceVariant,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.outline.withAlpha((255 * 0.2).round())
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: suffixIcon,
    );
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
      print("Error picking files: $e");
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
    
    final fileExtension = (file.extension ?? '').toLowerCase();
    Widget iconWidget;
    
    if (["png", "jpg", "jpeg", "gif", "bmp", "webp", "heic"].contains(fileExtension)) {
      iconWidget = Icon(Icons.image_outlined, color: colorScheme.primary, size: 30);
    } else if (fileExtension == "pdf") {
      iconWidget = Icon(Icons.picture_as_pdf, color: colorScheme.error, size: 30);
    } else {
      iconWidget = Icon(Icons.insert_drive_file, color: colorScheme.onSurfaceVariant, size: 30);
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
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Center(child: iconWidget),
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () => _removeFile(_attachedFiles.indexOf(file)),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: colorScheme.onError,
                  ),
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

      print("Successfully created CPE-Proposta IDs: ${createdCpeIds.join(', ')}");

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
      print("Error submitting CPE link: $e");
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ficheiros',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: TextFormField(
        controller: controller,
        style: theme.textTheme.bodySmall,
        decoration: _inputDecoration(label: label, hint: hint),
        validator: (val) => (val == null || val.trim().isEmpty) ? 'Campo obrigatório' : null,
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String? value) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: TextFormField(
        initialValue: value ?? '',
        readOnly: true,
        style: theme.textTheme.bodySmall,
        decoration: _inputDecoration(label: label, readOnly: true),
      ),
    );
  }

  Widget _buildDropdownField(String label, AsyncValue<List<SalesforceCiclo>> asyncOptions) {
    final theme = Theme.of(context);
    return asyncOptions.when(
      data: (options) => SizedBox(
        height: 56,
        child: DropdownButtonFormField<String>(
          value: _selectedCicloId,
          decoration: _inputDecoration(label: label),
          items: options.map((ciclo) => DropdownMenuItem(
            value: ciclo.id,
            child: Text(ciclo.name, style: theme.textTheme.bodySmall),
          )).toList(),
          onChanged: (val) => setState(() => _selectedCicloId = val),
          style: theme.textTheme.bodySmall,
          isExpanded: true,
          validator: (val) => val == null ? 'Campo obrigatório' : null,
        ),
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
