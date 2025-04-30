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

    return AlertDialog(
      title: const Text('Add CPE Link'), // TODO: l10n
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min, // Important for Dialog content
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- CPE Fields ---
              TextFormField(
                controller: _cpeController,
                decoration: const InputDecoration(
                  labelText: 'CPE',
                ), // TODO: l10n
                validator:
                    (value) =>
                        (value?.trim().isEmpty ?? true)
                            ? 'CPE is required'
                            : null, // TODO: l10n
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nifController,
                decoration: const InputDecoration(
                  labelText: 'NIF',
                ), // TODO: l10n
                validator:
                    (value) =>
                        (value?.trim().isEmpty ?? true)
                            ? 'NIF is required'
                            : null, // TODO: l10n
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _consumoController,
                decoration: const InputDecoration(
                  labelText: 'Consumption or Peak Power',
                ), // TODO: l10n
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^[0-9]*[\.,]?[0-9]*$'),
                  ),
                ],
                validator:
                    (value) =>
                        (value?.trim().isEmpty ?? true)
                            ? 'Consumption/Power is required'
                            : null, // TODO: l10n
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fidelizacaoController,
                decoration: const InputDecoration(
                  labelText: 'Loyalty Period (Years)', // TODO: l10n
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator:
                    (value) =>
                        (value?.trim().isEmpty ?? true)
                            ? 'Loyalty period is required'
                            : null, // TODO: l10n
              ),
              const SizedBox(height: 16),
              // --- Activation Cycle Dropdown ---
              activationCyclesAsync.when(
                data:
                    (cycles) => DropdownButtonFormField<String>(
                      value: _selectedCicloId,
                      hint: const Text('Select Activation Cycle'), // TODO: l10n
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Activation Cycle', // TODO: l10n
                        border: OutlineInputBorder(),
                      ),
                      items:
                          cycles.map((SalesforceCiclo ciclo) {
                            return DropdownMenuItem<String>(
                              value: ciclo.id,
                              child: Text(ciclo.name),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCicloId = newValue;
                        });
                      },
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Activation cycle is required'
                                  : null, // TODO: l10n
                    ),
                loading:
                    () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                error:
                    (err, stack) => TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Activation Cycle', // TODO: l10n
                        hintText: 'Error loading cycles', // TODO: l10n
                        errorText: err.toString(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _comissaoController,
                decoration: const InputDecoration(
                  labelText: 'Retail Commission', // TODO: l10n
                  prefixText: '€ ',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^[0-9]*[\.,]?[0-9]{0,2}$'),
                  ),
                ],
                validator:
                    (value) =>
                        (value?.trim().isEmpty ?? true)
                            ? 'Retail commission is required'
                            : null, // TODO: l10n
              ),
              const SizedBox(height: 24),

              // --- File Upload Section ---
              Text(
                'Attach Files (Optional)',
                style: theme.textTheme.titleSmall,
              ), // TODO: l10n
              const SizedBox(height: 8),
              // Display selected files
              if (_attachedFiles.isNotEmpty)
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: List.generate(_attachedFiles.length, (fileIndex) {
                    final file = _attachedFiles[fileIndex];
                    return Chip(
                      avatar: const CircleAvatar(
                        child: Icon(Icons.insert_drive_file_outlined, size: 16),
                      ),
                      label: Text(file.name, style: theme.textTheme.bodySmall),
                      onDeleted: () => _removeFile(fileIndex),
                      deleteIconColor: theme.colorScheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    );
                  }),
                ),
              if (_attachedFiles.isNotEmpty) const SizedBox(height: 8),
              // Add files button
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file, size: 18),
                label: const Text('Add Files'), // TODO: l10n
                onPressed: _pickFiles,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: theme.textTheme.labelMedium,
                ),
              ),
              // --- End File Upload ---
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // Close without success
          child: const Text('Cancel'), // TODO: l10n
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitForm,
          child:
              _isSubmitting
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Submit'), // TODO: l10n
        ),
      ],
    );
  }
}
