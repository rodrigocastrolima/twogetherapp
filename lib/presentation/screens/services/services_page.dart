import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../core/models/service_types.dart';
import '../../../core/theme/theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/constants.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  int _currentStep = 0; // Start at 0 to not show step indicator initially
  ServiceCategory? _selectedCategory;
  EnergyType? _selectedEnergyType;
  ClientType? _selectedClientType;

  // Form controllers
  final _companyNameController = TextEditingController();
  final _responsibleNameController = TextEditingController();
  final _nifController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
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

  void _handleCategorySelection(ServiceCategory category) {
    if (!category.isAvailable) return;

    setState(() {
      _selectedCategory = category;
      _currentStep = 1; // Now start counting steps
      _selectedEnergyType = null;
      _selectedClientType = null;
      _clearForm();
    });
  }

  void _handleEnergyTypeSelection(EnergyType type) {
    setState(() {
      _selectedEnergyType = type;
      _currentStep = 2;
      _selectedClientType = null;
      _clearForm();
    });
  }

  void _handleClientTypeSelection(ClientType type) {
    setState(() {
      _selectedClientType = type;
      _currentStep = 3;
    });
  }

  void _clearForm() {
    _companyNameController.clear();
    _responsibleNameController.clear();
    _nifController.clear();
    _emailController.clear();
    _phoneController.clear();
    _invoiceFile = null;
  }

  bool _isFormValid() {
    if (_selectedClientType == ClientType.commercial) {
      return _companyNameController.text.isNotEmpty &&
          _responsibleNameController.text.isNotEmpty &&
          _nifController.text.isNotEmpty &&
          _emailController.text.isNotEmpty &&
          _phoneController.text.isNotEmpty &&
          _invoiceFile != null;
    } else {
      return _responsibleNameController.text.isNotEmpty &&
          _nifController.text.isNotEmpty &&
          _emailController.text.isNotEmpty &&
          _phoneController.text.isNotEmpty &&
          _invoiceFile != null;
    }
  }

  void _handleSubmit() {
    if (!_isFormValid()) return;
    // Handle form submission
    print('Form submitted');
  }

  void _handleBackPress() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
        switch (_currentStep) {
          case 0:
            _selectedCategory = null;
            _selectedEnergyType = null;
            _selectedClientType = null;
            _clearForm();
            break;
          case 1:
            _selectedEnergyType = null;
            _selectedClientType = null;
            _clearForm();
            break;
          case 2:
            _selectedClientType = null;
            _clearForm();
            break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            Image.asset('assets/images/bg.jpg', fit: BoxFit.cover),
            Container(color: AppTheme.background.withOpacity(0.65)),
            // Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with back arrow and logo
                Padding(
                  padding: const EdgeInsets.all(AppConstants.spacing16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppTheme.foreground,
                        ),
                        onPressed:
                            _currentStep == 0
                                ? () => Navigator.of(context).pop()
                                : _handleBackPress,
                      ),
                      const Spacer(),
                      Image.asset(
                        'assets/images/twogether_logo_light_br.png',
                        height: 32,
                      ),
                      const SizedBox(width: AppConstants.spacing16),
                    ],
                  ),
                ),
                if (_currentStep > 0) _buildStepIndicator(),
                Expanded(child: _buildCurrentStep()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacing16),
      child: Row(
        children: [
          _buildStepNumber(1, _currentStep >= 1),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildStepLine(_currentStep >= 2),
            ),
          ),
          _buildStepNumber(2, _currentStep >= 2),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildStepLine(_currentStep >= 3),
            ),
          ),
          _buildStepNumber(3, _currentStep >= 3),
        ],
      ),
    );
  }

  Widget _buildStepNumber(int step, bool isActive) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppTheme.primary : AppTheme.muted.withAlpha(50),
      ),
      child: Center(
        child: Text(
          step.toString(),
          style: TextStyle(
            color:
                isActive
                    ? AppTheme.primaryForeground
                    : AppTheme.mutedForeground,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Container(
      height: 1,
      color: isActive ? AppTheme.primary : AppTheme.muted.withAlpha(50),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildServiceCategoryStep();
      case 1:
        if (_selectedCategory == ServiceCategory.energy) {
          return _buildEnergyTypeStep();
        }
        return const Center(child: Text('Service not available yet'));
      case 2:
        return _buildClientTypeStep();
      case 3:
        return _buildFormStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildServiceCategoryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppConstants.spacing24),
          Text(
            'Qual tipo de serviço?',
            style: AppTextStyles.h2.copyWith(
              color: AppTheme.foreground,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppConstants.spacing32),
          ...ServiceCategory.values.map(
            (category) => _buildSelectionTile(
              title: category.displayName,
              icon: _getCategoryIcon(category),
              onTap: () => _handleCategorySelection(category),
              isDisabled: !category.isAvailable,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyTypeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Qual tipo de serviço de energia?', style: AppTextStyles.h2),
          const SizedBox(height: AppConstants.spacing24),
          ...EnergyType.values.map(
            (type) => _buildSelectionTile(
              title: type.displayName,
              icon: _getEnergyTypeIcon(type),
              onTap: () => _handleEnergyTypeSelection(type),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientTypeStep() {
    // For Solar, show only Commercial client with EDP
    if (_selectedEnergyType == EnergyType.solar) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selecione seu fornecedor', style: AppTextStyles.h2),
            Text(
              'Escolha com base no tipo de cliente',
              style: AppTextStyles.body2.copyWith(
                color: AppTheme.mutedForeground,
              ),
            ),
            const SizedBox(height: AppConstants.spacing24),
            _buildClientCard(
              title: 'Clientes Comerciais',
              subtitle: 'Para empresas e clientes comerciais',
              imagePath: 'assets/images/edp_logo_br.png',
              onTap: () => _handleClientTypeSelection(ClientType.commercial),
            ),
          ],
        ),
      );
    }

    // Original view for Electricity/Gas
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selecione seu fornecedor', style: AppTextStyles.h2),
          Text(
            'Escolha com base no tipo de cliente',
            style: AppTextStyles.body2.copyWith(
              color: AppTheme.mutedForeground,
            ),
          ),
          const SizedBox(height: AppConstants.spacing24),
          _buildClientCard(
            title: 'Clientes Comerciais',
            subtitle: 'Para empresas e clientes comerciais',
            imagePath: 'assets/images/edp_logo_br.png',
            onTap: () => _handleClientTypeSelection(ClientType.commercial),
          ),
          const SizedBox(height: AppConstants.spacing16),
          _buildClientCard(
            title: 'Clientes Residenciais',
            subtitle: 'Para residências e famílias',
            imagePath: 'assets/images/repsol_logo_br.png',
            onTap: () => _handleClientTypeSelection(ClientType.residential),
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard({
    required String title,
    required String subtitle,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(AppConstants.spacing16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: AppTextStyles.body2.copyWith(
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacing16),
                  SizedBox(
                    width: 80,
                    child: Image.asset(imagePath, fit: BoxFit.contain),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.foreground.withOpacity(0.5),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacing16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isDisabled ? null : onTap,
              child: Container(
                padding: const EdgeInsets.all(AppConstants.spacing16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color:
                            isDisabled
                                ? Colors.white.withOpacity(0.05)
                                : AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color:
                            isDisabled
                                ? AppTheme.mutedForeground
                                : AppTheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacing16),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color:
                              isDisabled
                                  ? AppTheme.mutedForeground
                                  : AppTheme.foreground,
                        ),
                      ),
                    ),
                    if (!isDisabled)
                      Icon(
                        Icons.chevron_right,
                        color: AppTheme.foreground.withOpacity(0.5),
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dados do Cliente', style: AppTextStyles.h2),
          const SizedBox(height: AppConstants.spacing24),
          if (_selectedClientType == ClientType.commercial) ...[
            _buildTextField(
              controller: _companyNameController,
              label: 'Nome da Empresa',
              hint: 'Digite o nome da empresa',
            ),
            const SizedBox(height: AppConstants.spacing16),
          ],
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isFormValid() ? _handleSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.primaryForeground,
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
        ],
      ),
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
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppTheme.mutedForeground),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
              style: TextStyle(color: AppTheme.foreground),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileUpload() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppConstants.spacing16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                size: 48,
                color: AppTheme.foreground.withOpacity(0.7),
              ),
              const SizedBox(height: AppConstants.spacing8),
              Text(
                _invoiceFile ?? 'Por favor, carregue uma fatura',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.foreground.withOpacity(0.7),
                ),
              ),
              Text(
                'Click or drag files here',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.foreground.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(ServiceCategory category) {
    switch (category) {
      case ServiceCategory.energy:
        return Icons.bolt;
      case ServiceCategory.insurance:
        return Icons.security;
      case ServiceCategory.telecommunications:
        return Icons.phone_android;
    }
  }

  IconData _getEnergyTypeIcon(EnergyType type) {
    switch (type) {
      case EnergyType.electricityGas:
        return Icons.bolt;
      case EnergyType.solar:
        return Icons.solar_power;
    }
  }
}
