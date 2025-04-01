import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../core/theme/theme.dart';
import '../../../core/utils/constants.dart';
import 'package:go_router/go_router.dart';

class ResubmissionFormPage extends StatefulWidget {
  final String submissionId;

  const ResubmissionFormPage({super.key, required this.submissionId});

  @override
  State<ResubmissionFormPage> createState() => _ResubmissionFormPageState();
}

class _ResubmissionFormPageState extends State<ResubmissionFormPage> {
  // Form controllers with pre-filled data
  final _companyNameController = TextEditingController(
    text: 'Tech Solutions Lda',
  );
  final _responsibleNameController = TextEditingController(text: 'João Silva');
  final _nifController = TextEditingController(text: '123456789');
  final _emailController = TextEditingController(
    text: 'joao.silva@techsolutions.pt',
  );
  final _phoneController = TextEditingController(text: '912345678');
  String? _invoiceFile;

  @override
  void dispose() {
    _companyNameController.dispose();
    _responsibleNameController.dispose();
    _nifController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _isFormValid() {
    return _companyNameController.text.isNotEmpty &&
        _responsibleNameController.text.isNotEmpty &&
        _nifController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _phoneController.text.isNotEmpty &&
        _invoiceFile != null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Form Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Submission ID: ${widget.submissionId}',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.foreground.withAlpha(178),
                  ),
                ),
                const SizedBox(height: AppConstants.spacing24),
                Text(
                  'Dados do Cliente',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
                const SizedBox(height: AppConstants.spacing24),
                _buildTextField(
                  controller: _companyNameController,
                  label: 'Nome da Empresa',
                  hint: 'Digite o nome da empresa',
                ),
                const SizedBox(height: AppConstants.spacing16),
                _buildTextField(
                  controller: _responsibleNameController,
                  label: 'Nome do Responsável',
                  hint: 'Digite o nome do responsável',
                ),
                const SizedBox(height: AppConstants.spacing16),
                _buildTextField(
                  controller: _nifController,
                  label: 'NIF',
                  hint: 'Digite o NIF',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppConstants.spacing16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Digite o email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppConstants.spacing16),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Telefone',
                  hint: 'Digite o telefone',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppConstants.spacing24),
                _buildFileUpload(),
                const SizedBox(height: AppConstants.spacing24),
              ],
            ),
          ),
        ),

        // Submit Button
        Padding(
          padding: const EdgeInsets.all(AppConstants.spacing16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isFormValid() ? () => context.pop() : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.spacing16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Enviar'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.foreground,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(51)),
              ),
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: AppTheme.mutedForeground),
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                style: TextStyle(color: AppTheme.foreground),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fatura',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.foreground,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(51)),
              ),
              child: InkWell(
                onTap: () {
                  // Handle file upload
                  setState(() {
                    _invoiceFile = 'invoice.pdf';
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _invoiceFile != null
                            ? Icons.check_circle
                            : Icons.upload_file,
                        color:
                            _invoiceFile != null
                                ? AppTheme.primary
                                : AppTheme.foreground.withAlpha(128),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _invoiceFile ?? 'Clique para fazer upload da fatura',
                          style: TextStyle(
                            color:
                                _invoiceFile != null
                                    ? AppTheme.foreground
                                    : AppTheme.foreground.withAlpha(128),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
