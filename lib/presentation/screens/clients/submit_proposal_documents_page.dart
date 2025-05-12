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

// Enum to represent different document types
enum DocumentType { contract, idDocument, proofOfAddress, crcDocument }

// ConsumerStatefulWidget to potentially access providers if needed (e.g., for NIF)
class SubmitProposalDocumentsPage extends ConsumerStatefulWidget {
  final String proposalId;
  final List<SalesforceCPEProposalData> cpeList;
  final String nif;

  const SubmitProposalDocumentsPage({
    super.key,
    required this.proposalId,
    required this.cpeList,
    required this.nif,
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
    if (_isLoading) return;

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // 1. Validation
    List<String> missingFiles = [];
    if (!_isDigitallySigned) {
      for (var cpeEntry in _contractFiles.entries) {
        if (cpeEntry.value == null) {
          // Find corresponding CPE Data for the ID
          final cpeData = widget.cpeList.firstWhere(
            (c) => c.id == cpeEntry.key,
            orElse:
                () =>
                    SalesforceCPEProposalData(id: 'unknown', attachedFiles: []),
          );
          // Use the ID for the message, showing last 6 chars
          final String displayId =
              cpeData.id.length > 6
                  ? cpeData.id.substring(cpeData.id.length - 6)
                  : cpeData.id;
          missingFiles.add('Contrato (ID: ...$displayId)'); // Use ID in message
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
      setState(() => _isLoading = false);
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
        setState(() => _isLoading = false);
        return;
      }

      // 5. Call Cloud Function
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('acceptProposalAndUploadDocs');

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('A submeter documentos para Salesforce...'),
        ),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'proposalId': widget.proposalId,
        'nif': widget.nif,
        'files': fileDataForFunction,
      });

      // 6. Handle result
      if (result.data['success'] == true) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Documentos submetidos com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        // Optional: Check result.data['proposalUpdateStatus'] if needed
        navigator.pop(); // Go back on success
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
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erro Cloud Function (${e.code}): ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Ocorreu um erro inesperado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submeter Documentos'), // TODO: Localize
        centerTitle: true,
      ),
      body: IgnorePointer(
        ignoring: _isLoading,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Opacity(
                opacity: _isLoading ? 0.5 : 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Carregar documentos necessários:', // TODO: Localize
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),

                    // --- Digital Signature Toggle ---
                    SwitchListTile.adaptive(
                      title: const Text('Contratos assinados digitalmente'),
                      value: _isDigitallySigned,
                      onChanged: (bool value) {
                        setState(() {
                          _isDigitallySigned = value;
                          if (_isDigitallySigned) {
                            _contractFiles.updateAll((key, _) => null);
                          }
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        _isDigitallySigned
                            ? CupertinoIcons.checkmark_seal_fill
                            : CupertinoIcons.checkmark_seal,
                        color:
                            _isDigitallySigned
                                ? theme.colorScheme.primary
                                : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- File Upload Section ---
                    if (!_isDigitallySigned)
                      ...widget.cpeList.map((cpe) {
                        String shortId =
                            cpe.id.length > 6
                                ? cpe.id.substring(cpe.id.length - 6)
                                : cpe.id;
                        return _buildFileUploadPlaceholder(
                          context,
                          'Contrato Assinado (CPE ...$shortId)',
                          Icons.description_outlined,
                          DocumentType.contract,
                          _contractFiles[cpe.id],
                          cpeProposalId: cpe.id,
                        );
                      }).toList(),

                    const Divider(height: 24),

                    _buildFileUploadPlaceholder(
                      context,
                      'Documento de identificação (CC)',
                      CupertinoIcons.person_crop_rectangle,
                      DocumentType.idDocument,
                      _idDocumentFile,
                    ),
                    _buildFileUploadPlaceholder(
                      context,
                      'Prova de residência',
                      CupertinoIcons.house,
                      DocumentType.proofOfAddress,
                      _proofOfAddressFile,
                    ),
                    _buildFileUploadPlaceholder(
                      context,
                      'Certidão Permanente (CRC)',
                      CupertinoIcons.doc_chart,
                      DocumentType.crcDocument,
                      _crcDocumentFile,
                    ),
                    const SizedBox(height: 32),

                    // --- Submit Button ---
                    Center(
                      child: CupertinoButton.filled(
                        onPressed: _isLoading ? null : _submitDocuments,
                        child: const Text('Submeter Documentos'),
                      ),
                    ),
                    const SizedBox(height: 40), // Extra padding at bottom
                  ],
                ),
              ),
            ),
            // --- Loading Indicator Overlay ---
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  // Helper widget for file upload placeholders
  Widget _buildFileUploadPlaceholder(
    BuildContext context,
    String title,
    IconData icon,
    DocumentType docType,
    PlatformFile? pickedFile, {
    String? cpeProposalId,
  }) {
    bool isFilePicked = pickedFile != null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(
          icon,
          color:
              isFilePicked
                  ? Colors.green
                  : Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          isFilePicked ? pickedFile.name : title,
          style: TextStyle(color: isFilePicked ? Colors.green : null),
          overflow: TextOverflow.ellipsis,
        ),
        trailing:
            isFilePicked
                ? IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Remover ficheiro',
                  onPressed: () {
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
                )
                : null,
        onTap: () => _pickFile(docType, cpeProposalId: cpeProposalId),
      ),
    );
  }
}
