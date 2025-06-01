import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../features/proposal/data/models/salesforce_cpe_proposal_data.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';
import '../../widgets/logo.dart'; // Import LogoWidget
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/notifications/data/repositories/notification_repository.dart';
import 'package:flutter/foundation.dart';
import '../../widgets/success_dialog.dart'; // Import the success dialog
import '../../widgets/app_loading_indicator.dart'; // Import the custom loading indicator
import 'package:go_router/go_router.dart'; // Import go_router
import '../../../features/proposal/presentation/providers/proposal_providers.dart'; // Import for provider invalidation
import '../../../features/opportunity/presentation/providers/opportunity_providers.dart'; // Import for opportunity provider invalidation

// Enum to represent different document types
enum DocumentType { contract, idDocument, proofOfAddress, crcDocument }

// ConsumerStatefulWidget to potentially access providers if needed (e.g., for NIF)
class SubmitProposalDocumentsPage extends ConsumerStatefulWidget {
  final String proposalId;
  final String proposalName;
  final List<SalesforceCPEProposalData> cpeList;
  final String nif;
  final String? opportunityId; // Add optional opportunity ID

  const SubmitProposalDocumentsPage({
    super.key,
    required this.proposalId,
    required this.proposalName,
    required this.cpeList,
    required this.nif,
    this.opportunityId, // Optional parameter
  });

  @override
  ConsumerState<SubmitProposalDocumentsPage> createState() =>
      _SubmitProposalDocumentsPageState();
}

class _SubmitProposalDocumentsPageState
    extends ConsumerState<SubmitProposalDocumentsPage> {
  bool _isDigitallySigned = false;
  bool _isLoading = false;

  // State variables to hold picked files
  Map<String, PlatformFile?> _contractFiles = {};
  PlatformFile? _idDocumentFile;
  PlatformFile? _proofOfAddressFile;
  PlatformFile? _crcDocumentFile;

  @override
  void initState() {
    super.initState();
    // Initialize the map keys based on the passed cpeList
    for (var cpe in widget.cpeList) {
      _contractFiles[cpe.id] = null;
    }
  }

  bool _areAllDocumentsReady() {
    if (!_isDigitallySigned) {
      // Check all contract files if not digitally signed
      for (var cpeEntry in _contractFiles.entries) {
        if (cpeEntry.value == null) return false;
      }
    }
    // Check other mandatory documents
    if (_idDocumentFile == null) return false;
    if (_proofOfAddressFile == null) return false;
    if (_crcDocumentFile == null) return false;
    return true;
  }

  // Method to pick a file
  Future<void> _pickFile(DocumentType docType, {String? cpeProposalId}) async {
    if (_isLoading) return;
    // Only allow picking contract if not digitally signed
    if (docType == DocumentType.contract && _isDigitallySigned) return;

    // Ensure cpeProposalId is provided when picking a contract
    if (docType == DocumentType.contract && cpeProposalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Internal error: CPE ID missing for contract.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.single != null) {
        if (result.files.single.bytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error reading file data.')),
          );
          return;
        }

        setState(() {
          switch (docType) {
            case DocumentType.contract:
              // Store contract file in the map using the CPE ID
              if (cpeProposalId != null) {
                _contractFiles[cpeProposalId] = result.files.single;
              }
              break;
            case DocumentType.idDocument:
              _idDocumentFile = result.files.single;
              break;
            case DocumentType.proofOfAddress:
              _proofOfAddressFile = result.files.single;
              break;
            case DocumentType.crcDocument:
              _crcDocumentFile = result.files.single;
              break;
          }
        });
      } else {
        // User canceled the picker
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao selecionar ficheiro: $e')),
      );
    }
  }

  // Placeholder for file upload logic
  Future<void> _submitDocuments() async {
    if (_isLoading || !_areAllDocumentsReady()) return;

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // 1. Validation
    List<String> missingFiles = [];
    if (!_isDigitallySigned) {
      for (var cpeEntry in _contractFiles.entries) {
        if (cpeEntry.value == null) {
          final cpeData = widget.cpeList.firstWhere(
            (c) => c.id == cpeEntry.key,
            orElse:
                () =>
                    SalesforceCPEProposalData(id: 'unknown', attachedFiles: []),
          );
          final String displayId =
              cpeData.id.length > 6
                  ? cpeData.id.substring(cpeData.id.length - 6)
                  : cpeData.id;
          missingFiles.add('Contrato (ID: ...$displayId)');
        }
      }
    }
    if (_idDocumentFile == null)
      missingFiles.add('Documento de identificação (CC)');
    if (_proofOfAddressFile == null) missingFiles.add('Prova de residência');
    if (_crcDocumentFile == null) missingFiles.add('Certidão Permanente (CRC)');

    if (missingFiles.isNotEmpty) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Ficheiros em falta: ${missingFiles.join(', ')}'),
          backgroundColor: Colors.orange,
        ),
      );
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 2. Prepare file list for upload
    Map<DocumentType, PlatformFile?> filesToUpload = {
      // Contracts handled separately below
      DocumentType.idDocument: _idDocumentFile,
      DocumentType.proofOfAddress: _proofOfAddressFile,
      DocumentType.crcDocument: _crcDocumentFile,
    };

    List<Map<String, dynamic>> fileDataForFunction = [];
    bool uploadErrorOccurred = false;

    try {
      // 3. Upload non-contract files
      for (var entry in filesToUpload.entries) {
        if (entry.value != null) {
          final docType = entry.key;
          final file = entry.value!;
          final String typeString = _getDocTypeString(docType);

          final uploadResult = await _uploadFileToStorage(file);
          if (uploadResult['url'] != null &&
              uploadResult['originalFilename'] != null) {
            fileDataForFunction.add({
              'type': typeString,
              'url': uploadResult['url'],
              'originalFilename': uploadResult['originalFilename'],
            });
          } else {
            uploadErrorOccurred = true;
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('Falha no upload: ${uploadResult['error']}'),
                backgroundColor: Colors.red,
              ),
            );
            break; // Stop if one fails?
          }
        }
      }

      // 3b. Upload contract files (if not digitally signed and no errors yet)
      if (!_isDigitallySigned && !uploadErrorOccurred) {
        for (var entry in _contractFiles.entries) {
          if (entry.value != null) {
            final cpeProposalId = entry.key;
            final file = entry.value!;
            // Use the CPE_Proposta__c ID as the identifier for the filename
            final cpeIdentifier = cpeProposalId;

            final uploadResult = await _uploadFileToStorage(file);
            if (uploadResult['url'] != null &&
                uploadResult['originalFilename'] != null) {
              fileDataForFunction.add({
                'type': 'Contrato',
                'url': uploadResult['url'],
                'cpe': cpeIdentifier, // Pass the CPE_Proposta__c ID
                'originalFilename': uploadResult['originalFilename'],
              });
            } else {
              uploadErrorOccurred = true;
              // Keep user message simple or use short ID if needed
              String shortId =
                  cpeIdentifier.length > 6
                      ? cpeIdentifier.substring(cpeIdentifier.length - 6)
                      : cpeIdentifier;
              scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
                    'Falha no upload (Contrato ...${shortId}): ${uploadResult['error']}',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              break; // Stop if one fails?
            }
          }
        }
      }

      // 4. If any upload failed, stop here
      if (uploadErrorOccurred) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 5. Call Cloud Function
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('acceptProposalAndUploadDocs');

      final result = await callable.call<Map<String, dynamic>>({
        'proposalId': widget.proposalId,
        'nif': widget.nif,
        'files': fileDataForFunction,
      });

      // 6. Handle result
      if (result.data['success'] == true) {
        // Invalidate providers to ensure refresh
        ref.invalidate(resellerProposalDetailsProvider(widget.proposalId));
        ref.invalidate(resellerOpportunitiesProvider);
        
        // Also invalidate the opportunity proposals provider if opportunity ID is available
        if (widget.opportunityId != null) {
          ref.invalidate(resellerOpportunityProposalNamesProvider(widget.opportunityId!));
        }

        // --- Create Notification Document ---
        try {
          final currentUser = ref.read(currentUserProvider);
          final notificationRepo = ref.read(notificationRepositoryProvider);
          
          // Assuming opportunityId might be null or not available here
          await notificationRepo.createProposalAcceptedNotification(
            proposalId: widget.proposalId,
            proposalName: widget.proposalName, // Now available via widget
            opportunityId: widget.opportunityId, // Pass the opportunity ID
            clientNif: widget.nif,
            resellerName: currentUser?.displayName,
            resellerId: currentUser?.uid,
          );
          if (kDebugMode) {
            print('Proposal acceptance notification created successfully.');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error creating proposal acceptance notification: $e');
            // Optionally show a non-blocking error to user or log to a monitoring service
            // but don't let this error block the primary success flow.
          }
        }
        // --- END Notification Document Creation ---

        // Show success dialog instead of SnackBar
        await showSuccessDialog(
          context: context, // context is available here
          message: 'Documentos submetidos com sucesso!',
          onDismissed: () {
            // Navigate to home page
            context.go('/'); 
          },
        );
      } else {
        final errorMsg =
            result.data['message'] ??
            result.data['error'] ??
            'Falha ao submeter documentos.';
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Erro: $errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _isLoading = false); // Ensure loader stops on error
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erro Cloud Function (${e.code}): ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false); // Ensure loader stops on error
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Ocorreu um erro inesperado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Returns a map with 'url' and 'originalFilename' on success, or 'error' on failure.
  Future<Map<String, String?>> _uploadFileToStorage(PlatformFile file) async {
    if (file.bytes == null) {
      return {'error': 'File data is missing for ${file.name}'};
    }
    try {
      // Create a unique filename using timestamp and original name's base
      final uniqueFileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.name)}';
      final storagePath =
          'proposals/${widget.proposalId}/submitted_documents/$uniqueFileName';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      // Attempt to determine Content-Type, fallback to octet-stream
      final contentType =
          lookupMimeType(file.name) ?? 'application/octet-stream';
      final metadata = SettableMetadata(contentType: contentType);

      final uploadTask = storageRef.putData(file.bytes!, metadata);

      // Await completion
      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return {
        'url': downloadUrl,
        'originalFilename': file.name, // Return original name
      };
    } catch (e) {
      return {'error': 'Firebase Storage Error: ${e.toString()}'};
    }
  }

  String _getDocTypeString(DocumentType type) {
    switch (type) {
      case DocumentType.contract:
        return 'Contrato';
      case DocumentType.idDocument:
        return 'CC';
      case DocumentType.proofOfAddress:
        return 'PR';
      case DocumentType.crcDocument:
        return 'CRC';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool allDocumentsReady = _areAllDocumentsReady();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // Conditionally show AppBar
      appBar: _isLoading ? null : AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.chevron_left,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: LogoWidget(height: 60, darkMode: isDark),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Main content with proper layout constraints
          if (!_isLoading)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Page Title Section
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title on the left
                            Text(
                              'Aceitar Proposta',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Proposal name centered
                            Center(
                              child: Text(
                                widget.proposalName,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Main content
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Digital signature section (no card container)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _isDigitallySigned
                                            ? theme.colorScheme.primary.withAlpha((255 * 0.1).round())
                                            : theme.colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        _isDigitallySigned 
                                            ? Icons.description_outlined 
                                            : Icons.description,
                                        color: _isDigitallySigned 
                                            ? theme.colorScheme.primary 
                                            : theme.colorScheme.onSurfaceVariant,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Contratos assinados digitalmente',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const Spacer(),
                                    Switch.adaptive(
                                      value: _isDigitallySigned,
                                      onChanged: (bool value) {
                                        setState(() {
                                          _isDigitallySigned = value;
                                          if (_isDigitallySigned) {
                                            _contractFiles.updateAll((key, _) => null);
                                          }
                                        });
                                      },
                                      activeColor: theme.colorScheme.primary,
                                      inactiveThumbColor: theme.colorScheme.outline,
                                      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                                        if (states.contains(WidgetState.selected)) {
                                          return theme.colorScheme.primary;
                                        }
                                        return theme.colorScheme.outline.withAlpha((255 * 0.5).round());
                                      }),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Contracts section (if not digitally signed)
                              if (!_isDigitallySigned) ...[
                                Text(
                                  'Contratos Assinados',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...widget.cpeList.map((cpe) {
                                  String cpeDisplayName = cpe.cpeC ?? 'CPE ...${cpe.id.length > 6 ? cpe.id.substring(cpe.id.length - 6) : cpe.id}';
                                  return _buildModernFileUploadCard(
                                    context,
                                    'Contrato Assinado ($cpeDisplayName)',
                                    'Ficheiro PDF assinado para este CPE',
                                    Icons.description_outlined,
                                    DocumentType.contract,
                                    _contractFiles[cpe.id],
                                    cpeProposalId: cpe.id,
                                  );
                                }).toList(),
                                const SizedBox(height: 32),
                              ],

                              // Required documents section
                              Text(
                                'Documentos Obrigatórios',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              _buildModernFileUploadCard(
                                context,
                                'Documento de identificação (CC)',
                                'Cartão de Cidadão ou documento equivalente',
                                CupertinoIcons.person_crop_rectangle,
                                DocumentType.idDocument,
                                _idDocumentFile,
                              ),
                              
                              _buildModernFileUploadCard(
                                context,
                                'Prova de residência',
                                'Comprovativo de morada atual',
                                CupertinoIcons.house,
                                DocumentType.proofOfAddress,
                                _proofOfAddressFile,
                              ),
                              
                              _buildModernFileUploadCard(
                                context,
                                'Certidão Permanente (CRC)',
                                'Certidão do Registo Comercial',
                                CupertinoIcons.doc_chart,
                                DocumentType.crcDocument,
                                _crcDocumentFile,
                              ),

                              const SizedBox(height: 40),

                              // Submit button
                              Center(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isLoading || !allDocumentsReady 
                                        ? null 
                                        : _submitDocuments,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primary,
                                      foregroundColor: theme.colorScheme.onPrimary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                      ),
                                      minimumSize: const Size(double.infinity, 50),
                                    ),
                                    child: Text(
                                      'Submeter Documentos',
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        color: theme.colorScheme.onPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Custom loading indicator as overlay
          if (_isLoading)
            const AppLoadingIndicator(),
        ],
      ),
    );
  }

  // Helper widget for modern file upload cards
  Widget _buildModernFileUploadCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    DocumentType docType,
    PlatformFile? pickedFile, {
    String? cpeProposalId,
  }) {
    final theme = Theme.of(context);
    final bool isFilePicked = pickedFile != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha((255 * 0.2).round()),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withAlpha((255 * 0.05).round()),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isFilePicked
                      ? Colors.green.withAlpha((255 * 0.1).round())
                      : theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isFilePicked ? Icons.check_circle : icon,
                  color: isFilePicked
                      ? Colors.green
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Content (always shows original title/subtitle)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Right side: File info or add button
              if (isFilePicked) ...[
                // File icon with tooltip and click-to-view functionality
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 4), // Add padding to prevent cutoff
                  child: Stack(
                    clipBehavior: Clip.none, // Allow overflow for the remove button
                    children: [
                      Tooltip(
                        message: pickedFile!.name,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            // TODO: Implement SecureFileViewer for local files
                            // This would require creating a temporary download URL or handling bytes directly
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Visualização de ficheiros locais em desenvolvimento'),
                                backgroundColor: theme.colorScheme.primary,
                              ),
                            );
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant.withAlpha((255 * 0.7).round()),
                              borderRadius: BorderRadius.circular(6.0),
                              border: Border.all(
                                color: Colors.black.withAlpha((255 * 0.1).round()),
                                width: 0.5,
                              ),
                            ),
                            child: Center(
                              child: _getFileIcon(pickedFile.name, theme),
                            ),
                          ),
                        ),
                      ),
                      // Remove button positioned at top-right corner
                      Positioned(
                        top: -6,
                        right: -6,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            if (_isLoading) return;
                            setState(() {
                              switch (docType) {
                                case DocumentType.contract:
                                  if (cpeProposalId != null) {
                                    _contractFiles[cpeProposalId] = null;
                                  }
                                  break;
                                case DocumentType.idDocument:
                                  _idDocumentFile = null;
                                  break;
                                case DocumentType.proofOfAddress:
                                  _proofOfAddressFile = null;
                                  break;
                                case DocumentType.crcDocument:
                                  _crcDocumentFile = null;
                                  break;
                              }
                            });
                          },
                          child: Icon(
                            CupertinoIcons.xmark,
                            color: Colors.red,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Add button (only this is clickable)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _pickFile(docType, cpeProposalId: cpeProposalId),
                  child: Container(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.add,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to get file icon based on file extension
  Widget _getFileIcon(String fileName, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final fileType = fileName.toLowerCase().split('.').last;
    
    if (['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp', 'heic'].contains(fileType)) {
      return Icon(Icons.image_outlined, color: colorScheme.primary, size: 20);
    } else if (fileType == 'pdf') {
      return Icon(Icons.picture_as_pdf, color: colorScheme.error, size: 20);
    } else {
      return Icon(Icons.insert_drive_file, color: colorScheme.onSurfaceVariant, size: 20);
    }
  }
}
