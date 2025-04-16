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
    formNotifier.updateFormFields({
      'serviceCategory': category.name,
      // Clear dependent fields in provider state
      'energyType': null,
      'clientType': null,
      'provider': null,
    });
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
    formNotifier.updateFormFields({
      'energyType': type.name,
      'clientType': null,
      'provider': null,
    });
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
    formNotifier.updateFormFields({
      'clientType': type.name,
      'provider': _selectedProvider!.name,
    });
  }

  // Clear only text form fields, keep file selection
  void _clearFormValues() {
    _companyNameController.clear();
    _responsibleNameController.clear();
    _nifController.clear();
    _emailController.clear();
    _phoneController.clear();
    // Note: This does NOT clear the provider's formData map,
    // only the local controllers. Provider state is managed via updateFormFields.
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final formNotifier = ref.read(serviceSubmissionProvider.notifier);
      final userRepo = ref.read(repo.serviceSubmissionRepositoryProvider);
      final userData = await userRepo.getCurrentUserData();

      if (userData == null) throw Exception('User not authenticated');

      final success = await formNotifier.submitServiceRequest(
        resellerId: userData['uid'] ?? '',
        resellerName: userData['displayName'] ?? userData['email'] ?? 'Unknown',
      );

      if (success && mounted) {
        // Set the global flag to show dialog on destination page
        ref.read(showSubmissionSuccessDialogProvider.notifier).state = true;

        // Navigate back immediately
        if (context.canPop()) {
          context.pop();
      } else {
          context.go('/'); // Navigate to home/root
        }
      } else if (!success && mounted) {
        // Handle submission failure (error message likely set by notifier)
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

  void handleBackPress() {
    if (currentStep > 0) {
    setState(() {
        currentStep--;
        // Clear local selections for the step we are going back to
        switch (currentStep) {
          case 0: // Going back to category selection
            _selectedCategory = null;
            _selectedEnergyType = null;
            _selectedClientType = null;
            _selectedProvider = null;
            _clearFormValues();
            // Also reset provider state completely when going back to step 0
            ref.read(serviceSubmissionProvider.notifier).resetForm();
            break;
          case 1: // Going back to energy type selection
            _selectedEnergyType = null;
            _selectedClientType = null;
            _selectedProvider = null;
            _clearFormValues();
            // Clear corresponding fields in provider state
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
            // Clear corresponding fields in provider state
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.darkPrimary : AppTheme.primary;
    final foregroundColor =
        isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final destructiveColor =
        isDark ? AppTheme.darkDestructive : AppTheme.destructive;
    final primaryForeground =
        isDark ? AppTheme.darkPrimaryForeground : AppTheme.primaryForeground;

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
          icon: Icon(CupertinoIcons.chevron_left, color: foregroundColor),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.darkPrimary : AppTheme.primary;
    final inactiveColor = isDark ? AppTheme.darkMuted : Colors.grey[300];
    final textColor = isDark ? AppTheme.darkPrimaryForeground : Colors.white;
    final inactiveTextColor =
        isDark ? AppTheme.darkMutedForeground : Colors.grey[600];

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
                  color: isActive ? primaryColor : inactiveColor,
      ),
      child: Center(
        child: Text(
                    '$stepNumber',
          style: TextStyle(
                      color: isActive ? textColor : inactiveTextColor,
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
                  color: isActive ? primaryColor : inactiveColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final destructiveColor =
        isDark ? AppTheme.darkDestructive : AppTheme.destructive;
    final primaryColor = isDark ? AppTheme.darkPrimary : AppTheme.primary;
    final primaryForeground =
        isDark ? AppTheme.darkPrimaryForeground : AppTheme.primaryForeground;

    // Get the notifier reference here for use in onChanged
    final notifier = ref.read(serviceSubmissionProvider.notifier);

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
                // Add onChanged to update provider
                onChanged:
                    (value) =>
                        notifier.updateFormFields({'companyName': value}),
              ),
              const SizedBox(height: AppConstants.spacing16),
            ],
            _buildTextField(
              controller: _responsibleNameController,
              label: 'Nome do Responsável',
              hint: 'Digite o nome do responsável',
              // Add onChanged to update provider
              onChanged:
                  (value) =>
                      notifier.updateFormFields({'responsibleName': value}),
            ),
            const SizedBox(height: AppConstants.spacing16),
            _buildTextField(
              controller: _nifController,
              label: 'NIF',
              hint: 'Digite o NIF',
              keyboardType: TextInputType.number,
              // Add onChanged to update provider
              onChanged: (value) => notifier.updateFormFields({'nif': value}),
            ),
            const SizedBox(height: AppConstants.spacing16),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'Digite o email',
              keyboardType: TextInputType.emailAddress,
              // Add onChanged to update provider
              onChanged: (value) => notifier.updateFormFields({'email': value}),
            ),
            const SizedBox(height: AppConstants.spacing16),
            _buildTextField(
              controller: _phoneController,
              label: 'Telefone',
              hint: 'Digite o telefone',
              keyboardType: TextInputType.phone,
              // Add onChanged to update provider
              onChanged: (value) => notifier.updateFormFields({'phone': value}),
            ),
            const SizedBox(height: AppConstants.spacing24),

            // Document upload widget - Pass required state from provider
            Consumer(
              builder: (context, ref, child) {
                final state = ref.watch(serviceSubmissionProvider);
                return FileUploadWidget(
                  selectedFile: state.selectedInvoiceFile,
                  selectedFileName: state.selectedInvoiceFileName,
                );
              },
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: AppConstants.spacing16),
                        Text(
                _errorMessage!,
                style: TextStyle(color: destructiveColor, fontSize: 14),
              ),
            ],

            const SizedBox(height: AppConstants.spacing24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // Use isFormValidProvider directly here
                onPressed:
                    ref.watch(isFormValidProvider) && !_isSubmitting
                        ? _handleSubmit
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: primaryForeground,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.spacing16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child:
                    _isSubmitting
                        ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: primaryForeground,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor =
        isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final mutedColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;
    final primaryColor = isDark ? AppTheme.darkPrimary : AppTheme.primary;
    final bgColor =
        isDark ? Colors.black.withAlpha(26) : Colors.white.withAlpha(26);
    final borderColor =
        isDark ? AppTheme.darkBorder.withAlpha(51) : Colors.white.withAlpha(51);

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
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color:
                            isDisabled
                                ? (isDark
                                    ? Colors.white.withAlpha(8)
                                    : Colors.white.withAlpha(13))
                                : primaryColor.withAlpha(38),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: isDisabled ? mutedColor : primaryColor,
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
                          color: isDisabled ? mutedColor : foregroundColor,
                        ),
                      ),
                    ),
                    if (!isDisabled)
                      Icon(
                        Icons.chevron_right,
                        color: foregroundColor.withAlpha(128),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor =
        isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final mutedColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;
    final bgColor =
        isDark ? Colors.black.withAlpha(26) : Colors.white.withAlpha(26);
    final borderColor =
        isDark ? AppTheme.darkBorder.withAlpha(51) : Colors.white.withAlpha(51);

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
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
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
                            color: foregroundColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: AppTextStyles.body2.copyWith(
                            color: mutedColor,
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
                    color: foregroundColor.withAlpha(128),
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
    void Function(String)? onChanged, // Added onChanged parameter
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor =
        isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final mutedColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;
    final bgColor =
        isDark ? Colors.black.withAlpha(26) : Colors.white.withAlpha(26);
    final borderColor =
        isDark ? AppTheme.darkBorder.withAlpha(51) : Colors.white.withAlpha(51);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: foregroundColor,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                onChanged: onChanged, // Use the passed onChanged callback
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: mutedColor),
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                style: TextStyle(color: foregroundColor),
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
