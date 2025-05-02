import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

// Enum to represent different document types
enum DocumentType { signedContract, idDocument, proofOfAddress, crcDocument }

class SubmitProposalDocumentsPage extends StatefulWidget {
  final String proposalId;

  const SubmitProposalDocumentsPage({super.key, required this.proposalId});

  @override
  State<SubmitProposalDocumentsPage> createState() =>
      _SubmitProposalDocumentsPageState();
}

class _SubmitProposalDocumentsPageState
    extends State<SubmitProposalDocumentsPage> {
  bool _isDigitallySigned = false;

  // State variables to hold picked files
  PlatformFile? _signedContractFile;
  PlatformFile? _idDocumentFile;
  PlatformFile? _proofOfAddressFile;
  PlatformFile? _crcDocumentFile;

  // Method to pick a file
  Future<void> _pickFile(DocumentType docType) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single != null) {
        setState(() {
          switch (docType) {
            case DocumentType.signedContract:
              _signedContractFile = result.files.single;
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
    // TODO: Implement file picking and upload logic
    // 1. Check which files are required based on _isDigitallySigned
    // 2. Ensure required files are picked (show error if not)
    // 3. Call Cloud Function/API to upload files, linking to widget.proposalId
    // 4. Show success/error message
    // 5. Maybe navigate back or to a success page

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
                'Contrato assinado digitalmente',
              ), // TODO: Localize
              value: _isDigitallySigned,
              onChanged: (bool value) {
                setState(() {
                  _isDigitallySigned = value;
                  // Clear the contract file if switching to digitally signed
                  if (_isDigitallySigned) {
                    _signedContractFile = null;
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

            // --- File Upload Placeholders ---
            // TODO: Replace these Text widgets with actual file picker widgets/buttons

            // Conditionally show Signed Contract upload
            if (!_isDigitallySigned)
              _buildFileUploadPlaceholder(
                context,
                'Contrato assinado', // TODO: Localize
                Icons.description_outlined,
                DocumentType.signedContract,
                _signedContractFile,
              ),

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
    PlatformFile? pickedFile,
  ) {
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
        trailing: Icon(
          isFilePicked
              ? CupertinoIcons.checkmark_circle_fill
              : CupertinoIcons.folder_badge_plus,
          color: isFilePicked ? Colors.green : null,
        ),
        onTap: () {
          _pickFile(docType);
        },
      ),
    );
  }
}
