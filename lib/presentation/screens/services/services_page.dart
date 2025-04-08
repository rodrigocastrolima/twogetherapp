import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/service_types.dart';
import '../../../core/models/service_types.dart' as service_types show Provider;
import '../../../core/theme/theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/constants.dart';
import 'dart:ui';
import '../../../core/theme/ui_styles.dart';
import '../../../features/services/presentation/widgets/image_upload_widget.dart';
import '../../../features/services/presentation/providers/service_submission_provider.dart';

class ServicesPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? preFilledData;

  const ServicesPage({super.key, this.preFilledData});

  @override
  ConsumerState<ServicesPage> createState() => ServicesPageState();
}

class ServicesPageState extends ConsumerState<ServicesPage> {
  int currentStep = 0; // Start at 0 to not show step indicator initially
  ServiceCategory? _selectedCategory;
  EnergyType? _selectedEnergyType;
  ClientType? _selectedClientType;
  service_types.Provider? _selectedProvider;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Form controllers
  late final TextEditingController _companyNameController;
  late final TextEditingController _responsibleNameController;
  late final TextEditingController _nifController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    debugPrint('ServicesPage opened');
    // Initialize controllers with pre-filled data if available
    _companyNameController = TextEditingController(
      text: widget.preFilledData?['companyName'],
    );
    _responsibleNameController = TextEditingController(
      text: widget.preFilledData?['responsibleName'],
    );
    _nifController = TextEditingController(text: widget.preFilledData?['nif']);
    _emailController = TextEditingController(
      text: widget.preFilledData?['email'],
    );
    _phoneController = TextEditingController(
      text: widget.preFilledData?['phone'],
    );

    // If we have pre-filled data, set the client type but don't skip steps
    if (widget.preFilledData != null) {
      _selectedClientType = widget.preFilledData!['clientType'] as ClientType;
    }
  }

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
      currentStep = 1; // Now start counting steps
      _selectedEnergyType = null;
      _selectedClientType = null;
      _selectedProvider = null;
      _clearForm();
    });

    // Update the form state
    final formNotifier = ref.read(serviceSubmissionProvider.notifier);
    formNotifier.updateFormField('serviceCategory', category.name);
  }

  void _handleEnergyTypeSelection(EnergyType type) {
    setState(() {
      _selectedEnergyType = type;
      currentStep = 2;
      _selectedClientType = null;
      _selectedProvider = null;
      _clearForm();
    });

    // Update the form state
    final formNotifier = ref.read(serviceSubmissionProvider.notifier);
    formNotifier.updateFormField('energyType', type.name);
  }

  void _handleClientTypeSelection(ClientType type) {
    setState(() {
      _selectedClientType = type;
      currentStep = 3;

      // Set provider based on client type
      if (_selectedEnergyType == EnergyType.solar ||
          type == ClientType.commercial) {
        _selectedProvider = service_types.Provider.edp;
      } else {
        _selectedProvider = service_types.Provider.repsol;
      }
    });

    // Update the form state
    final formNotifier = ref.read(serviceSubmissionProvider.notifier);
    formNotifier.updateFormField('clientType', type.name);
    formNotifier.updateFormField('provider', _selectedProvider!.name);
  }

  void _clearForm() {
    _companyNameController.clear();
    _responsibleNameController.clear();
    _nifController.clear();
    _emailController.clear();
    _phoneController.clear();

    // Reset form state
    final formNotifier = ref.read(serviceSubmissionProvider.notifier);
    formNotifier.resetForm();
  }

  bool _isFormValid() {
    // Check if invoice file has been selected
    final formState = ref.read(serviceSubmissionProvider);
    bool hasInvoiceFile = formState.selectedInvoiceFile != null;

    if (_selectedClientType == ClientType.commercial) {
      return _companyNameController.text.isNotEmpty &&
          _responsibleNameController.text.isNotEmpty &&
          _nifController.text.isNotEmpty &&
          _emailController.text.isNotEmpty &&
          _phoneController.text.isNotEmpty &&
          hasInvoiceFile;
    } else {
      return _responsibleNameController.text.isNotEmpty &&
          _nifController.text.isNotEmpty &&
          _emailController.text.isNotEmpty &&
          _phoneController.text.isNotEmpty &&
          hasInvoiceFile;
    }
  }

  Future<void> _handleSubmit() async {
    if (!_isFormValid() || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Make sure all selections from the UI are set in the form state
      final formNotifier = ref.read(serviceSubmissionProvider.notifier);

      // Update form fields with the text controller values
      final formData = {
        'companyName': _companyNameController.text,
        'responsibleName': _responsibleNameController.text,
        'nif': _nifController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
      };

      // Explicitly set the selections from UI state
      if (_selectedCategory != null) {
        formData['serviceCategory'] = _selectedCategory!.name;
      }

      if (_selectedEnergyType != null) {
        formData['energyType'] = _selectedEnergyType!.name;
      }

      if (_selectedClientType != null) {
        formData['clientType'] = _selectedClientType!.name;
      }

      if (_selectedProvider != null) {
        formData['provider'] = _selectedProvider!.name;
      }

      // Update all form fields at once
      formNotifier.updateFormFields(formData);

      // Get current user info
      final user =
          await ref
              .read(serviceSubmissionRepositoryProvider)
              .getCurrentUserData();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Now submit the form
      final success = await formNotifier.submitServiceRequest(
        resellerId: user['uid'] ?? '',
        resellerName: user['displayName'] ?? user['email'] ?? 'Unknown',
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service request submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset form and go back to first step
        setState(() {
          currentStep = 0;
          _selectedCategory = null;
          _selectedEnergyType = null;
          _selectedClientType = null;
          _selectedProvider = null;
          _clearForm();
        });
      } else {
        final formState = ref.read(serviceSubmissionProvider);
        setState(() {
          _errorMessage = formState.errorMessage ?? 'Error submitting form';
        });
      }
    } catch (e) {
      debugPrint('Error submitting form: $e');
      setState(() {
        _errorMessage = 'Error submitting form: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void handleBackPress() {
    setState(() {
      if (currentStep > 0) {
        currentStep--;
        switch (currentStep) {
          case 0:
            _selectedCategory = null;
            _selectedEnergyType = null;
            _selectedClientType = null;
            _selectedProvider = null;
            _clearForm();
            break;
          case 1:
            _selectedEnergyType = null;
            _selectedClientType = null;
            _selectedProvider = null;
            _clearForm();
            break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentStep > 0) _buildStepIndicator(),
        Expanded(child: _buildCurrentStep()),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacing16),
      child: Row(
        children: [
          _buildStepNumber(1, currentStep >= 1),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildStepLine(currentStep >= 2),
            ),
          ),
          _buildStepNumber(2, currentStep >= 2),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildStepLine(currentStep >= 3),
            ),
          ),
          _buildStepNumber(3, currentStep >= 3),
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
        color: isActive ? AppTheme.primary : AppTheme.muted.withAlpha(128),
      ),
      child: Center(
        child: Text(
          step.toString(),
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.mutedForeground,
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
      color: isActive ? AppTheme.primary : AppTheme.muted.withAlpha(128),
    );
  }

  Widget _buildCurrentStep() {
    switch (currentStep) {
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
    return NoScrollbarBehavior.noScrollbars(
      context,
      SingleChildScrollView(
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
      ),
    );
  }

  Widget _buildEnergyTypeStep() {
    return NoScrollbarBehavior.noScrollbars(
      context,
      SingleChildScrollView(
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
      ),
    );
  }

  Widget _buildClientTypeStep() {
    // For Solar, show only Commercial client with EDP
    if (_selectedEnergyType == EnergyType.solar) {
      return NoScrollbarBehavior.noScrollbars(
        context,
        SingleChildScrollView(
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
        ),
      );
    }

    // Original view for Electricity/Gas
    return NoScrollbarBehavior.noScrollbars(
      context,
      SingleChildScrollView(
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
                color: Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(51)),
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
                    color: AppTheme.foreground.withAlpha(128),
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
                  color: Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(51)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color:
                            isDisabled
                                ? Colors.white.withAlpha(13)
                                : AppTheme.primary.withAlpha(38),
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
                        color: AppTheme.foreground.withAlpha(128),
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
    final formState = ref.watch(serviceSubmissionProvider);

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

          // Document upload widget
          const ImageUploadWidget(),

          if (_errorMessage != null) ...[
            const SizedBox(height: AppConstants.spacing16),
            Text(
              _errorMessage!,
              style: TextStyle(color: AppTheme.destructive, fontSize: 14),
            ),
          ],

          const SizedBox(height: AppConstants.spacing24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _isFormValid() && !_isSubmitting ? _handleSubmit : null,
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
              child:
                  _isSubmitting
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Text('Enviar'),
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
