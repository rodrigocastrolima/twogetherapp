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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../widgets/success_dialog.dart'; // Import the success dialog

class ServicesPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? preFilledData;

  const ServicesPage({super.key, this.preFilledData});

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
    if (!category.isAvailable) return;

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
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final formNotifier = ref.read(serviceSubmissionProvider.notifier);
      final userRepo = ref.read(repo.serviceSubmissionRepositoryProvider);
      final userData = await userRepo.getCurrentUserData();

      if (userData == null) throw Exception(l10n.servicesUserAuthError);

      final success = await formNotifier.submitServiceRequest(
        resellerId: userData['uid'] ?? '',
        resellerName: userData['displayName'] ?? userData['email'] ?? 'Unknown',
      );

      if (success && mounted) {
        // Show the success dialog FIRST
        await showSuccessDialog(
          context: context,
          message:
              l10n.servicesSubmissionSuccessMessage, // Use the new l10n key
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
              formState.errorMessage ?? l10n.servicesSubmissionError;
        });
      }
    } catch (e) {
      debugPrint('Error submitting form: $e');
      setState(() {
        _errorMessage = l10n.servicesSubmissionErrorGeneric(e.toString());
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
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context)!;

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
        title: null,
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
            final isCompleted = currentStep > stepIndex;

            Widget circle = Container(
              width: isCurrent ? 28 : 24,
              height: isCurrent ? 28 : 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isActive ? colorScheme.primary : colorScheme.surfaceVariant,
                border:
                    isCurrent
                        ? Border.all(color: colorScheme.primary, width: 2)
                        : isActive
                        ? null
                        : Border.all(color: colorScheme.outlineVariant),
              ),
              child: Center(
                child: Text(
                  '$stepIndex',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        isActive
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );

            // Apply pulse animation only if current
            return isCurrent
                ? ScaleTransition(scale: _pulseAnimation, child: circle)
                : circle;
          } else {
            // Line
            final stepIndex = index ~/ 2 + 1;
            final isActive = currentStep > stepIndex;
            final isCompleted = currentStep > stepIndex;
            return Expanded(
              child: Container(
                height: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color:
                      isCompleted
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                ),
              ),
            );
          }
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    final l10n = AppLocalizations.of(context)!;
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
        return Center(child: Text(l10n.servicesStepInvalid));
    }
  }

  // --- Step Builder Methods --- //

  Widget _buildServiceCategoryStep() {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context)!;

    return ScrollConfiguration(
      behavior: const NoScrollbarBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.servicesPageTitle,
              style: textTheme.headlineMedium?.copyWith(
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context)!;

    return ScrollConfiguration(
      behavior: const NoScrollbarBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.servicesEnergyPageTitle, style: textTheme.headlineMedium),
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Common structure for title and subtitle
    Widget buildHeader() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.servicesClientTypePageTitle,
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: AppConstants.spacing4),
          Text(
            l10n.servicesClientTypePageSubtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
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
              title: l10n.servicesClientTypeCommercialTitle,
              subtitle: l10n.servicesClientTypeCommercialSubtitle,
              imagePath: 'assets/images/edp_logo_br.png',
              onTap: () => _handleClientTypeSelection(ClientType.commercial),
            ),
            // Conditionally show Residential card only if not Solar
            if (_selectedEnergyType != EnergyType.solar) ...[
              const SizedBox(height: AppConstants.spacing16),
              _buildClientCard(
                title: l10n.servicesClientTypeResidentialTitle,
                subtitle: l10n.servicesClientTypeResidentialSubtitle,
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
    final l10n = AppLocalizations.of(context)!;

    final notifier = ref.read(serviceSubmissionProvider.notifier);

    return ScrollConfiguration(
      behavior: const NoScrollbarBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.servicesFormTitle, style: textTheme.headlineMedium),
            const SizedBox(height: AppConstants.spacing24),
            if (_selectedClientType == ClientType.commercial) ...[
              _buildTextField(
                controller: _companyNameController,
                label: l10n.servicesFormCompanyNameLabel,
                hint: l10n.servicesFormCompanyNameHint,
                onChanged:
                    (value) =>
                        notifier.updateFormFields({'companyName': value}),
              ),
              const SizedBox(height: AppConstants.spacing16),
            ],
            _buildTextField(
              controller: _responsibleNameController,
              label: l10n.servicesFormResponsibleNameLabel,
              hint: l10n.servicesFormResponsibleNameHint,
              onChanged:
                  (value) =>
                      notifier.updateFormFields({'responsibleName': value}),
            ),
            const SizedBox(height: AppConstants.spacing16),
            _buildTextField(
              controller: _nifController,
              label: l10n.servicesFormNifLabel,
              hint: l10n.servicesFormNifHint,
              keyboardType: TextInputType.number,
              onChanged: (value) => notifier.updateFormFields({'nif': value}),
            ),
            const SizedBox(height: AppConstants.spacing16),
            _buildTextField(
              controller: _emailController,
              label: l10n.servicesFormEmailLabel,
              hint: l10n.servicesFormEmailHint,
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) => notifier.updateFormFields({'email': value}),
            ),
            const SizedBox(height: AppConstants.spacing16),
            _buildTextField(
              controller: _phoneController,
              label: l10n.servicesFormPhoneLabel,
              hint: l10n.servicesFormPhoneHint,
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
                          l10n.servicesSubmitButtonLabel,
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

    final Color effectiveIconColor =
        isDisabled
            ? colorScheme.onSurface.withOpacity(0.38)
            : colorScheme.primary;
    final Color effectiveTextColor =
        isDisabled
            ? colorScheme.onSurface.withOpacity(0.38)
            : colorScheme.onSurface;
    final Color effectiveTileColor = colorScheme.surfaceContainerHighest
        .withOpacity(0.5);

    return Card(
      elevation: 1.0,
      margin: const EdgeInsets.only(bottom: AppConstants.spacing12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacing16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withOpacity(isDisabled ? 0.1 : 0.2),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(icon, color: effectiveIconColor, size: 24),
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
    );
  }

  Widget _buildClientCard({
    required String title,
    required String subtitle,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      elevation: 1.0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacing16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacing4),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spacing16),
              SizedBox(
                width: 80,
                height: 40,
                child: Image.asset(imagePath, fit: BoxFit.contain),
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
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            bottom: AppConstants.spacing8,
            left: AppConstants.spacing4,
          ),
          child: Text(
            label,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacing16,
              vertical: AppConstants.spacing16,
            ),
          ),
          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
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
