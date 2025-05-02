import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data'; // For Uint8List
import 'dart:convert'; // For base64Decode

import '../../../../core/theme/theme.dart';
import '../../../features/proposal/presentation/providers/proposal_providers.dart';
import '../../../features/proposal/data/models/get_reseller_proposal_details_result.dart';
import '../../../features/proposal/data/models/salesforce_cpe_proposal_data.dart';
import '../../../features/proposal/data/models/salesforce_proposal_data.dart';
import './submit_proposal_documents_page.dart'; // Import the new page
import '../../../../core/services/salesforce_auth_service.dart'; // For auth provider
import '../../../../core/theme/theme.dart';
import 'package:twogether/presentation/widgets/full_screen_pdf_viewer.dart';
import 'package:twogether/presentation/widgets/full_screen_image_viewer.dart';

class ResellerProposalDetailsPage extends ConsumerWidget {
  final String proposalId;
  final String proposalName; // For AppBar title

  const ResellerProposalDetailsPage({
    super.key,
    required this.proposalId,
    required this.proposalName,
  });

  // Helper to format date strings (YYYY-MM-DD or ISO8601)
  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(dateTime.toLocal());
    } catch (e) {
      return dateString; // Fallback
    }
  }

  // Helper to format currency
  String _formatCurrency(double? value) {
    if (value == null) return 'N/A';
    // TODO: Use proper localization/currency formatting based on app settings
    final format = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    return format.format(value);
  }

  // Helper to format loyalty years
  String _formatYears(double? value) {
    if (value == null) return 'N/A';
    // Display as integer if whole number, otherwise one decimal place
    if (value == value.toInt()) {
      return '${value.toInt()} Ano${value.toInt() == 1 ? '' : 's'}';
    }
    return '${value.toStringAsFixed(1)} Anos';
  }

  // --- ADDED: Helper to determine file type (basic) --- //
  String _getFileTypeFromTitle(String title) {
    final extension = title.split('.').last.toLowerCase();
    if (['pdf'].contains(extension)) return 'pdf';
    if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(extension))
      return 'image';
    return 'unknown'; // Default/fallback type
  }
  // --- END ADDED --- //

  // --- ADDED: Function to handle file tap --- //
  Future<void> _handleFileTap(
    BuildContext context,
    WidgetRef ref,
    SalesforceFileInfo file,
  ) async {
    if (kDebugMode) {
      print('Tapped file - ID: ${file.id}, Title: ${file.title}');
    }

    final scaffoldMessenger = ScaffoldMessenger.of(
      context,
    ); // Capture scaffold messenger
    final navigator = Navigator.of(context); // Capture navigator

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get Salesforce credentials
      final authNotifier = ref.read(salesforceAuthNotifierProvider.notifier);
      final accessToken = authNotifier.currentAccessToken;
      final instanceUrl = authNotifier.currentInstanceUrl;

      if (accessToken == null || instanceUrl == null) {
        throw Exception('Salesforce authentication credentials not found.');
      }

      // Call the Cloud Function
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('downloadFileForReseller');
      final result = await callable.call<Map<String, dynamic>>({
        'contentVersionId': file.id,
      });

      // Close loading indicator
      if (navigator.canPop()) {
        navigator.pop();
      }

      if (result.data['success'] == true && result.data['data'] != null) {
        final fileDataMap = result.data['data'] as Map<String, dynamic>;
        final String base64String = fileDataMap['fileData'] as String;
        final String? contentType = fileDataMap['contentType'] as String?;

        // Decode base64
        Uint8List fileBytes;
        try {
          fileBytes = base64Decode(base64String);
        } catch (e) {
          throw Exception('Failed to decode file data.');
        }

        // Determine file type (prefer contentType, fallback to title)
        String fileType = 'unknown';
        if (contentType != null) {
          if (contentType.contains('pdf'))
            fileType = 'pdf';
          else if (contentType.startsWith('image/'))
            fileType = 'image';
        }
        if (fileType == 'unknown') {
          fileType = _getFileTypeFromTitle(file.title);
        }

        if (kDebugMode) {
          print(
            'File Type: $fileType, Content-Type: $contentType, Size: ${fileBytes.lengthInBytes}',
          );
        }

        // --- Navigate to Viewer --- //
        if (fileType == 'pdf') {
          navigator.push(
            MaterialPageRoute(
              builder:
                  (_) => FullScreenPdfViewer(
                    pdfBytes: fileBytes,
                    pdfName: file.title,
                  ),
            ),
          );
        } else if (fileType == 'image') {
          navigator.push(
            MaterialPageRoute(
              builder:
                  (_) => FullScreenImageViewer(
                    imageBytes: fileBytes,
                    imageName: file.title,
                  ),
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Cannot preview file type: $fileType (${file.title})',
              ),
            ),
          );
          // TODO: Implement alternative action (e.g., share, open external)
        }
        // --- END Navigation --- //
      } else {
        final String errorMsg =
            result.data['error']?.toString() ??
            'Cloud function failed to download file.';
        throw Exception(errorMsg);
      }
    } catch (e) {
      // Close loading indicator on error
      if (navigator.canPop()) {
        navigator.pop();
      }

      String errorMessage;
      if (e is FirebaseFunctionsException) {
        errorMessage = e.message ?? e.code;
        print("Function Error Code: ${e.code}, Details: ${e.details}");
      } else {
        errorMessage = e.toString();
      }
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error getting file: $errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
      if (kDebugMode) {
        print('Error handling file tap: $e');
      }
    }
  }
  // --- END ADDED --- //

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detailsAsync = ref.watch(resellerProposalDetailsProvider(proposalId));

    // Define acceptable statuses for showing Accept/Reject buttons
    // Adjust these based on your actual Salesforce Status__c picklist values
    const actionableStatuses = {
      'Pendente', // Example: Pending
      'Enviada', // Example: Sent
      // Add other statuses where action is allowed
    };

    return Scaffold(
      appBar: AppBar(title: Text(proposalName), centerTitle: true),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          // Display specific error messages if possible
          String errorMessage = 'Erro ao carregar detalhes da proposta.';
          if (error is FirebaseFunctionsException) {
            if (error.code == 'not-found') {
              errorMessage = 'Proposta não encontrada.';
            } else {
              errorMessage = 'Erro de comunicação: ${error.message}';
            }
          } else {
            errorMessage = 'Erro: ${error.toString()}';
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(errorMessage, textAlign: TextAlign.center),
            ),
          );
        },
        data: (proposal) {
          final cpeList = proposal.cpePropostas;
          final bool showActions = actionableStatuses.contains(proposal.status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- START: Conditional Action Buttons ---
                // Only show buttons if the status is 'Enviada' (adjust if needed)
                if (proposal.status == 'Enviada')
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 24.0,
                    ), // Add padding when buttons are shown
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        CupertinoButton(
                          color: Colors.red,
                          child: const Text('Rejeitar'), // TODO: Localize
                          onPressed: () {
                            // --- START: Confirmation Dialog ---
                            showCupertinoDialog(
                              context: context,
                              builder: (BuildContext ctx) {
                                return CupertinoAlertDialog(
                                  title: const Text(
                                    'Confirmar Rejeição',
                                  ), // TODO: Localize
                                  content: const Text(
                                    'Tem a certeza que pretende rejeitar esta proposta?', // TODO: Localize
                                  ),
                                  actions: <Widget>[
                                    CupertinoDialogAction(
                                      child: const Text(
                                        'Cancelar',
                                      ), // TODO: Localize
                                      onPressed: () {
                                        Navigator.of(ctx).pop(); // Close dialog
                                      },
                                    ),
                                    CupertinoDialogAction(
                                      isDestructiveAction: true,
                                      child: const Text(
                                        'Rejeitar',
                                      ), // TODO: Localize
                                      onPressed: () {
                                        Navigator.of(ctx).pop(); // Close dialog
                                        // TODO: Implement Reject action (e.g., call Cloud Function)
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Rejeitar - Não implementado', // TODO: Localize
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                            // --- END: Confirmation Dialog ---
                          },
                        ),
                        CupertinoButton.filled(
                          child: const Text('Aceitar'), // TODO: Localize
                          onPressed: () {
                            // --- START: Navigate to Submit Documents Page ---
                            final cpeList = proposal.cpePropostas ?? [];

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => SubmitProposalDocumentsPage(
                                      proposalId: proposalId,
                                      cpeList: cpeList,
                                    ),
                              ),
                            );
                            // --- END: Navigate to Submit Documents Page ---

                            // Keep SnackBar temporarily if needed for testing, or remove
                            /*
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Aceitar - Não implementado'),
                              ),
                            );
                            */
                            // Example navigation (replace with actual route later)
                            // context.push('/proposal/submit-docs', extra: proposalId);
                          },
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(
                    height: 0,
                  ), // No buttons, no extra space needed initially
                // --- END: Conditional Action Buttons ---

                // Proposal Details Section
                _buildSectionTitle(context, 'Detalhes da Proposta'),
                _buildDetailRow(context, 'Status', proposal.status ?? 'N/A'),
                _buildDetailRow(
                  context,
                  'Data Criação',
                  _formatDate(proposal.createdDate),
                ),
                _buildDetailRow(
                  context,
                  'Data Validade',
                  _formatDate(proposal.expiryDate),
                ),
                const SizedBox(height: 24),

                // CPE List Section
                _buildSectionTitle(context, 'CPEs'),
                if (cpeList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: Text('Nenhum contrato associado.')),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cpeList.length,
                    itemBuilder: (context, index) {
                      final cpe = cpeList[index];
                      return _buildCpeCard(context, cpe);
                    },
                  ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper for Section Titles
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  // Helper for Detail Rows (same as in Opportunity Details)
  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120, // Adjust width as needed
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  // Helper to build a card for each CPE
  Widget _buildCpeCard(BuildContext context, SalesforceCPEProposalData cpe) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CPE ID: ${cpe.id.substring(cpe.id.length - 6)}', // Show last 6 chars of ID
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.secondary,
              ),
            ),
            const Divider(height: 16),
            _buildDetailRow(
              context,
              'Consumo/Potência',
              cpe.consumptionOrPower?.toStringAsFixed(2) ?? 'N/A',
            ),
            _buildDetailRow(
              context,
              'Fidelização',
              _formatYears(cpe.loyaltyYears),
            ),
            _buildDetailRow(
              context,
              'Comissão',
              _formatCurrency(cpe.commissionRetail),
            ),
            // --- ADDED: Display Attached Files --- //
            if (cpe.attachedFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Ficheiros Anexados:', // TODO: Localize
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8.0, // Horizontal space between chips
                runSpacing: 4.0, // Vertical space between lines
                children:
                    cpe.attachedFiles.map((file) {
                      // --- MODIFIED: Use Consumer to get ref for onPressed --- //
                      return Consumer(
                        builder: (context, cardRef, _) {
                          // Use a new ref here
                          return InputChip(
                            avatar: const Icon(Icons.attach_file, size: 16),
                            label: Text(
                              file.title,
                              style: theme.textTheme.bodySmall,
                            ),
                            onPressed:
                                () => _handleFileTap(
                                  context,
                                  cardRef,
                                  file,
                                ), // Pass ref
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          );
                        },
                      );
                      // --- END MODIFICATION --- //
                    }).toList(),
              ),
            ],
            // --- END: Display Attached Files --- //
          ],
        ),
      ),
    );
  }
}
