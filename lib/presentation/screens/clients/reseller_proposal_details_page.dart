import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data'; // For Uint8List
import 'dart:convert'; // For base64Decode AND jsonEncode/Decode

import '../../../../core/theme/theme.dart';
import '../../../features/proposal/presentation/providers/proposal_providers.dart';
import '../../../features/proposal/data/models/get_reseller_proposal_details_result.dart';
import '../../../features/proposal/data/models/salesforce_cpe_proposal_data.dart';
import '../../../features/proposal/data/models/salesforce_proposal_data.dart';
import './submit_proposal_documents_page.dart'; // Import the new page
import '../../../../core/services/salesforce_auth_service.dart'; // For auth provider
import 'package:twogether/presentation/widgets/full_screen_pdf_viewer.dart';
import 'package:twogether/presentation/widgets/full_screen_image_viewer.dart';
import '../../widgets/logo.dart'; // Added for LogoWidget
import '../../../features/auth/presentation/providers/auth_provider.dart'; // Corrected import for currentUserProvider
import '../../../features/notifications/data/repositories/notification_repository.dart'; // Corrected import for notificationRepositoryProvider

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

  // --- ADDED: Helper for file icons ---
  IconData _getFileIcon(String fileName, ThemeData theme) {
    final extension = fileName.split('.').last.toLowerCase();
    if (extension == 'pdf') {
      return CupertinoIcons.doc_text_fill;
    } else if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(extension)) {
      return CupertinoIcons.photo_fill;
    } else if (['doc', 'docx'].contains(extension)) {
      return CupertinoIcons.doc_richtext;
    } else if (['xls', 'xlsx', 'csv'].contains(extension)) {
      return CupertinoIcons.table_fill;
    } else if (['ppt', 'pptx'].contains(extension)) {
      return CupertinoIcons
          .chart_pie_fill; // Using pie chart as a placeholder for presentations
    }
    return CupertinoIcons.paperclip; // General attachment icon
  }
  // --- END ADDED ---

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
      // Get Salesforce credentials - REMOVED, handled by JWT in function
      // final authNotifier = ref.read(salesforceAuthNotifierProvider.notifier);
      // final accessToken = authNotifier.currentAccessToken;
      // final instanceUrl = authNotifier.currentInstanceUrl;

      // if (accessToken == null || instanceUrl == null) {
      //   throw Exception('Salesforce authentication credentials not found.');
      // }

      // Call the Cloud Function (which uses JWT auth internally)
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('downloadFileForReseller');
      final result = await callable.call<Map<String, dynamic>>({
        'contentVersionId': file.id,
      });

      // --- DEFERRED POPPING DIALOG ---
      // // Close loading indicator
      // if (navigator.canPop()) {
      //   navigator.pop();
      // }
      // --- END DEFERRED ---

      if (result.data['success'] == true && result.data['data'] != null) {
        // Apply jsonEncode/Decode to fix typing
        final jsonString = jsonEncode(result.data['data']);
        final fileDataMap = jsonDecode(jsonString) as Map<String, dynamic>?;

        if (fileDataMap == null) {
          throw Exception('Failed to process file data after JSON conversion.');
        }

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

        // --- Pop dialog BEFORE navigating ---
        if (navigator.canPop()) {
          navigator.pop(); // Close loading indicator *now*
        }
        // --- END POP ---

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
          // --- Pop dialog if navigating failed or unknown type ---
          if (navigator.canPop()) {
            navigator.pop(); // Ensure pop if we don't navigate
          }
          // --- END POP ---
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
        // --- Pop dialog on function failure ---
        if (navigator.canPop()) {
          navigator.pop(); // Close loading indicator
        }
        // --- END POP ---
        final String errorMsg =
            result.data['error']?.toString() ??
            'Cloud function failed to download file.';
        throw Exception(errorMsg);
      }
    } catch (e) {
      // Close loading indicator on error
      if (navigator.canPop()) {
        navigator.pop(); // Close loading indicator
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
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.chevron_left,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: LogoWidget(
          height: 60,
          darkMode: theme.brightness == Brightness.dark,
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
          // Use ?? [] to ensure cpeList is never null for the UI
          final cpeList = proposal.cpePropostas ?? [];
          final bool showActions = actionableStatuses.contains(proposal.status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Proposal Details Section
                _buildSectionTitle(context, 'Detalhes da Proposta'),
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

                // --- START: Conditional Action Buttons (MOVED HERE) ---
                if (proposal.status == 'Enviada')
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 16.0, // Add some space above buttons
                      bottom: 8.0, // Standard padding at bottom
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          // Added Expanded for flexible width
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ), // Spacing between buttons
                            decoration: BoxDecoration(
                              color:
                                  theme
                                      .cardColor, // Changed to cardColor for white/neutral background
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: CupertinoColors.systemGrey4,
                                width: 1.0,
                              ), // Added subtle border
                            ),
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal:
                                    20, // Adjusted padding for container
                                vertical: 12,
                              ),
                              child: const Text(
                                'Rejeitar',
                                style: TextStyle(
                                  color: CupertinoColors.destructiveRed,
                                  fontWeight:
                                      FontWeight.w600, // Slightly bolder text
                                ),
                              ),
                              onPressed: () {
                                // --- START: Confirmation Dialog ---
                                showCupertinoDialog(
                                  context: context,
                                  builder: (BuildContext ctx) {
                                    return CupertinoAlertDialog(
                                      title: const Text('Confirmar Rejeição'),
                                      content: const Text(
                                        'Tem a certeza que pretende rejeitar esta proposta?',
                                      ),
                                      actions: <Widget>[
                                        CupertinoDialogAction(
                                          child: const Text('Cancelar'),
                                          onPressed: () {
                                            Navigator.of(
                                              ctx,
                                            ).pop(); // Close dialog
                                          },
                                        ),
                                        CupertinoDialogAction(
                                          isDestructiveAction: true,
                                          child: const Text('Rejeitar'),
                                          onPressed: () async {
                                            Navigator.of(
                                              ctx,
                                            ).pop(); // Close dialog

                                            // Show loading indicator
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder:
                                                  (context) => const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                            );

                                            try {
                                              // Get Salesforce credentials (might be used by the function)
                                              final authNotifier = ref.read(
                                                salesforceAuthNotifierProvider
                                                    .notifier,
                                              );

                                              // Call the Cloud Function to reject the proposal
                                              final functions =
                                                  FirebaseFunctions.instanceFor(
                                                    region: 'us-central1',
                                                  );
                                              final callable = functions
                                                  .httpsCallable(
                                                    'rejectProposalForReseller',
                                                  );
                                              final result = await callable
                                                  .call<Map<String, dynamic>>({
                                                    'proposalId': proposalId,
                                                  });

                                              // Close loading dialog
                                              Navigator.of(context).pop();

                                              if (result.data['success'] ==
                                                  true) {
                                                // --- START: Create Notification Document ---
                                                try {
                                                  final currentUser = ref.read(
                                                    currentUserProvider,
                                                  ); // Corrected provider name
                                                  final notificationRepo = ref.read(
                                                    notificationRepositoryProvider,
                                                  );

                                                  await notificationRepo
                                                      .createProposalRejectedNotification(
                                                        proposalId: proposalId,
                                                        proposalName:
                                                            proposalName, // Class member
                                                        opportunityId:
                                                            null, // TODO: Pass opportunityId to this page
                                                        clientName:
                                                            proposal
                                                                .nifC, // Using NIF as client identifier for now
                                                        resellerName:
                                                            currentUser
                                                                ?.displayName,
                                                        resellerId:
                                                            currentUser?.uid,
                                                      );
                                                  if (kDebugMode) {
                                                    print(
                                                      'Proposal rejection notification created successfully.',
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (kDebugMode) {
                                                    print(
                                                      'Error creating proposal rejection notification: $e',
                                                    );
                                                    // Optionally show a non-blocking error to user or log to a monitoring service
                                                  }
                                                }
                                                // --- END: Create Notification Document ---

                                                // Success - show message and refresh the data
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Proposta rejeitada com sucesso',
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );

                                                // Refresh the proposal details
                                                ref.refresh(
                                                  resellerProposalDetailsProvider(
                                                    proposalId,
                                                  ),
                                                );
                                              } else {
                                                // Error - show error message from function
                                                final errorMsg =
                                                    result.data['error'] ??
                                                    'Falha ao rejeitar a proposta';
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Erro: $errorMsg',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              // Close loading dialog
                                              Navigator.of(context).pop();

                                              // Handle errors
                                              String errorMessage;
                                              if (e
                                                  is FirebaseFunctionsException) {
                                                errorMessage =
                                                    e.message ?? e.code;
                                                if (kDebugMode) {
                                                  print(
                                                    "Function Error Code: ${e.code}, Details: ${e.details}",
                                                  );
                                                }
                                              } else {
                                                errorMessage = e.toString();
                                              }

                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Erro ao rejeitar proposta: $errorMessage',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                                // --- END: Confirmation Dialog ---
                              },
                            ),
                          ),
                        ),
                        Expanded(
                          // Added Expanded for flexible width
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ), // Spacing between buttons
                            decoration: BoxDecoration(
                              color:
                                  theme
                                      .cardColor, // Changed to cardColor for white/neutral background
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: CupertinoColors.systemGrey4,
                                width: 1.0,
                              ), // Added subtle border
                            ),
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal:
                                    20, // Adjusted padding for container
                                vertical: 12,
                              ),
                              child: const Text(
                                'Aceitar',
                                style: TextStyle(
                                  color: CupertinoColors.activeGreen,
                                  fontWeight:
                                      FontWeight.w600, // Slightly bolder text
                                ),
                              ),
                              onPressed: () {
                                // --- START: Navigate to Submit Documents Page ---
                                final cpeList = proposal.cpePropostas ?? [];

                                // +++ DEBUG PRINTS +++
                                if (kDebugMode) {
                                  print("--- Debug: Aceitar Button Tapped ---");
                                  print(
                                    "Proposal Object: ${proposal.toString()}",
                                  );
                                  print(
                                    "Value of proposal.nifC: ${proposal.nifC}",
                                  );
                                }
                                // +++ END DEBUG PRINTS +++

                                final nif =
                                    proposal
                                        .nifC; // <-- Get NIF from proposal data

                                if (nif == null || nif.isEmpty) {
                                  // Handle case where NIF is missing - show error?
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Erro: NIF não encontrado para esta proposta.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return; // <--- Error is triggered here
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            SubmitProposalDocumentsPage(
                                              proposalId: proposalId,
                                              cpeList: cpeList,
                                              nif: nif, // <-- Pass the NIF
                                            ),
                                  ),
                                );
                                // --- END: Navigate to Submit Documents Page ---
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox.shrink(), // Use shrink if buttons not shown
                // --- END: Conditional Action Buttons ---
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
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface, // Matched style
        ),
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
              // Use cpeC if available, otherwise fallback to ID or N/A
              cpe.cpeC != null && cpe.cpeC!.isNotEmpty
                  ? '${cpe.cpeC}'
                  : '${cpe.id.substring(cpe.id.length - 6)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(
              height: 16,
            ), // Added SizedBox for consistent spacing after removing Divider
            // Commission (Highlighted and First)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120, // Keep consistent label width
                    child: Text(
                      'Comissão:', // TODO: Localize
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatCurrency(cpe.commissionRetail),
                      style: theme.textTheme.titleSmall?.copyWith(
                        // Highlight style
                        fontWeight: FontWeight.bold,
                        color:
                            theme
                                .colorScheme
                                .primary, // Or another highlight color
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildDetailRow(
              context,
              'Potência',
              cpe.consumptionOrPower?.toStringAsFixed(2) ?? 'N/A',
            ),
            _buildDetailRow(
              context,
              'Fidelização',
              _formatYears(cpe.loyaltyYears),
            ),
            // --- MODIFIED: Display Attached Files (Icons Only) --- //
            if (cpe.attachedFiles.isNotEmpty) ...[
              const SizedBox(height: 24), // Increased top spacing for the label
              Text(
                'Ficheiros', // TODO: Localize
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color:
                      theme
                          .colorScheme
                          .onSurfaceVariant, // Consistent label color
                ),
              ),
              const SizedBox(height: 8), // Spacing between label and icons
              Wrap(
                alignment: WrapAlignment.center, // Center align the file icons
                spacing: 12.0, // Horizontal space between icons
                runSpacing: 8.0, // Vertical space between lines of icons
                children:
                    cpe.attachedFiles.map((file) {
                      return Consumer(
                        builder: (context, cardRef, _) {
                          return IconButton(
                            padding: EdgeInsets.zero, // Minimal padding
                            icon: Icon(
                              _getFileIcon(file.title, theme),
                              size: 36, // Slightly larger icon size
                              color:
                                  CupertinoColors
                                      .systemGrey, // More neutral icon color
                            ),
                            tooltip:
                                file.title, // Show filename on long press/hover
                            onPressed:
                                () => _handleFileTap(context, cardRef, file),
                          );
                        },
                      );
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
