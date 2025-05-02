import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../features/proposal/data/models/salesforce_cpe_proposal_data.dart';

// Enum to represent different document types
enum DocumentType { contract, idDocument, proofOfAddress, crcDocument }

class SubmitProposalDocumentsPage extends StatefulWidget {
  final String proposalId;
  final List<SalesforceCPEProposalData> cpeList;

  const SubmitProposalDocumentsPage({
    super.key,
    required this.proposalId,
    required this.cpeList,
  });

  @override
  State<SubmitProposalDocumentsPage> createState() =>
      _SubmitProposalDocumentsPageState();
}

class _SubmitProposalDocumentsPageState
    extends State<SubmitProposalDocumentsPage> {
  bool _isDigitallySigned = false;

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
    // Only allow picking contract if not digitally signed
    if (docType == DocumentType.contract && _isDigitallySigned) return;

    // Ensure cpeProposalId is provided when picking a contract
    if (docType == DocumentType.contract && cpeProposalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Internal error: CPE ID missing for contract.'),
        ),
      );
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single != null) {
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
    // TODO: Implement file upload logic for multiple contracts
    // 1. Check required files based on _isDigitallySigned and cpeList
    //    - If !_isDigitallySigned, ALL contract files in _contractFiles must be non-null.
    //    - ID, Address, CRC must be non-null.
    // 2. Show error if validation fails.
    // 3. Upload files (need strategy for multiple contracts - maybe naming convention?)
    // 4. Show success/error
    // 5. Navigate back

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Submeter - Não implementado (Proposal ID: ${widget.proposalId})',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submeter Documentos'), // TODO: Localize
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
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
              title: const Text(
                'Contratos assinados digitalmente', // Pluralized
              ), // TODO: Localize
              value: _isDigitallySigned,
              onChanged: (bool value) {
                setState(() {
                  _isDigitallySigned = value;
                  // Clear all contract files if switching to digitally signed
                  if (_isDigitallySigned) {
                    // Set all values in the map to null
                    _contractFiles.updateAll((key, _) => null);
                  }
                });
              },
              contentPadding: EdgeInsets.zero, // Adjust padding if needed
              secondary: Icon(
                _isDigitallySigned
                    ? CupertinoIcons.checkmark_seal_fill
                    : CupertinoIcons.checkmark_seal,
                color: _isDigitallySigned ? theme.colorScheme.primary : null,
              ),
            ),
            const SizedBox(height: 16),

            // --- File Upload Section --- //

            // --- Conditionally show Contract uploads --- //
            if (!_isDigitallySigned)
              ...widget.cpeList.map((cpe) {
                // Generate list dynamically
                // Extract last 6 chars for display, or use full ID if shorter
                String shortId =
                    cpe.id.length > 6
                        ? cpe.id.substring(cpe.id.length - 6)
                        : cpe.id;
                return _buildFileUploadPlaceholder(
                  context,
                  'Contrato Assinado (CPE ...$shortId)', // TODO: Localize (and format)
                  Icons.description_outlined,
                  DocumentType.contract,
                  _contractFiles[cpe.id], // Get file from map
                  cpeProposalId: cpe.id, // Pass CPE ID for picking
                );
              }).toList(),

            // --- End Contract Uploads --- //
            const Divider(height: 24),

            // --- Static Document Uploads --- //
            _buildFileUploadPlaceholder(
              context,
              'Documento de identificação (CC)', // TODO: Localize
              CupertinoIcons.person_crop_rectangle,
              DocumentType.idDocument,
              _idDocumentFile,
            ),

            _buildFileUploadPlaceholder(
              context,
              'Prova de residência', // TODO: Localize
              CupertinoIcons.house,
              DocumentType.proofOfAddress,
              _proofOfAddressFile,
            ),

            _buildFileUploadPlaceholder(
              context,
              'Certidão Permanente (CRC)', // TODO: Localize
              CupertinoIcons.doc_chart,
              DocumentType.crcDocument,
              _crcDocumentFile,
            ),

            // --- End Static Document Uploads --- //
            const SizedBox(height: 32),

            // --- Submit Button ---
            Center(
              child: CupertinoButton.filled(
                onPressed: _submitDocuments,
                child: const Text('Submeter Documentos'), // TODO: Localize
              ),
            ),
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
    String? cpeProposalId, // Make CPE ID optional
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
                  tooltip: 'Remover ficheiro', // TODO: Localize
                  onPressed: () {
                    setState(() {
                      // Clear correct state variable
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
