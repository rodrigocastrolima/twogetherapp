import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/service_types.dart';
import '../../../core/models/service_types.dart' as service_types show Provider;
import '../../../core/theme/theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/constants.dart';
import 'dart:ui';
import '../../../core/theme/ui_styles.dart';
import '../../../features/services/presentation/widgets/file_upload_widget.dart';
import '../../../features/services/presentation/providers/service_submission_provider.dart';
import '../../../features/services/data/repositories/service_submission_repository.dart'
    as repo;

class ServicesPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? preFilledData;

  const ServicesPage({super.key, this.preFilledData});

  @override
  ConsumerState<ServicesPage> createState() => ServicesPageState();
}

class ServicesPageState extends ConsumerState<ServicesPage>
    with SingleTickerProviderStateMixin {
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

  // Animation controller for pulsing effect
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
    if (widget.preFilledData != null &&
        widget.preFilledData!.containsKey('resubmissionId')) {
      // Potentially pre-fill steps based on existing submission data
      // For now, just log it
      debugPrint(
        "Handling potential resubmission for ID: ${widget.preFilledData!['resubmissionId']}",
      );
    }

    // Initialize animation controller
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 700), // Pulse duration
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _responsibleNameController.dispose();
    _nifController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _pulseController.dispose(); // Dispose animation controller
    super.dispose();
  }

  void _handleCategorySelection(ServiceCategory category) {
    if (!category.isAvailable) return;

    setState(() {
      _selectedCategory = category;
      currentStep = 1;
      _selectedEnergyType = null;
      _selectedClientType = null;
      _selectedProvider = null;
      _clearFormValues(); // Clear form fields, but not file
    });

    // Update the form state in the provider
    final formNotifier = ref.read(serviceSubmissionProvider.notifier);
    formNotifier.updateFormField('serviceCategory', category.name);
    // Clear dependent fields in provider state
    formNotifier.updateFormField('energyType', null);
    formNotifier.updateFormField('clientType', null);
    formNotifier.updateFormField('provider', null);
  }

  void _handleEnergyTypeSelection(EnergyType type) {
    setState(() {
      _selectedEnergyType = type;
      currentStep = 2;
      _selectedClientType = null;
      _selectedProvider = null;
      _clearFormValues();
    });

    // Update the form state
    final formNotifier = ref.read(serviceSubmissionProvider.notifier);
    formNotifier.updateFormField('energyType', type.name);
    formNotifier.updateFormField('clientType', null);
    formNotifier.updateFormField('provider', null);
  }

  void _handleClientTypeSelection(ClientType type) {
    setState(() {
      _selectedClientType = type;
      currentStep = 3;

      // Set provider based on client type and energy type
      if (_selectedEnergyType == EnergyType.solar ||
          type == ClientType.commercial) {
        _selectedProvider = service_types.Provider.edp;
      } else {
        _selectedProvider = service_types.Provider.repsol;
      }
      _clearFormValues();
    });

    // Update the form state
    final formNotifier = ref.read(serviceSubmissionProvider.notifier);
    formNotifier.updateFormField('clientType', type.name);
    formNotifier.updateFormField('provider', _selectedProvider!.name);
  }

  // Clear only text form fields, keep file selection
  void _clearFormValues() {
    _companyNameController.clear();
    _responsibleNameController.clear();
    _nifController.clear();
    _emailController.clear();
    _phoneController.clear();
    // Don't reset provider form state here, keep selections
  }

  bool _isFormValid() {
    // Check if invoice file has been selected from the provider state
    final formState = ref.read(serviceSubmissionProvider);
    bool hasInvoiceFile = formState.selectedInvoiceFile != null;

    // Validate required text fields based on client type
    bool textFieldsValid = false;
    if (_selectedClientType == ClientType.commercial) {
      textFieldsValid =
          _companyNameController.text.isNotEmpty &&
          _responsibleNameController.text.isNotEmpty &&
          _nifController.text.isNotEmpty &&
          _emailController.text.isNotEmpty &&
          _phoneController.text.isNotEmpty;
    } else {
      textFieldsValid =
          _responsibleNameController.text.isNotEmpty &&
          _nifController.text.isNotEmpty &&
          _emailController.text.isNotEmpty &&
          _phoneController.text.isNotEmpty;
    }

    // Check NIF format
    bool nifValid =
        _nifController.text.length == 9 &&
        int.tryParse(_nifController.text) != null;

    // Check email format
    bool emailValid =
        _emailController.text.contains('@') &&
        _emailController.text.contains('.');

    return hasInvoiceFile && textFieldsValid && nifValid && emailValid;
  }

  Future<void> _handleSubmit() async {
    if (!_isFormValid() || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final formNotifier = ref.read(serviceSubmissionProvider.notifier);

      // Update form fields with the text controller values
      final formData = {
        'companyName': _companyNameController.text,
        'responsibleName': _responsibleNameController.text,
        'nif': _nifController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
      };

      // Ensure selections from UI state are also in the provider state
      if (_selectedCategory != null) {
        formNotifier.updateFormField(
          'serviceCategory',
          _selectedCategory!.name,
        );
      }
      if (_selectedEnergyType != null) {
        formNotifier.updateFormField('energyType', _selectedEnergyType!.name);
      }
      if (_selectedClientType != null) {
        formNotifier.updateFormField('clientType', _selectedClientType!.name);
      }
      if (_selectedProvider != null) {
        formNotifier.updateFormField('provider', _selectedProvider!.name);
      }

      // Update text fields in provider state
      formNotifier.updateFormFields(formData);

      // Get current user info from repository
      final userRepo = ref.read(repo.serviceSubmissionRepositoryProvider);
      final userData = await userRepo.getCurrentUserData();
      if (userData == null) {
        throw Exception('User not authenticated');
      }

      // Now submit the form using the provider
      final success = await formNotifier.submitServiceRequest(
        resellerId: userData['uid'] ?? '',
        resellerName: userData['displayName'] ?? userData['email'] ?? 'Unknown',
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido de serviço enviado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back after successful submission
        if (context.canPop()) {
          context.pop();
        } else {
          // Fallback if cannot pop (e.g., deep link)
          context.go('/');
        }
      } else {
        // Error message is handled by the provider listener
        final formState = ref.read(serviceSubmissionProvider);
        setState(() {
          _errorMessage = formState.errorMessage ?? 'Erro ao enviar formulário';
        });
      }
    } catch (e) {
      debugPrint('Error submitting form: $e');
      setState(() {
        _errorMessage = 'Erro ao enviar formulário: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // Handle back navigation within the stepper or pop the route
  void handleBackPress() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
        // Clear selections for the step we are going *back* to
        // This logic might need refinement based on exact UX desired
        switch (currentStep) {
          case 0: // Going back to category selection
            _selectedCategory = null;
            _selectedEnergyType = null;
            _selectedClientType = null;
            _selectedProvider = null;
            _clearFormValues();
            ref
                .read(serviceSubmissionProvider.notifier)
                .resetForm(); // Full reset
            break;
          case 1: // Going back to energy type selection
            _selectedEnergyType = null;
            _selectedClientType = null;
            _selectedProvider = null;
            _clearFormValues();
            ref.read(serviceSubmissionProvider.notifier).updateFormFields({
              'energyType': null,
              'clientType': null,
              'provider': null,
            });
            break;
          case 2: // Going back to client type selection
            _selectedClientType = null;
            _selectedProvider = null;
            _clearFormValues();
            ref.read(serviceSubmissionProvider.notifier).updateFormFields({
              'clientType': null,
              'provider': null,
            });
            break;
        }
      });
    } else {
      // If at step 0 (category selection), pop the route
      if (context.canPop()) {
        context.pop();
      } else {
        // Fallback if cannot pop (e.g., direct link)
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for error messages from the provider
    ref.listen<ServiceSubmissionState>(serviceSubmissionProvider, (
      previous,
      next,
    ) {
      if (next.errorMessage != null && next.errorMessage != _errorMessage) {
        // Update local error message state IF the provider has an error
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _errorMessage = next.errorMessage;
            });
          }
        });
      } else if (next.errorMessage == null && _errorMessage != null) {
        // Clear local error message if provider error is cleared
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _errorMessage = null;
            });
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left),
          onPressed: handleBackPress, // Use unified back handler
        ),
        // Remove title conditionally based on step?
        title: null, // Removed title
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Only show step indicator after step 0
          if (currentStep > 0) _buildStepIndicator(),
          Expanded(child: _buildCurrentStep()),
        ],
      ),
    );
  }

  // --- UI Builder Methods --- //

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacing16),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min, // Keep Row compact
          children: List<Widget>.generate(5, (index) {
            // 3 circles + 2 lines = 5 items
            // Even indices are circles (0, 2, 4), odd are lines (1, 3)
            if (index.isEven) {
              final stepIndex = index ~/ 2; // 0, 1, 2
              final stepNumber = stepIndex + 1;
              final isActive = currentStep >= stepNumber;
              final isCurrent = currentStep == stepNumber;

              // Build Circle
              Widget circleWidget = Container(
                width: 30, // Revert to fixed size
                height: 30, // Revert to fixed size
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? AppTheme.primary : Colors.grey[300],
                ),
                child: Center(
                  child: Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );

              // Apply pulse effect if current
              if (isCurrent) {
                return ScaleTransition(
                  scale: _pulseAnimation,
                  child: circleWidget,
                );
              } else {
                return circleWidget;
              }
            } else {
              // Build Line
              final stepIndex = index ~/ 2; // 0, 1
              final stepNumber = stepIndex + 1;
              final isActive = currentStep > stepNumber;

              return Container(
                width: 80, // Increased width for the line
                height: 1.5, // Thinner line
                margin: const EdgeInsets.symmetric(horizontal: 8),
                // Use rounded corners for a softer look
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primary : Colors.grey[300],
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }
          }),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (currentStep) {
      case 0:
        return _buildServiceCategoryStep();
      case 1:
        return _buildEnergyTypeStep();
      case 2:
        return _buildClientTypeStep();
      case 3:
        return _buildFormStep();
      default:
        return const Center(child: Text('Passo inválido'));
    }
  }

  // --- Step Builder Methods (Reverted to original structure) ---

  Widget _buildServiceCategoryStep() {
    return ScrollConfiguration(
      behavior: const NoScrollbarBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
    return ScrollConfiguration(
      behavior: const NoScrollbarBehavior(),
      child: SingleChildScrollView(
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
      return ScrollConfiguration(
        behavior: const NoScrollbarBehavior(),
        child: SingleChildScrollView(
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
    return ScrollConfiguration(
      behavior: const NoScrollbarBehavior(),
      child: SingleChildScrollView(
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

  Widget _buildFormStep() {
    return ScrollConfiguration(
      behavior: const NoScrollbarBehavior(),
      child: SingleChildScrollView(
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
            const FileUploadWidget(),

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

// Helper class to prevent scrollbar from showing
class NoScrollbarBehavior extends ScrollBehavior {
  const NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
