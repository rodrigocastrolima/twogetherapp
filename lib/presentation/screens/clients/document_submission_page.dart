import 'package:flutter/material.dart';

class DocumentSubmissionPage extends StatefulWidget {
  const DocumentSubmissionPage({super.key});

  @override
  State<DocumentSubmissionPage> createState() => _DocumentSubmissionPageState();
}

class _DocumentSubmissionPageState extends State<DocumentSubmissionPage> {
  bool isDigitallySigned = false;
  final Map<String, String?> documents = {
    'Documento de Identificação': null,
    'Comprovativo de Morada': null,
    'Certidão Permanente': null,
    'Contrato Assinado': null,
  };

  bool get canSubmit {
    if (isDigitallySigned) {
      // If digitally signed, we don't need the "Contrato Assinado"
      return documents.entries
          .where((e) => e.key != 'Contrato Assinado')
          .every((e) => e.value != null);
    }
    // If not digitally signed, we need all documents
    return documents.values.every((v) => v != null);
  }

  Future<void> _selectDocument(String documentType) async {
    // Simulate file selection
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      documents[documentType] = 'selected_file.pdf';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submeter Ficheiros')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDigitalSignatureSection(),
                  const Divider(height: 32),
                  ..._buildDocumentsList(),
                ],
              ),
            ),
          ),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildDigitalSignatureSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Contrato Assinado Digitalmente',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Switch(
                value: isDigitallySigned,
                onChanged: (value) {
                  setState(() {
                    isDigitallySigned = value;
                  });
                },
                activeColor: Colors.black,
              ),
            ],
          ),
          if (isDigitallySigned)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Se o contrato foi assinado digitalmente, não é necessário fazer upload',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildDocumentsList() {
    return documents.entries.map((entry) {
      // Skip "Contrato Assinado" if digitally signed
      if (isDigitallySigned && entry.key == 'Contrato Assinado') {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              entry.key,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            ),
            TextButton(
              onPressed: () => _selectDocument(entry.key),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    size: 20,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.value == null ? 'Selecionar' : 'Selecionado',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSubmitButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed:
              canSubmit
                  ? () {
                    // Handle submission
                  }
                  : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Submeter Documentos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
