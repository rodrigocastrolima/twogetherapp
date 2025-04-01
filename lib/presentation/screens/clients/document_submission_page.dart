import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

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
      return documents.entries
          .where((e) => e.key != 'Contrato Assinado')
          .every((e) => e.value != null);
    }
    return documents.values.every((v) => v != null);
  }

  Future<void> _selectDocument(String documentType) async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      documents[documentType] = 'selected_file.pdf';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _buildDigitalSignatureCard(),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final entry = documents.entries.elementAt(index);
                      if (isDigitallySigned &&
                          entry.key == 'Contrato Assinado') {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildDocumentItem(entry.key, entry.value),
                      );
                    }, childCount: documents.length),
                  ),
                ),
              ],
            ),
          ),

          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Submeter Ficheiros',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'João Silva', // Dummy data
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF404040),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'PT0002000123456789', // Dummy CPE
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Color(0xFF737373),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalSignatureCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(38), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 15,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.signature,
                    size: 18,
                    color: Color(0xFF2C2C2E),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Contrato Assinado Digitalmente',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  CupertinoSwitch(
                    value: isDigitallySigned,
                    onChanged: (value) {
                      setState(() {
                        isDigitallySigned = value;
                      });
                    },
                    activeTrackColor: const Color(0xFF2C2C2E),
                  ),
                ],
              ),
              if (isDigitallySigned) ...[
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 28),
                  child: Text(
                    'Se o contrato foi assinado digitalmente, não é necessário fazer upload',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF737373),
                      height: 1.3,
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

  Widget _buildDocumentItem(String title, String? value) {
    final isSelected = value != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(38), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 15,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? CupertinoIcons.doc_checkmark : CupertinoIcons.doc,
                size: 22,
                color:
                    isSelected
                        ? const Color(0xFF34C759)
                        : const Color(0xFF8E8E93),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? const Color(0xFFE9F7EC)
                            : Colors.black.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.add,
                        size: 14,
                        color:
                            isSelected
                                ? const Color(0xFF34C759)
                                : const Color(0xFF2C2C2E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSelected ? 'Adicionado' : 'Adicionar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color:
                              isSelected
                                  ? const Color(0xFF34C759)
                                  : const Color(0xFF2C2C2E),
                        ),
                      ),
                    ],
                  ),
                ),
                onPressed: () => _selectDocument(title),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        top: false,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: canSubmit ? () {} : null,
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color:
                  canSubmit
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFF2C2C2E).withAlpha(128),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Submeter Documentos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
