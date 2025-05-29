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

class ServicesPage extends ConsumerStatefulWidget {
  const ServicesPage({super.key});

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

      if (userData == null)
        throw Exception('Erro de autenticação do utilizador.');

      final success = await formNotifier.submitServiceRequest(
        resellerId: userData['uid'] ?? '',
        resellerName: userData['displayName'] ?? userData['email'] ?? 'Unknown',
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
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface),
          onPressed: handleBackPress,
          tooltip: '',
        ),
        title: LogoWidget(height: 60, darkMode: theme.brightness == Brightness.dark),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
          'Serviços',
                  style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
          ),
        ),
      ),
              // Step indicator (show after step 0)
              if (currentStep > 0) ...[
                const SizedBox(height: 24),
                _buildStepIndicator(),
              ],
              const SizedBox(height: 24),
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
            final bool isCompleted = currentStep > stepIndex;
            final bool isActiveOrCompleted = currentStep >= stepIndex;
            final double size = isActiveOrCompleted ? 28 : 20;
            final Color fillColor = isActiveOrCompleted
                ? colorScheme.primary
                : colorScheme.surface;
            final Color borderColor = isActiveOrCompleted
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.4);
            final Color textColor = isActiveOrCompleted
                          ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant.withOpacity(0.7);
            final FontWeight fontWeight = isActive ? FontWeight.bold : FontWeight.w500;
            final List<BoxShadow> boxShadow = isActive
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.10),
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
                    : theme.colorScheme.outline.withOpacity(0.25),
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
        padding: const EdgeInsets.all(AppConstants.spacing16),
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
                        'Brevemente...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
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
        padding: const EdgeInsets.all(AppConstants.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tipo de Energia', style: textTheme.headlineSmall),
            const SizedBox(height: AppConstants.spacing24),
            ...EnergyType.values.map((type) {
              final isSelected = false; // No selection highlight for now
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
        padding: const EdgeInsets.all(AppConstants.spacing16),
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

    final notifier = ref.read(serviceSubmissionProvider.notifier);

    return ScrollConfiguration(
      behavior: const NoScrollbarBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalhes do Cliente', style: textTheme.headlineSmall),
            const SizedBox(height: AppConstants.spacing24),
            if (_selectedClientType == ClientType.commercial) ...[
              AppInputField(
                controller: _companyNameController,
                label: 'Nome da Empresa',
                hint: 'Insira o nome da empresa',
                onChanged: (value) => notifier.updateFormFields({'companyName': value}),
              ),
              const SizedBox(height: AppConstants.spacing16),
            ],
            AppInputField(
              controller: _responsibleNameController,
              label: 'Nome do Responsável',
              hint: 'Insira o nome do responsável',
              onChanged: (value) => notifier.updateFormFields({'responsibleName': value}),
            ),
            const SizedBox(height: AppConstants.spacing16),
            AppInputField(
              controller: _nifController,
              label: 'NIF',
              hint: 'Insira o NIF',
              keyboardType: TextInputType.number,
              onChanged: (value) => notifier.updateFormFields({'nif': value}),
            ),
            const SizedBox(height: AppConstants.spacing16),
            AppInputField(
              controller: _emailController,
              label: 'Email',
              hint: 'Insira o email de contacto',
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) => notifier.updateFormFields({'email': value}),
            ),
            const SizedBox(height: AppConstants.spacing16),
            AppInputField(
              controller: _phoneController,
              label: 'Telefone',
              hint: 'Insira o número de telefone',
              keyboardType: TextInputType.phone,
              onChanged: (value) => notifier.updateFormFields({'phone': value}),
            ),
            const SizedBox(height: AppConstants.spacing24),

            // Document upload widget
            Consumer(
              builder: (context, ref, child) {
                // FileUploadWidget now reads the provider state internally
                return const FileUploadWidget();
              },
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: AppConstants.spacing16),
              Text(
                _errorMessage!,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: AppConstants.spacing24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    ref.watch(isFormValidProvider) && !_isSubmitting
                        ? _handleSubmit
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.spacing16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child:
                    _isSubmitting
                        ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          'Submeter Pedido',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onPrimary,
                          ),
                        ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final bool isDark = theme.brightness == Brightness.dark;

    final Color effectiveIconColor =
        isDisabled
            ? colorScheme.onSurface.withOpacity(0.38)
            : colorScheme.primary;
    final Color effectiveTextColor =
        isDisabled
            ? colorScheme.onSurface.withOpacity(0.38)
            : colorScheme.onSurface;

    return Card(
      elevation: isDark ? 1.0 : 2.0,
      shadowColor:
          isDark ? Colors.black.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
      margin: const EdgeInsets.only(bottom: AppConstants.spacing12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacing16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Icon(icon, color: effectiveIconColor, size: 28),
                ),
                const SizedBox(width: AppConstants.spacing16),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      color: effectiveTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (!isDisabled)
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClientCard({
    required String title,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      elevation: 1.0,
      margin: const EdgeInsets.only(bottom: AppConstants.spacing12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacing16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Image.asset(imagePath, fit: BoxFit.contain),
                ),
                const SizedBox(width: AppConstants.spacing16),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
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
        onTap: isEnabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isEnabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.38),
                size: 28,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isEnabled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withOpacity(0.38),
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
    super.key,
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
                  ? theme.colorScheme.surface.withOpacity(0.97)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isHovering ? 0.10 : 0.06),
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
    super.key,
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
                  ? theme.colorScheme.surface.withOpacity(0.97)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isHovering ? 0.10 : 0.06),
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
