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

  // List of editable fields (using model property names)
  final List<String> _editableFields = [
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
    // Add mappings for other editable fields as needed
    // Example: 'stageName': 'StageName' (Standard field)
  };
  // --- END: Field Mapping --- //

  @override
  void initState() {
    super.initState();
    // Initial setup of controllers - they will be updated with data when it loads
    for (final field in _editableFields) {
      _controllers[field] = TextEditingController();
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  // Helper to initialize or update controllers and the edited copy
  // Also manages listeners
  void _initializeEditState(DetailedSalesforceOpportunity opportunity) {
    _originalOpportunity = opportunity; // Store the original for cancellation
    _editedOpportunity = opportunity.copyWith();

    // Update controllers with current values and add listeners
    _controllers.forEach((field, controller) {
      final initialValue = _editedOpportunity?.toJson()[field] as String?;
      controller.text = initialValue ?? ''; // Set text, default to empty string

      // Listener function to update the state
      void listener() {
        // Important: Check if still editing and if the controller's value actually changed
        // to avoid unnecessary updates and potential loops.
        final currentValue =
            _editedOpportunity?.toJson()[field] as String? ?? '';
        if (_isEditing && controller.text != currentValue) {
          // Call the update helper
          _updateEditedOpportunityField(field, controller.text);
        }
      }

      // Remove any existing listener first
      try {
        controller.removeListener(listener);
      } catch (_) {
        /* Ignore if listener wasn't attached */
      }

      // Add the listener
      controller.addListener(listener);
    });
  }

  // Separate helper to update the _editedOpportunity state based on field key
  // Called by controller listeners
  void _updateEditedOpportunityField(String field, String value) {
    if (!_isEditing || _editedOpportunity == null) return;
    // Use setState to trigger rebuilds
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
        // Add cases for other editable fields
      }
    });
  }

  // Keep helper methods within the State class
  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateString);
      // Example format: 15 Jan 2024
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
      // Simple parsing: look for color_XXX.gif
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
          // Add more cases if other colors exist
        }
      }
    }

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: indicatorColor,
        borderRadius: BorderRadius.circular(4), // Slightly rounded corners
        border: Border.all(color: Colors.black54, width: 0.5),
      ),
    );
  }
  // --- END: Red Flag Indicator Helper ---

  // --- ADDED: Navigation Helper --- //
  void _navigateToCreateProposal(
    BuildContext context,
    DetailedSalesforceOpportunity opp,
  ) {
    // Validate required IDs before navigating
    if (opp.accountId == null ||
        opp.resellerSalesforceId == null ||
        opp.nifC == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Missing required data to create a proposal.',
          ), // TODO: l10n
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    context.push(
      '/proposal/create', // Make sure this matches your GoRouter route
      extra: {
        'salesforceOpportunityId': opp.id, // Actual ID
        'salesforceAccountId': opp.accountId, // Actual ID
        'accountName': opp.accountName ?? 'N/A', // Pass name, handle null
        'resellerSalesforceId': opp.resellerSalesforceId, // Actual ID
        'resellerName': opp.resellerName ?? 'N/A', // Pass name, handle null
        'nif': opp.nifC, // Pass NIF
        'opportunityName': opp.name, // Pass Opp Name
      },
    );
  }
  // --- END Navigation Helper --- //

  // --- ADDED: Cancel Edit --- //
  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      // Restore original data and update controllers
      if (_originalOpportunity != null) {
        // Re-initialize to reset controllers and remove listeners implicitly
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
    if (_isSaving) return; // Prevent double taps

    setState(() => _isSaving = true);

    // Ensure we have data to compare
    if (_originalOpportunity == null || _editedOpportunity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Data not available to save.'),
        ), // TODO: l10n
      );
      setState(() => _isSaving = false);
      return;
    }

    // Get auth state and notifier
    final authNotifier = ref.read(salesforceAuthProvider.notifier);
    final authState = ref.read(
      salesforceAuthProvider,
    ); // Read the current state enum

    if (authState != SalesforceAuthState.authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Not authenticated.'),
        ), // TODO: l10n
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
        ), // TODO: l10n
      );
      setState(() => _isSaving = false);
      return;
    }

    // --- Prepare data for update --- //
    final Map<String, dynamic> fieldsToUpdate = {};
    final originalJson = _originalOpportunity!.toJson();
    final editedJson = _editedOpportunity!.toJson();
    final List<SalesforceFile> filesToDelete = List.from(
      _filesToDelete,
    ); // Copy list
    final List<PlatformFile> filesToAdd = List.from(_filesToAdd); // Copy list

    // Clear the state lists immediately to prevent duplicates if save fails/retries
    _filesToDelete.clear();
    _filesToAdd.clear();

    // Compare editable fields and add changed ones to the map
    for (final fieldKey in _editableFields) {
      final apiName = _fieldApiNameMapping[fieldKey];
      if (apiName == null) {
        print(
          "Warning: No API name mapping found for field '$fieldKey'",
        ); // Log missing mapping
        continue; // Skip fields without mapping
      }

      final originalValue = originalJson[fieldKey];
      final editedValue = editedJson[fieldKey];

      // Handle nulls and empty strings potentially needing to be sent as null
      final effectiveEditedValue =
          (editedValue is String && editedValue.isEmpty) ? null : editedValue;

      if (originalValue != effectiveEditedValue) {
        // Ensure value is not null before adding for standard fields like Name
        if (apiName == 'Name' && effectiveEditedValue == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opportunity Name cannot be empty.'),
            ), // TODO: l10n
          );
          setState(() => _isSaving = false);
          return;
        }
        fieldsToUpdate[apiName] = effectiveEditedValue;
      }
    }
    // REMOVED TODO: Add logic for changed files (uploads/deletions)

    // --- Check if anything changed --- //
    final bool filesChanged =
        filesToAdd.isNotEmpty || filesToDelete.isNotEmpty; // Use copied lists
    if (fieldsToUpdate.isEmpty && !filesChanged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes detected.')), // TODO: l10n
      );
      setState(() {
        _isEditing = false; // Exit edit mode even if no changes
        _isSaving = false;
      });
      return;
    }

    // --- Call the service --- //
    try {
      // Get the service instance
      final opportunityService = ref.read(salesforceOpportunityServiceProvider);

      // --- Process File Deletions --- //
      if (filesToDelete.isNotEmpty) {
        print("Deleting ${filesToDelete.length} files...");
        // Use Future.wait for concurrent deletions (optional, can be sequential)
        await Future.wait(
          filesToDelete.map((file) async {
            try {
              await opportunityService.deleteFile(
                accessToken: accessToken,
                instanceUrl: instanceUrl,
                contentDocumentId: file.id, // Use SalesforceFile ID
              );
              print("Deleted file: ${file.title}");
            } catch (e) {
              print("Error deleting file ${file.title}: $e");
              // Collect errors? Show specific message? For now, just log.
              // Re-add to state list if failed?
              // ScopedMessenger... show snackbar
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
              return; // Skip if bytes are somehow null
            }
            try {
              final contentDocId = await opportunityService.uploadFile(
                accessToken: accessToken,
                instanceUrl: instanceUrl,
                parentId: widget.opportunityId, // Link to this opportunity
                fileName: file.name,
                fileBytes: file.bytes!, // We ensured bytes are not null
                // mimeType: lookupMimeType(file.name), // Optional: use mime package
              );
              if (contentDocId != null) {
                print("Uploaded file: ${file.name} (ID: $contentDocId)");
              } else {
                print(
                  "Upload failed for file: ${file.name} (Service returned null)",
                );
                // Handle upload failure - maybe show specific error
              }
            } catch (e) {
              print("Error uploading file ${file.name}: $e");
              // Handle upload failure - maybe show specific error
            }
          }),
        );
      }

      // --- Update Opportunity Fields (if changed) --- //
      if (fieldsToUpdate.isNotEmpty) {
        print("Updating opportunity fields...");
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
        const SnackBar(
          content: Text('Changes saved successfully!'),
        ), // TODO: l10n
      );

      // Refresh the data and exit edit mode
      ref.refresh(opportunityDetailsProvider(widget.opportunityId));
      setState(() {
        _isEditing = false;
        // _originalOpportunity gets updated automatically by the refresh/rebuild
      });
    } catch (e) {
      // --- Handle Error --- //
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update opportunity: $e'), // TODO: l10n
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      // --- Always reset saving state --- //
      if (mounted) {
        // Check if widget is still in tree
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Removed WidgetRef from here
    final theme = Theme.of(context);
    // Access widget's opportunityId using widget.opportunityId
    final detailsAsync = ref.watch(
      opportunityDetailsProvider(widget.opportunityId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Opportunity' : 'Opportunity Details',
        ), // Dynamic title
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
              onPressed: _isSaving ? null : _cancelEdit, // Disable when saving
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
              onPressed: _isSaving ? null : _saveEdit, // Disable when saving
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit', // TODO: l10n
              onPressed: () {
                // Get the current data before entering edit mode
                final currentData =
                    ref
                        .read(opportunityDetailsProvider(widget.opportunityId))
                        .asData
                        ?.value;
                if (currentData != null) {
                  _initializeEditState(currentData);
                  setState(() {
                    _isEditing = true;
                  });
                } else {
                  // Handle case where data isn't loaded yet
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Data not loaded yet. Please wait.'),
                    ), // TODO: l10n
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
                  'Error loading details: \n$error',
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        data: (opportunityDetails) {
          // Initialize state when data first loads or if it changes
          // Avoid re-initializing if already editing to preserve user input
          if (_originalOpportunity == null ||
              opportunityDetails.id != _originalOpportunity!.id) {
            // Use WidgetsBinding.instance.addPostFrameCallback to avoid calling setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // Check if the state is still mounted
                _initializeEditState(opportunityDetails);
                // No need for setState here as it's post-frame and build will run again if needed
              }
            });
          }

          // Determine which opportunity data to display (original or edited)
          final DetailedSalesforceOpportunity displayOpportunity =
              (_isEditing ? _editedOpportunity : opportunityDetails) ??
              opportunityDetails; // Fallback just in case

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
                _buildDetailItem(
                  'Entidade',
                  displayOpportunity.accountName,
                ), // Read-only for now
                // Assuming 'Nome Entidade' is the same as accountName for display
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
                ), // Pass maxLines positionally
                _buildDetailItem(
                  'Motivo da Perda',
                  displayOpportunity.motivoDaPerda,
                  'motivoDaPerda',
                ),
                _buildDetailItem(
                  'Qualificação concluída',
                  _formatBool(displayOpportunity.qualificacaoConcluida),
                ),
                // Red Flag is read-only
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.center, // Center align vertically
                    children: [
                      SizedBox(
                        width: 150, // Match width of _buildDetailItem label
                        child: Text(
                          'Red Flag:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      _buildRedFlagIndicator(
                        displayOpportunity.redFlag,
                      ), // Call the helper
                    ],
                  ),
                ),
                // --- End Custom Red Flag ---
              ]),
              const SizedBox(height: 16),

              // --- Section 2: Metainformação da Oportunidade ---
              _buildDetailSection(context, 'Metainformação da Oportunidade', [
                _buildDetailItem(
                  'Data de Criação da Oportunidade',
                  _formatDate(displayOpportunity.dataDeCriacaoDaOportunidadeC),
                ),
                _buildDetailItem('NIF', displayOpportunity.nifC, 'nifC'),
                _buildDetailItem('Fase', displayOpportunity.faseC),
                _buildDetailItem('Fase LDF', displayOpportunity.faseLDF),
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
                ), // Read-only
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
                ), // Actual Close Date
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

  // Helper widget to display a label and value, or a TextField if editing
  Widget _buildDetailItem(
    String label,
    String? value, [
    String? fieldKey,
    int? maxLines,
  ]) {
    final controller = fieldKey != null ? _controllers[fieldKey] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150, // Consistent width for labels
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                (_isEditing &&
                        controller !=
                            null) // Check if editing AND controller exists
                    ? TextFormField(
                      controller: controller,
                      maxLines: maxLines, // Use provided maxLines
                      minLines: 1,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.all(8.0),
                        border: OutlineInputBorder(),
                      ),
                      // Optional: Update _editedOpportunity directly on change
                      // onChanged: (newValue) {
                      //   // Potentially update _editedOpportunity here, but using listeners is often cleaner
                      //   if (_editedOpportunity != null) {
                      //     // Use copyWith based on fieldKey
                      //   }
                      // },
                    )
                    : Text(
                      value ?? 'N/A',
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines:
                          maxLines, // Use provided maxLines for Text as well
                      overflow: TextOverflow.visible, // Allow text to wrap
                    ),
          ),
        ],
      ),
    );
  }

  // --- NEW: Files Section Builder ---
  Widget _buildFilesSection(BuildContext context, List<SalesforceFile> files) {
    final theme = Theme.of(context);
    // Combine original files (minus deleted) with newly added ones for display
    final List<dynamic> displayedItems = [
      // Existing files not marked for deletion
      ...files.where((f) => !_filesToDelete.contains(f)),
      // Newly added files (PlatformFile)
      ..._filesToAdd,
    ];

    // Helper function to get file icon
    IconData getFileIcon(String fileTypeOrExtension) {
      final type = fileTypeOrExtension.toLowerCase();
      if (type == 'pdf') {
        return Icons.picture_as_pdf_outlined;
      }
      if (['png', 'jpg', 'jpeg', 'gif', 'bmp'].contains(type)) {
        return Icons.image_outlined;
      }
      if (['doc', 'docx'].contains(type)) {
        return Icons.description_outlined;
      }
      if (['xls', 'xlsx'].contains(type)) {
        return Icons.table_chart_outlined;
      }
      if (['ppt', 'pptx'].contains(type)) {
        return Icons.slideshow_outlined;
      }
      if (type == 'zip') {
        return Icons.folder_zip_outlined;
      }
      return Icons.insert_drive_file_outlined; // Default file icon
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
            // --- Title Row with Add Button (Edit Mode) --- //
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
                    onPressed: _pickFiles, // Implement this method
                  ),
              ],
            ),
            // --- End Title Row --- //
            const SizedBox(height: 12),
            if (displayedItems.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    'No files linked to this opportunity.', // TODO: l10n
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
                    // Existing File
                    final file = item;
                    icon = getFileIcon(file.fileType);
                    title = file.title;
                    subtitle = file.fileType.toUpperCase();
                    isMarkedForDeletion = _filesToDelete.contains(file);

                    // --- UPDATED: onTapAction navigates to SecureFileViewer ---
                    onTapAction = () {
                      if (isMarkedForDeletion)
                        return; // Don't open if marked for deletion

                      // Navigate to the new SecureFileViewer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => SecureFileViewer(
                                contentVersionId:
                                    file.contentVersionId, // Pass the ContentVersion ID
                                title: file.title, // Pass the title
                                fileType:
                                    file.fileType, // Pass the fileType hint
                              ),
                          fullscreenDialog: true,
                        ),
                      );
                    };
                    // --- END UPDATE ---
                  } else if (item is PlatformFile) {
                    // New File (PlatformFile from file_picker)
                    final file = item;
                    icon = getFileIcon(file.extension ?? '');
                    title = file.name;
                    subtitle =
                        '${((file.size / 1024 * 100).round() / 100)} KB'; // Show size
                    onTapAction = null; // No action for newly added files yet
                  } else {
                    // Should not happen
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
                      // Disable tap in edit mode for existing files, otherwise use defined action
                      onTap: _isEditing ? null : onTapAction,
                      trailing:
                          _isEditing
                              ? IconButton(
                                icon:
                                    item is SalesforceFile
                                        ? Icon(
                                          isMarkedForDeletion
                                              ? Icons
                                                  .undo // Option to un-delete
                                              : Icons.delete_outline,
                                          color:
                                              isMarkedForDeletion
                                                  ? Colors.orange
                                                  : Colors.red,
                                        )
                                        : const Icon(
                                          Icons.cancel_outlined,
                                          color: Colors.red,
                                        ), // Remove newly added file
                                tooltip:
                                    item is SalesforceFile
                                        ? (isMarkedForDeletion
                                            ? 'Undo Delete'
                                            : 'Mark for Deletion')
                                        : 'Remove File', // TODO: l10n
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
  // --- END: Files Section Builder ---

  // --- ADDED: File Picker Logic ---
  Future<void> _pickFiles() async {
    // Implement file picking using file_picker package
    // print("Placeholder: _pickFiles called");
    // Example (requires file_picker dependency and import):
    try {
      // Ensure bytes are read for potential web compatibility and direct upload
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true, // Read file bytes into memory
        type:
            FileType
                .any, // Or specify allowed types: FileType.custom(allowedExtensions: ['pdf', 'png', 'jpg'])
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          // Filter out files without bytes (shouldn't happen with withData: true)
          _filesToAdd.addAll(result.files.where((file) => file.bytes != null));
          // Optional: Check for duplicates before adding
          // Optional: Limit total number or size of files
        });
        if (result.files.any((file) => file.bytes == null)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Some files could not be read.'),
            ), // TODO: l10n
          );
        }
      } else {
        // User canceled the picker
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File picking cancelled.'),
            ), // TODO: l10n
          );
        }
      }
    } catch (e) {
      print("Error picking files: $e");
      if (mounted) {
        // Check mount status before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e')), // TODO: l10n
        );
      }
    }
  }
  // --- END: File Picker Logic ---

  // --- Updated Proposals Section Builder (accepts full opportunity) ---
  Widget _buildProposalsSection(
    BuildContext context,
    DetailedSalesforceOpportunity opportunityDetails,
  ) {
    final theme = Theme.of(context);
    final proposals =
        opportunityDetails.proposals; // Get proposals from the object
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Title Row with Add Button ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Related Proposals', // TODO: l10n
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 24), // Plus icon
              tooltip: 'Create Proposal', // TODO: l10n
              visualDensity: VisualDensity.compact, // Make it less bulky
              padding: EdgeInsets.zero, // Remove default padding
              splashRadius: 24,
              color: theme.colorScheme.primary, // Use primary color
              onPressed:
                  () => _navigateToCreateProposal(
                    context,
                    opportunityDetails, // Use the passed object
                  ),
            ),
          ],
        ),
        // --- End Title Row ---
        const SizedBox(height: 12),
        if (proposals.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                'No proposals linked to this opportunity.', // TODO: l10n
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          // Wrap Proposals List in Card for consistency
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: theme.dividerColor.withAlpha(25)),
            ),
            margin: EdgeInsets.zero, // Remove default margin if inside Column
            clipBehavior: Clip.antiAlias, // Clip content
            child: ListView.builder(
              shrinkWrap: true, // Important inside ListView
              physics:
                  const NeverScrollableScrollPhysics(), // Disable scrolling for inner list
              itemCount: proposals.length,
              padding: EdgeInsets.zero, // Remove padding for inner list
              itemBuilder: (context, index) {
                final proposal = proposals[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.description_outlined,
                    size: 20,
                    color: theme.colorScheme.secondary,
                  ),
                  title: Text(proposal.name),
                  // Add subtitle later if more fields are needed (e.g., status)
                  // subtitle: Text('Status: ${proposal.status ?? "N/A"}'),
                  onTap: () {
                    // TODO: Navigate to Proposal Detail Page (if applicable)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Proposal detail view not implemented yet.',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
