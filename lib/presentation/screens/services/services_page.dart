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
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        title: Text(
          'Serviços',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final totalSteps = 3;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.spacing8,
        horizontal: AppConstants.spacing16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalSteps * 2 - 1, (index) {
          if (index.isEven) {
            // Circle
            final stepIndex = index ~/ 2 + 1;
            final isActive = currentStep >= stepIndex;
            final isCurrent = currentStep == stepIndex;

            // Use AnimatedContainer for smoother transitions
            Widget circleContent = Center(
              child: Text(
                '$stepIndex',
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color:
                      isActive
                          ? colorScheme.onPrimary
                          : colorScheme
                              .onSurfaceVariant, // Keep or adjust based on new bg
                ),
              ),
            );

            Widget circle = AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isCurrent ? 28 : 24,
              height: isCurrent ? 28 : 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isActive
                        ? colorScheme.primary
                        : colorScheme
                            .surfaceContainerHighest, // Softer inactive color
                border:
                    isCurrent
                        ? Border.all(color: colorScheme.primary, width: 2)
                        : isActive
                        ? null // No border for active but not current
                        : Border.all(
                          color: colorScheme.outline.withOpacity(0.5),
                        ), // Subtle border for inactive
              ),
              child: circleContent,
            );

            // Apply pulse animation only if current
            return isCurrent
                ? ScaleTransition(scale: _pulseAnimation, child: circle)
                : circle;
          } else {
            // Line
            final stepIndex = index ~/ 2 + 1;
            final isCompleted = currentStep > stepIndex;
            // Use AnimatedContainer for smoother transitions
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 2.0, // Slightly thicker line
                margin: const EdgeInsets.symmetric(
                  horizontal: 4,
                ), // Reduced margin
                decoration: BoxDecoration(
                  color:
                      isCompleted
                          ? colorScheme.primary
                          : colorScheme.outline.withOpacity(
                            0.3,
                          ), // Softer inactive line
                  borderRadius: BorderRadius.circular(
                    1.0,
                  ), // Rounded ends for the line
                ),
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
    final textTheme = theme.textTheme;

    return ScrollConfiguration(
      behavior: const NoScrollbarBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...ServiceCategory.values.map((category) {
              VoidCallback onTapAction;
              if (!category.isAvailable) {
                // If category is not available, set onTap to show a dialog
                onTapAction = () {
                  showDialog(
                    context: context,
                    barrierDismissible:
                        true, // Allow dismissing by tapping outside
                    builder: (BuildContext dialogContext) {
                      final ThemeData dialogTheme = Theme.of(dialogContext);
                      final bool isDark =
                          dialogTheme.brightness == Brightness.dark;

                      return AlertDialog(
                        backgroundColor:
                            isDark
                                ? dialogTheme.colorScheme.surface.withOpacity(
                                  0.9, // Slightly increased opacity for better readability
                                )
                                : Colors.white.withOpacity(0.9),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            16.0,
                          ), // Slightly smaller radius
                        ),
                        titlePadding: const EdgeInsets.fromLTRB(
                          // Adjusted padding
                          20.0,
                          20.0,
                          20.0,
                          0.0,
                        ),
                        contentPadding: const EdgeInsets.fromLTRB(
                          // Adjusted padding
                          20.0,
                          12.0, // Reduced top padding for content
                          20.0,
                          20.0, // Reduced bottom padding
                        ),
                        title: Align(
                          // Title is just centered text now
                          alignment: Alignment.center,
                          child: Text(
                            'Em Desenvolvimento',
                            style: dialogTheme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // Removed the Stack and Positioned widget for the close button
                        content: Text(
                          // Content is just centered text now
                          'Esta funcionalidade estará disponível brevemente.',
                          style: dialogTheme.textTheme.bodyMedium?.copyWith(
                            color: dialogTheme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  );
                };
              } else {
                // If category is available, set onTap to proceed
                onTapAction = () => _handleCategorySelection(category);
              }

              return _buildSelectionTile(
                title: category.displayName,
                icon: _getCategoryIcon(category),
                onTap: onTapAction, // Use the determined onTapAction
                isDisabled: !category.isAvailable,
              );
            }),
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
            ...EnergyType.values.map(
              (type) => _buildSelectionTile(
                title: type.displayName,
                icon: _getEnergyTypeIcon(type),
                onTap:
                    () => _handleEnergyTypeSelection(
                      type,
                    ), // Correct onTap for this step
                // isDisabled is not typically needed here as all energy types are usually selectable
              ),
            ),
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
            _buildClientCard(
              title: 'Empresarial',
              imagePath: 'assets/images/edp_logo_br.png',
              onTap: () => _handleClientTypeSelection(ClientType.commercial),
            ),
            // Conditionally show Residential card only if not Solar
            if (_selectedEnergyType != EnergyType.solar) ...[
              _buildClientCard(
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
              _buildTextField(
                controller: _companyNameController,
                label: 'Nome da Empresa',
                hint: 'Insira o nome da empresa',
                onChanged:
                    (value) =>
                        notifier.updateFormFields({'companyName': value}),
              ),
              const SizedBox(height: AppConstants.spacing16),
            ],
            _buildTextField(
              controller: _responsibleNameController,
              label: 'Nome do Responsável',
              hint: 'Insira o nome do responsável',
              onChanged:
                  (value) =>
                      notifier.updateFormFields({'responsibleName': value}),
            ),
            const SizedBox(height: AppConstants.spacing16),
            _buildTextField(
              controller: _nifController,
              label: 'NIF',
              hint: 'Insira o NIF',
              keyboardType: TextInputType.number,
              onChanged: (value) => notifier.updateFormFields({'nif': value}),
            ),
            const SizedBox(height: AppConstants.spacing16),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'Insira o email de contacto',
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) => notifier.updateFormFields({'email': value}),
            ),
            const SizedBox(height: AppConstants.spacing16),
            _buildTextField(
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    final theme = Theme.of(context);
    final cupertinoTheme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine background color similar to ChangePasswordPage
    final Color textFieldBackgroundColor = CupertinoDynamicColor.resolve(
        isDark ? CupertinoColors.darkBackgroundGray : CupertinoColors.systemGrey6,
        context);

    final Color placeholderColor = CupertinoDynamicColor.resolve(CupertinoColors.placeholderText, context);
    final Color textColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoTextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          placeholder: label,
          placeholderStyle: TextStyle(
            color: placeholderColor,
          ),
          style: cupertinoTheme.textTheme.textStyle.copyWith(
            color: textColor,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: textFieldBackgroundColor,
            borderRadius: BorderRadius.circular(8.0),
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
