import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/service_types.dart';
import '../../../core/models/service_types.dart' as service_types show Provider;
import '../../../core/utils/constants.dart';
import '../../../features/services/presentation/widgets/file_upload_widget.dart';
import '../../../features/services/presentation/providers/service_submission_provider.dart';
import '../../../features/services/data/repositories/service_submission_repository.dart'
    as repo;
import '../../widgets/success_dialog.dart'; // Import the success dialog
import '../../widgets/logo.dart'; // Import the LogoWidget
import '../../widgets/app_input_field.dart';
import '../../widgets/standard_app_bar.dart';

class ServicesPage extends ConsumerStatefulWidget {
  final String? quickAction;
  
  const ServicesPage({super.key, this.quickAction});

  @override
  ConsumerState<ServicesPage> createState() => ServicesPageState();
}

class ServicesPageState extends ConsumerState<ServicesPage>
    with SingleTickerProviderStateMixin {
  int currentStep = 0; // Start at 0 to not show step indicator initially
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

  // Validation error states
  String? _companyNameError;
  String? _responsibleNameError;
  String? _nifError;
  String? _emailError;
  String? _phoneError;

  // Track if fields have been touched/altered
  bool _companyNameTouched = false;
  bool _responsibleNameTouched = false;
  bool _nifTouched = false;
  bool _emailTouched = false;
  bool _phoneTouched = false;
  bool _submitAttempted = false;

  // Validation functions
  String? _validateFullName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Nome é obrigatório';
    if (trimmed.length < 2) return 'Nome deve ter pelo menos 2 caracteres';
    if (trimmed.length > 100) return 'Nome deve ter no máximo 100 caracteres';
    
    // Only alphabetic characters (including accents) and spaces
    final nameRegex = RegExp(r'^[a-zA-ZÀ-ÿĀ-žÀ-ú\s]+$');
    if (!nameRegex.hasMatch(trimmed)) {
      return 'Nome deve conter apenas letras e espaços';
    }
    
    return null;
  }

  String? _validateCompanyName(String value) {
    final trimmed = value.trim();
    if (_selectedClientType == ClientType.commercial && trimmed.isEmpty) {
      return 'Nome da empresa é obrigatório';
    }
    if (trimmed.isNotEmpty && trimmed.length < 2) {
      return 'Nome da empresa deve ter pelo menos 2 caracteres';
    }
    if (trimmed.length > 100) {
      return 'Nome da empresa deve ter no máximo 100 caracteres';
    }
    
    return null;
  }

  String? _validateNIF(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'NIF é obrigatório';
    
    // Must be exactly 9 digits
    final nifRegex = RegExp(r'^[0-9]{9}$');
    if (!nifRegex.hasMatch(trimmed)) {
      return 'NIF deve ter exatamente 9 dígitos numéricos';
    }
    
    return null;
  }

  String? _validateEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'E-mail é obrigatório';
    if (trimmed.length > 254) return 'E-mail deve ter no máximo 254 caracteres';
    
    // Standard email format
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Formato de e-mail inválido';
    }
    
    return null;
  }

  String? _validatePhone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Telefone é obrigatório';
    
    // Must be exactly 9 digits for Portuguese mobile numbers
    final phoneRegex = RegExp(r'^[0-9]{9}$');
    if (!phoneRegex.hasMatch(trimmed)) {
      return 'Telefone deve ter exatamente 9 dígitos numéricos';
    }
    
    // Optional: Check valid mobile operator codes
    final firstTwoDigits = trimmed.substring(0, 2);
    final validPrefixes = ['91', '92', '93', '96'];
    if (!validPrefixes.contains(firstTwoDigits)) {
      return 'Telefone deve começar com 91, 92, 93 ou 96';
    }
    
    return null;
  }

  // Form validation state - only check if fields have content
  bool get _isFormValid {
    final hasFile = ref.read(serviceSubmissionProvider).selectedFiles.isNotEmpty;
    
    // Check if all fields have content (not empty)
    bool baseValid = _responsibleNameController.text.trim().isNotEmpty &&
                     _nifController.text.trim().isNotEmpty &&
                     _emailController.text.trim().isNotEmpty &&
                     _phoneController.text.trim().isNotEmpty &&
                     hasFile;
    
    // Only require company name for commercial clients
    if (_selectedClientType == ClientType.commercial) {
      baseValid = baseValid && _companyNameController.text.trim().isNotEmpty;
    }
    
    return baseValid;
  }

  @override
  void initState() {
    super.initState();
    debugPrint('ServicesPage opened');
    // Initialize controllers (no longer using preFilledData)
    _companyNameController = TextEditingController();
    _responsibleNameController = TextEditingController();
    _nifController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();

    // Initialize animation controller
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Handle quick action if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.quickAction != null) {
        _handleQuickAction(widget.quickAction!);
      }
    });

    // Handle quick actions
    if (widget.quickAction != null) {
      // Pre-fill selections based on quick action
      WidgetsBinding.instance.addPostFrameCallback((_) {
        switch (widget.quickAction) {
          case 'edp-solar':
            setState(() {
              _selectedEnergyType = EnergyType.solar;
              _selectedClientType = ClientType.residential;
              _selectedProvider = service_types.Provider.edp;
              currentStep = 3;
            });
            ref.read(serviceSubmissionProvider.notifier).updateFormFields({
              'energyType': EnergyType.solar.name,
              'clientType': ClientType.residential.name,
              'provider': service_types.Provider.edp.name,
            });
            break;
          case 'edp-comercial':
            setState(() {
              _selectedEnergyType = EnergyType.solar;
              _selectedClientType = ClientType.commercial;
              _selectedProvider = service_types.Provider.edp;
              currentStep = 3;
            });
            ref.read(serviceSubmissionProvider.notifier).updateFormFields({
              'energyType': EnergyType.solar.name,
              'clientType': ClientType.commercial.name,
              'provider': service_types.Provider.edp.name,
            });
            break;
          case 'repsol-residencial':
            setState(() {
              _selectedEnergyType = EnergyType.electricityGas;
              _selectedClientType = ClientType.residential;
              _selectedProvider = service_types.Provider.repsol;
              currentStep = 3;
            });
            ref.read(serviceSubmissionProvider.notifier).updateFormFields({
              'energyType': EnergyType.electricityGas.name,
              'clientType': ClientType.residential.name,
              'provider': service_types.Provider.repsol.name,
            });
            break;
        }
      });
    }
  }

  String _getPageTitle() {
    switch (widget.quickAction) {
      case 'edp-solar':
        return 'EDP - Energia Solar';
      case 'edp-comercial':
        return 'EDP - Energia Comercial';
      case 'repsol-residencial':
        return 'Repsol - Energia Residencial';
      default:
        return 'Serviços';
    }
  }

  double _getResponsiveSpacing() {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth < 600 ? 0 : 24;
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
    // The onTapAction in _buildServiceCategoryStep handles showing the dialog
    // for unavailable categories and only calls this method for available ones.

    setState(() {
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
      // Clear company name for residential clients
      'companyName': type == ClientType.residential ? null : '',
    });
  }

  // Clear only text form fields, keep file selection
  void _clearFormValues() {
    _companyNameController.clear();
    _responsibleNameController.clear();
    _nifController.clear();
    _emailController.clear();
    _phoneController.clear();
    
    // Clear validation errors and touched states
    _companyNameError = null;
    _responsibleNameError = null;
    _nifError = null;
    _emailError = null;
    _phoneError = null;
    
    _companyNameTouched = false;
    _responsibleNameTouched = false;
    _nifTouched = false;
    _emailTouched = false;
    _phoneTouched = false;
    _submitAttempted = false;
    // Note: This does NOT clear the provider's formData map,
    // only the local controllers. Provider state is managed via updateFormFields.
  }

  void _handleQuickAction(String quickAction) {
    switch (quickAction) {
      case 'edp-solar':
        _skipToForm(
          energyType: EnergyType.solar,
          clientType: ClientType.commercial,
          provider: service_types.Provider.edp,
        );
        break;
      case 'edp-comercial':
        _skipToForm(
          energyType: EnergyType.electricityGas,
          clientType: ClientType.commercial,
          provider: service_types.Provider.edp,
        );
        break;
      case 'repsol-residencial':
        _skipToForm(
          energyType: EnergyType.electricityGas,
          clientType: ClientType.residential,
          provider: service_types.Provider.repsol,
        );
        break;
    }
  }

  void _skipToForm({
    required EnergyType energyType,
    required ClientType clientType,
    required service_types.Provider provider,
  }) {
    setState(() {
      currentStep = 3; // Jump directly to form step
      _selectedEnergyType = energyType;
      _selectedClientType = clientType;
      _selectedProvider = provider;
    });

    // Pre-populate provider state
    final formNotifier = ref.read(serviceSubmissionProvider.notifier);
    formNotifier.updateFormFields({
      'serviceCategory': ServiceCategory.energy.name,
      'energyType': energyType.name,
      'clientType': clientType.name,
      'provider': provider.name,
    });
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _submitAttempted = true;
      
      // Validate all fields on submit attempt
      _companyNameError = _validateCompanyName(_companyNameController.text);
      _responsibleNameError = _validateFullName(_responsibleNameController.text);
      _nifError = _validateNIF(_nifController.text);
      _emailError = _validateEmail(_emailController.text);
      _phoneError = _validatePhone(_phoneController.text);
    });

    // Check if any validation errors exist
    bool hasValidationErrors = _responsibleNameError != null ||
                              _nifError != null ||
                              _emailError != null ||
                              _phoneError != null;
    
    if (_selectedClientType == ClientType.commercial) {
      hasValidationErrors = hasValidationErrors || _companyNameError != null;
    }

    // If there are validation errors, stop submission and show errors
    if (hasValidationErrors) {
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    try {
      final formNotifier = ref.read(serviceSubmissionProvider.notifier);
      final userRepo = ref.read(repo.serviceSubmissionRepositoryProvider);
      final userData = await userRepo.getCurrentUserData();

      if (userData == null) {
        throw Exception('Erro de autenticação do utilizador.');
      }

      final success = await formNotifier.submitServiceRequest(
        resellerId: userData['uid'] ?? '',
        resellerName: userData['displayName'] ?? userData['email'] ?? 'Desconhecido',
      );

      if (success && mounted) {
        // Show the success dialog FIRST
        await showSuccessDialog(
          context: context,
          message:
              'Pedido de serviço submetido com sucesso! Será revisto em breve.',
          onDismissed: () {
            // Navigation happens AFTER the dialog is dismissed
            if (mounted) {
              // Check mounted again inside callback
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/'); // Fallback navigation
              }
            }
          },
        );
      } else if (!success && mounted) {
        final formState = ref.read(serviceSubmissionProvider);
        setState(() {
          _errorMessage =
              formState.errorMessage ?? 'Erro ao submeter o pedido de serviço.';
        });
      }
    } catch (e) {
      debugPrint('Error submitting form: $e');
      setState(() {
        _errorMessage = 'Ocorreu um erro inesperado ao submeter: $e';
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
    // If we're in quick action mode and at the form step, go back to home
    if (widget.quickAction != null && currentStep == 3) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
      return;
    }

    if (currentStep > 0) {
      setState(() {
        currentStep--;
        // Clear local selections for the step we are going back to
        switch (currentStep) {
          case 0: // Going back to category selection
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
      
      // Also trigger rebuild when files change for validation
      if (previous?.selectedFiles.length != next.selectedFiles.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: StandardAppBar(
        showBackButton: true,
        onBackPressed: handleBackPress,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SafeArea(
                child: SizedBox(height: _getResponsiveSpacing()),
              ),
              // Show title only on step 0, otherwise show step indicator in same position
              if (widget.quickAction == null && currentStep == 0) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    _getPageTitle(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (widget.quickAction == null && currentStep > 0) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                  child: _buildStepIndicator(),
                ),
                const SizedBox(height: 8),
              ] else if (widget.quickAction != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    _getPageTitle(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: _buildCurrentStep(),
              ),
        ],
          ),
        ),
      ),
    );
  }

  // --- UI Builder Methods --- //

  Widget _buildStepIndicator() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    const totalSteps = 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: List.generate(totalSteps * 2 - 1, (index) {
          if (index.isEven) {
            final stepIndex = index ~/ 2 + 1;
            final bool isActive = currentStep == stepIndex;
            final bool isActiveOrCompleted = currentStep >= stepIndex;
            final double size = isActiveOrCompleted ? 28 : 20;
            final Color fillColor = isActiveOrCompleted
                ? colorScheme.primary
                : colorScheme.surface;
            final Color borderColor = isActiveOrCompleted
                ? colorScheme.primary
                : colorScheme.outline.withAlpha((255 * 0.4).round());
            final Color textColor = isActiveOrCompleted
                          ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant.withAlpha((255 * 0.7).round());
            final FontWeight fontWeight = isActive ? FontWeight.bold : FontWeight.w500;
            final List<BoxShadow> boxShadow = isActive
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withAlpha((255 * 0.10).round()),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
              ),
                  ]
                : [];

            Widget circle = AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: fillColor,
                border: Border.all(color: borderColor, width: 1.5),
                shape: BoxShape.circle,
                boxShadow: boxShadow,
              ),
              child: Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Center(
                    child: Text(
                      '$stepIndex',
                      textAlign: TextAlign.center,
                      style: textTheme.labelLarge?.copyWith(
                        color: textColor,
                        fontWeight: fontWeight,
                        fontSize: isActiveOrCompleted ? 16 : 14,
                        letterSpacing: 0.2,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            );

            // Add pulse animation for active step
            if (isActive) {
              circle = ScaleTransition(scale: _pulseAnimation, child: circle);
            }

            return circle;
          } else {
            // Line between steps
            final prevStep = (index - 1) ~/ 2 + 1;
            final isActiveOrCompletedLine = currentStep > prevStep;
            return Expanded(
              child: Container(
                height: 1.0,
                color: isActiveOrCompletedLine
                          ? colorScheme.primary
                    : theme.colorScheme.outline.withAlpha((255 * 0.25).round()),
              ),
            );
          }
        }),
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
        return Center(child: Text('Passo inválido'));
    }
  }

  // --- Step Builder Methods --- //

  Widget _buildServiceCategoryStep() {
    final theme = Theme.of(context);
    return ScrollConfiguration(
      behavior: const NoScrollbarBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, category) in ServiceCategory.values.indexed) ...[
              ServiceCategoryCard(
                title: category.displayName,
                icon: _getCategoryIcon(category),
                enabled: category.isAvailable,
                onTap: category.isAvailable ? () => _handleCategorySelection(category) : null,
                trailing: category.isAvailable
                    ? Icon(CupertinoIcons.chevron_right, color: theme.colorScheme.onSurfaceVariant, size: 20)
                    : Text(
                        'Em breve',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withAlpha((255 * 0.6).round()),
                        ),
                      ),
              ),
              if (i != ServiceCategory.values.length - 1)
                const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyTypeStep() {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return ScrollConfiguration(
      behavior: const NoScrollbarBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tipo de Energia', style: textTheme.headlineSmall),
            const SizedBox(height: AppConstants.spacing24),
            ...EnergyType.values.map((type) {
              final icon = _getEnergyTypeIcon(type);
              return _EnergyTypeCard(
                title: type.displayName,
                icon: icon,
                onTap: () => _handleEnergyTypeSelection(type),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildClientTypeStep() {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Common structure for title
    Widget buildHeader() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tipo de Cliente', style: textTheme.headlineSmall),
          const SizedBox(height: AppConstants.spacing24),
        ],
      );
    }

    return ScrollConfiguration(
      behavior: const NoScrollbarBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildHeader(),
            ...[
              _ClientTypeCard(
              title: 'Empresarial',
              imagePath: 'assets/images/edp_logo_br.png',
              onTap: () => _handleClientTypeSelection(ClientType.commercial),
            ),
              if (_selectedEnergyType != EnergyType.solar)
                _ClientTypeCard(
                title: 'Residencial',
                imagePath: 'assets/images/repsol_logo_br.png',
                onTap: () => _handleClientTypeSelection(ClientType.residential),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return ScrollConfiguration(
      behavior: const NoScrollbarBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedClientType == ClientType.commercial ? 'Dados da Empresa' : 'Dados do Cliente',
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: AppConstants.spacing24),
            // Only show company name field for commercial clients
            if (_selectedClientType == ClientType.commercial) ...[
              _ValidatedInputField(
                controller: _companyNameController,
                label: 'Nome da Empresa',
                hint: 'Introduza o nome da empresa',
                error: _companyNameError,
                showError: _submitAttempted,
                onChanged: (value) {
                  setState(() {
                    _companyNameTouched = true;
                    _companyNameError = _validateCompanyName(value);
                  });
                  ref.read(serviceSubmissionProvider.notifier).updateFormFields({
                    'companyName': value,
                  });
                },
              ),
              const SizedBox(height: AppConstants.spacing16),
            ],
            _ValidatedInputField(
              controller: _responsibleNameController,
              label: _selectedClientType == ClientType.commercial ? 'Nome do Responsável' : 'Nome do Cliente',
              hint: _selectedClientType == ClientType.commercial ? 'Introduza o nome do responsável' : 'Introduza o nome do Cliente',
              error: _responsibleNameError,
              showError: _submitAttempted,
              onChanged: (value) {
                setState(() {
                  _responsibleNameTouched = true;
                  _responsibleNameError = _validateFullName(value);
                });
                ref.read(serviceSubmissionProvider.notifier).updateFormFields({
                  'responsibleName': value,
                });
              },
            ),
            const SizedBox(height: AppConstants.spacing16),
            _ValidatedInputField(
              controller: _nifController,
              label: 'NIF',
              hint: 'Introduza o NIF da empresa',
              keyboardType: TextInputType.number,
              error: _nifError,
              showError: _submitAttempted,
              onChanged: (value) {
                setState(() {
                  _nifTouched = true;
                  _nifError = _validateNIF(value);
                });
                ref.read(serviceSubmissionProvider.notifier).updateFormFields({
                  'nif': value,
                });
              },
            ),
            const SizedBox(height: AppConstants.spacing16),
            _ValidatedInputField(
              controller: _emailController,
              label: 'E-mail',
              hint: 'Introduza o e-mail',
              keyboardType: TextInputType.emailAddress,
              error: _emailError,
              showError: _submitAttempted,
              onChanged: (value) {
                setState(() {
                  _emailTouched = true;
                  _emailError = _validateEmail(value);
                });
                ref.read(serviceSubmissionProvider.notifier).updateFormFields({
                  'email': value,
                });
              },
            ),
            const SizedBox(height: AppConstants.spacing16),
            _ValidatedInputField(
              controller: _phoneController,
              label: 'Telefone',
              hint: 'Introduza o número de telefone',
              keyboardType: TextInputType.phone,
              error: _phoneError,
              showError: _submitAttempted,
              onChanged: (value) {
                setState(() {
                  _phoneTouched = true;
                  _phoneError = _validatePhone(value);
                });
                ref.read(serviceSubmissionProvider.notifier).updateFormFields({
                  'phone': value,
                });
              },
            ),
            const SizedBox(height: AppConstants.spacing24),
            const FileUploadWidget(),
            const SizedBox(height: AppConstants.spacing32),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppConstants.spacing16),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withAlpha((255 * 0.1).round()),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.error),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: colorScheme.error, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacing16),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFormValid ? colorScheme.primary : colorScheme.onSurface.withAlpha((255 * 0.12).round()),
                  foregroundColor: _isFormValid ? colorScheme.onPrimary : colorScheme.onSurface.withAlpha((255 * 0.38).round()),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: (_isSubmitting || !_isFormValid) ? null : _handleSubmit,
                child: _isSubmitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: colorScheme.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                      : Text(
                        'Submeter Pedido',
                        style: textTheme.labelLarge?.copyWith(
                          color: _isFormValid ? colorScheme.onPrimary : colorScheme.onSurface.withAlpha((255 * 0.38).round()),
                        ),
                      ),
              ),
            ),
          ],
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

// Add ServiceCategoryCard widget for consistent, interactive cards
class ServiceCategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ServiceCategoryCard({
    required this.title,
    required this.icon,
    this.enabled = true,
    this.onTap,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = enabled;
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isEnabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withAlpha((255 * 0.38).round()),
                size: 28,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isEnabled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withAlpha((255 * 0.38).round()),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

// Card for energy type selection, matching service card style
class _EnergyTypeCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  const _EnergyTypeCard({
    required this.title,
    required this.icon,
    this.onTap,
  });

  @override
  State<_EnergyTypeCard> createState() => _EnergyTypeCardState();
}

class _EnergyTypeCardState extends State<_EnergyTypeCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.only(bottom: 16),
        color: theme.colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: _isHovering
                  ? theme.colorScheme.surface.withAlpha((255 * 0.97).round())
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(_isHovering ? (255 * 0.10).round() : (255 * 0.06).round()),
                  blurRadius: _isHovering ? 10 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              children: [
                Icon(widget.icon, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(CupertinoIcons.chevron_right, color: theme.colorScheme.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Card for client type selection, matching service card style
class _ClientTypeCard extends StatefulWidget {
  final String title;
  final String imagePath;
  final VoidCallback? onTap;

  const _ClientTypeCard({
    required this.title,
    required this.imagePath,
    this.onTap,
  });

  @override
  State<_ClientTypeCard> createState() => _ClientTypeCardState();
}

class _ClientTypeCardState extends State<_ClientTypeCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.only(bottom: 16),
        color: theme.colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: _isHovering
                  ? theme.colorScheme.surface.withAlpha((255 * 0.97).round())
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(_isHovering ? (255 * 0.10).round() : (255 * 0.06).round()),
                  blurRadius: _isHovering ? 10 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Image.asset(widget.imagePath, fit: BoxFit.contain),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(CupertinoIcons.chevron_right, color: theme.colorScheme.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Validated input field with custom error styling
class _ValidatedInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final String? error;
  final bool showError;
  final ValueChanged<String>? onChanged;

  const _ValidatedInputField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.error,
    this.showError = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isLightMode = theme.brightness == Brightness.light;
    final hasError = error != null && showError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 56,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: textTheme.bodySmall?.copyWith(
                color: hasError ? colorScheme.error : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              hintText: hint,
              hintStyle: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withAlpha((255 * 0.7).round()),
              ),
              filled: true,
              fillColor: isLightMode 
                  ? colorScheme.surface
                  : colorScheme.surfaceContainerHighest,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError 
                      ? colorScheme.error
                      : (isLightMode 
                          ? colorScheme.outline.withAlpha((255 * 0.6).round())
                          : colorScheme.outline.withAlpha((255 * 0.2).round())),
                  width: hasError ? 2 : (isLightMode ? 1.5 : 1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? colorScheme.error : colorScheme.primary, 
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.error, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.error, width: 2),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 0),
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Text(
              error!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
