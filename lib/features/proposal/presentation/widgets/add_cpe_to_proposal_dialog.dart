import 'dart:typed_data';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twogether/features/proposal/domain/salesforce_ciclo.dart';
import 'package:twogether/features/proposal/presentation/providers/proposal_providers.dart';
// TODO: Add imports for repository and auth if needed for final submission

class AddCpeToProposalDialog extends ConsumerStatefulWidget {
  final String proposalId;
  final String accountId;
  final String resellerSalesforceId;
  // final String? defaultNif; // Optional default NIF

  const AddCpeToProposalDialog({
    super.key,
    required this.proposalId,
    required this.accountId,
    required this.resellerSalesforceId,
    // this.defaultNif,
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
  late TextEditingController _nifController;
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
    _nifController = TextEditingController(); // Set default NIF if needed
    _consumoController = TextEditingController();
    _fidelizacaoController = TextEditingController();
    _comissaoController = TextEditingController();
  }

  @override
  void dispose() {
    _cpeController.dispose();
    _nifController.dispose();
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
        withData: true, // Ensure bytes are loaded
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachedFiles.addAll(
            result.files.where((file) => file.bytes != null),
          );
          // Optional: Check for duplicates or size limits
        });
      }
    } catch (e) {
      print("Error picking files: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: ${e.toString()}')),
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
  // --- End File Picker Logic ---

  // --- Submit Logic (Placeholder) ---
  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return; // Validation failed
    }

    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. Collect data
      final cpeDetails = {
        'cpe': _cpeController.text.trim(),
        'nif': _nifController.text.trim(),
        'consumo': _consumoController.text.trim(),
        'fidelizacao': _fidelizacaoController.text.trim(),
        'cicloId': _selectedCicloId,
        'comissao': _comissaoController.text.trim(),
      };

      // 2. Prepare file data (example: list of maps with name and base64 content)
      List<Map<String, String>> filesToUpload = [];
      for (var file in _attachedFiles) {
        if (file.bytes != null) {
          filesToUpload.add({
            'fileName': file.name,
            'fileContentBase64': base64Encode(file.bytes!),
          });
        }
      }

      // 3. Get Auth Tokens (needed for actual call)
      // final sfAuthNotifier = ref.read(salesforceAuthNotifierProvider.notifier);
      // final accessToken = sfAuthNotifier.currentAccessToken;
      // final instanceUrl = sfAuthNotifier.currentInstanceUrl;
      // if (accessToken == null || instanceUrl == null) {
      //   throw Exception('Salesforce credentials not available.');
      // }

      // TODO: Call Repository Method (which calls the Cloud Function)
      // await ref.read(salesforceProposalServiceProvider).addCpeToProposal(
      //   proposalId: widget.proposalId,
      //   accountId: widget.accountId,
      //   resellerSalesforceId: widget.resellerSalesforceId,
      //   accessToken: accessToken,
      //   instanceUrl: instanceUrl,
      //   cpeDetails: cpeDetails,
      //   files: filesToUpload,
      // );

      // --- Placeholder ---
      print("--- Submitting CPE Link ---");
      print("Proposal ID: ${widget.proposalId}");
      print("Account ID: ${widget.accountId}");
      print("Reseller SF ID: ${widget.resellerSalesforceId}");
      print("CPE Details: $cpeDetails");
      print("Files to Upload: ${_attachedFiles.map((f) => f.name).toList()}");
      await Future.delayed(const Duration(seconds: 2)); // Simulate network call
      // --- End Placeholder ---

      if (mounted) {
        Navigator.of(
          context,
        ).pop(true); // Close dialog, return true for success
      }
    } catch (e) {
      print("Error submitting CPE link: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add CPE link: ${e.toString()}'),
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
  // --- End Submit Logic ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activationCyclesAsync = ref.watch(activationCyclesProvider);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Adicionar CPE à Proposta',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  _buildInputField('CPE', _cpeController, 'Insira o código CPE'),
                  const SizedBox(height: 16),
                  _buildInputField('NIF', _nifController, 'Insira o NIF'),
                  const SizedBox(height: 16),
                  _buildInputField('Consumo ou Potência Pico', _consumoController, 'kWh ou kVA'),
                  const SizedBox(height: 16),
                  _buildInputField('Período de Fidelização (anos)', _fidelizacaoController, 'Ex: 2'),
                  const SizedBox(height: 16),
                  _buildDropdownField('Ciclo de Ativação', activationCyclesAsync, _selectedCicloId, (val) => setState(() => _selectedCicloId = val)),
                  const SizedBox(height: 16),
                  _buildInputField('Comissão Retail', _comissaoController, '€'),
                  const SizedBox(height: 24),
                  Text('Anexar Ficheiros (Opcional)', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add, size: 24),
                        tooltip: 'Adicionar ficheiros',
                        onPressed: _pickFiles,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _attachedFiles.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final file = entry.value;
                            return Chip(
                              label: Text(file.name, style: theme.textTheme.bodySmall),
                              onDeleted: () => _removeFile(idx),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(100, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Submeter'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String hint) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      style: theme.textTheme.bodySmall,
      validator: (val) => (val == null || val.trim().isEmpty) ? 'Campo obrigatório' : null,
    );
  }

  Widget _buildDropdownField(String label, AsyncValue<List<SalesforceCiclo>> asyncOptions, String? selected, ValueChanged<String?> onChanged) {
    final theme = Theme.of(context);
    return asyncOptions.when(
      data: (options) => DropdownButtonFormField<String>(
        value: selected,
        items: options.map((ciclo) => DropdownMenuItem(
          value: ciclo.id,
          child: Text(ciclo.name, style: theme.textTheme.bodySmall),
        )).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: theme.colorScheme.surfaceVariant,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: theme.textTheme.bodySmall,
      ),
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erro ao carregar ciclos'),
    );
  }
}
