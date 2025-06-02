import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



import '../../../../features/auth/domain/models/app_user.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/opportunity/data/models/salesforce_opportunity.dart';
import '../../../../features/salesforce/presentation/providers/salesforce_providers.dart';
import '../../../../presentation/widgets/logo.dart';
import '../../../../presentation/widgets/app_loading_indicator.dart';
import '../../../../core/models/notification.dart';
import '../../../notifications/data/repositories/notification_repository.dart';
import '../../../../presentation/widgets/simple_list_item.dart';
import '../../../../presentation/widgets/app_input_field.dart';
import '../../../../core/services/salesforce_auth_service.dart';
// Removed import of non-existent file
// import '../../../../features/admin/presentation/widgets/submission_details_dialog.dart';
// Removed l10n import
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class UserDetailPage extends ConsumerStatefulWidget {
  final AppUser user;

  // Apply use_super_parameters fix
  const UserDetailPage({super.key, required this.user});

  @override
  ConsumerState<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends ConsumerState<UserDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isEditing = false;
  bool _isLoading = true;
  String? _errorMessage;

  // Controllers for editable fields
  late TextEditingController _displayNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _phoneSecondaryController;
  late TextEditingController _emailSecondaryController;
  late TextEditingController _birthDateController;
  late TextEditingController _collaboratorNifController;
  late TextEditingController _ccNumberController;
  late TextEditingController _ssNumberController;
  late TextEditingController _addressController;
  late TextEditingController _postalCodeController;
  late TextEditingController _cityController;
  late TextEditingController _districtController;
  late TextEditingController _tipologiaController;
  late TextEditingController _atividadeComercialController;
  late TextEditingController _commercialCodeController;
  late TextEditingController _companyNifController;
  late TextEditingController _ibanController;
  late TextEditingController _resellerNameController;
  late TextEditingController _joinedDateController;

  // Date picker state variables
  DateTime? _joinedDate;
  DateTime? _birthDate;

  // Initialize with widget.user to prevent late initialization error
  late AppUser _localUserCopy = widget.user;

  // Add at the top of _UserDetailPageState:
  late Future<List<SalesforceOpportunity>> _opportunitiesFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeControllersAndDates();
    _initializeUserData();
    _initOpportunitiesFuture();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _phoneSecondaryController.dispose();
    _emailSecondaryController.dispose();
    _birthDateController.dispose();
    _joinedDateController.dispose();
    _collaboratorNifController.dispose();
    _ccNumberController.dispose();
    _ssNumberController.dispose();
    _addressController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _tipologiaController.dispose();
    _atividadeComercialController.dispose();
    _commercialCodeController.dispose();
    _companyNifController.dispose();
    _ibanController.dispose();
    _resellerNameController.dispose();
    super.dispose();
  }

  // New method to initialize user data
  Future<void> _initializeUserData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(widget.user.uid).get();
      
      if (userDoc.exists) {
        if (mounted) {
          final data = userDoc.data()!;
          // Defensive patch: ensure all required fields exist (set to null if missing)
          data['uid'] = userDoc.id;
          data['email'] = data['email'];
          data['role'] = data['role'];
          data['displayName'] = data['displayName'];
          data['photoURL'] = data['photoURL'];
          data['salesforceId'] = data['salesforceId'];
          data['isFirstLogin'] = data['isFirstLogin'];
          data['isEmailVerified'] = data['isEmailVerified'];
          // Ensure additionalData is always a Map<String, dynamic> with String keys
          if (data['additionalData'] == null) {
            data['additionalData'] = {};
          } else if (data['additionalData'] is! Map<String, dynamic>) {
            try {
              data['additionalData'] = Map<String, dynamic>.from(
                (data['additionalData'] as Map).map((k, v) => MapEntry(k.toString(), v)),
              );
            } catch (_) {
              try {
                data['additionalData'] = Map.castFrom<dynamic, dynamic, String, dynamic>(data['additionalData'] as Map);
              } catch (_) {
                data['additionalData'] = {};
              }
            }
          }
          setState(() {
            _localUserCopy = AppUser.fromJson(data);
            _initializeControllersAndDates();
            _isLoading = false;
            _initOpportunitiesFuture();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Save user profile changes
  Future<void> _saveUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // Prepare data for update
      final Map<String, dynamic> fieldsToUpdate = {};

      // Compare and add fields to update map (compare with _localUserCopy)
      if (_displayNameController.text.trim() != (_localUserCopy.displayName ?? '')) {
        fieldsToUpdate['displayName'] = _displayNameController.text.trim();
      }
      if (_phoneController.text.trim() != (_localUserCopy.additionalData['phoneNumber'] ?? '')) {
        fieldsToUpdate['phoneNumber'] = _phoneController.text.trim();
      }
      if (_phoneSecondaryController.text.trim() != (_localUserCopy.additionalData['phoneSecondary'] ?? '')) {
        fieldsToUpdate['phoneSecondary'] = _phoneSecondaryController.text.trim();
      }
      if (_emailSecondaryController.text.trim() != (_localUserCopy.additionalData['emailSecondary'] ?? '')) {
        fieldsToUpdate['emailSecondary'] = _emailSecondaryController.text.trim();
      }

      // Handle birth_date (convert DateTime to ISO 8601 string)
      final currentBirthDateString = _localUserCopy.additionalData['birthDate'] != null
          ? DateTime.parse(_localUserCopy.additionalData['birthDate']).toIso8601String()
          : null;
      final newBirthDateString = _birthDate?.toIso8601String();
      if (newBirthDateString != currentBirthDateString) {
        fieldsToUpdate['birthDate'] = newBirthDateString;
      }

      if (_collaboratorNifController.text.trim() != (_localUserCopy.additionalData['collaboratorNif'] ?? '')) {
        fieldsToUpdate['collaboratorNif'] = _collaboratorNifController.text.trim();
      }
      if (_ccNumberController.text.trim() != (_localUserCopy.additionalData['ccNumber'] ?? '')) {
        fieldsToUpdate['ccNumber'] = _ccNumberController.text.trim();
      }
      if (_ssNumberController.text.trim() != (_localUserCopy.additionalData['ssNumber'] ?? '')) {
        fieldsToUpdate['ssNumber'] = _ssNumberController.text.trim();
      }
      if (_addressController.text.trim() != (_localUserCopy.additionalData['address'] ?? '')) {
        fieldsToUpdate['address'] = _addressController.text.trim();
      }
      if (_postalCodeController.text.trim() != (_localUserCopy.additionalData['postalCode'] ?? '')) {
        fieldsToUpdate['postalCode'] = _postalCodeController.text.trim();
      }
      if (_cityController.text.trim() != (_localUserCopy.additionalData['city'] ?? '')) {
        fieldsToUpdate['city'] = _cityController.text.trim();
      }
      if (_districtController.text.trim() != (_localUserCopy.additionalData['district'] ?? '')) {
        fieldsToUpdate['district'] = _districtController.text.trim();
      }
      if (_tipologiaController.text.trim() != (_localUserCopy.additionalData['tipologia'] ?? '')) {
        fieldsToUpdate['tipologia'] = _tipologiaController.text.trim();
      }
      if (_atividadeComercialController.text.trim() != (_localUserCopy.additionalData['atividadeComercial'] ?? '')) {
        fieldsToUpdate['atividadeComercial'] = _atividadeComercialController.text.trim();
      }
      if (_commercialCodeController.text.trim() != (_localUserCopy.additionalData['commercialCode'] ?? '')) {
        fieldsToUpdate['commercialCode'] = _commercialCodeController.text.trim();
      }
      if (_companyNifController.text.trim() != (_localUserCopy.additionalData['companyNif'] ?? '')) {
        fieldsToUpdate['companyNif'] = _companyNifController.text.trim();
      }
      if (_ibanController.text.trim() != (_localUserCopy.additionalData['iban'] ?? '')) {
        fieldsToUpdate['iban'] = _ibanController.text.trim();
      }
      if (_resellerNameController.text.trim() != (_localUserCopy.additionalData['resellerName'] ?? '')) {
        fieldsToUpdate['resellerName'] = _resellerNameController.text.trim();
      }

      // Handle joined_date (convert DateTime to ISO 8601 string)
      final currentJoinedDateString = _localUserCopy.additionalData['joinedDate'] != null
          ? DateTime.parse(_localUserCopy.additionalData['joinedDate']).toIso8601String()
          : null;
      final newJoinedDateString = _joinedDate?.toIso8601String();
      if (newJoinedDateString != currentJoinedDateString) {
        fieldsToUpdate['joinedDate'] = newJoinedDateString;
      }

      // Only update if there are changes
      if (fieldsToUpdate.isNotEmpty) {
        fieldsToUpdate['updatedAt'] = FieldValue.serverTimestamp();

        await firestore.collection('users').doc(widget.user.uid).update(fieldsToUpdate);

        // Refresh user data after saving
        await _initializeUserData();

        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
      } else {
        // No changes to save
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao atualizar perfil: ${e.toString()}';
      });
    }
  }

  // Reset user password
  Future<void> _resetPassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.sendPasswordResetEmail(widget.user.email);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email de redefinição de senha enviado'),
          ), // Hardcoded Portuguese
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Erro ao enviar redefinição de senha: ${e.toString()}'; // Hardcoded Portuguese
      });
    }
  }

   // Helper to initialize or update controllers and date pickers based on _localUserCopy
  void _initializeControllersAndDates() {
    _displayNameController = TextEditingController(
      text: _localUserCopy.displayName ?? '',
    );
    _emailController = TextEditingController(text: _localUserCopy.email);
    _phoneController = TextEditingController(
      text: _localUserCopy.additionalData['phoneNumber']?.toString().trim().isNotEmpty == true
          ? _localUserCopy.additionalData['phoneNumber']
          : (_localUserCopy.additionalData['mobilePhone']?.toString().trim().isNotEmpty == true
              ? _localUserCopy.additionalData['mobilePhone']
              : ''),
    );
    _phoneSecondaryController = TextEditingController(
      text: _localUserCopy.additionalData['phoneSecondary'] ?? '',
    );
    _emailSecondaryController = TextEditingController(
      text: _localUserCopy.additionalData['emailSecondary'] ?? '',
    );
     _birthDateController = TextEditingController(
      text: _localUserCopy.additionalData['birthDate'] != null
          ? DateFormat('dd/MM/yyyy').format(DateTime.parse(_localUserCopy.additionalData['birthDate']))
          : '',
    );
    _joinedDateController = TextEditingController(
      text: _localUserCopy.additionalData['joinedDate'] != null
          ? DateFormat('dd/MM/yyyy').format(DateTime.parse(_localUserCopy.additionalData['joinedDate']))
          : '',
    );
    _collaboratorNifController = TextEditingController(
      text: _localUserCopy.additionalData['collaboratorNif'] ?? '',
    );
    _ccNumberController = TextEditingController(
      text: _localUserCopy.additionalData['ccNumber'] ?? '',
    );
    _ssNumberController = TextEditingController(
      text: _localUserCopy.additionalData['ssNumber'] ?? '',
    );
    _addressController = TextEditingController(
      text: _localUserCopy.additionalData['address'] ?? '',
    );
    _postalCodeController = TextEditingController(
      text: _localUserCopy.additionalData['postalCode'] ?? '',
    );
    _cityController = TextEditingController(
      text: _localUserCopy.additionalData['city'] ?? '',
    );
    _districtController = TextEditingController(
      text: _localUserCopy.additionalData['district'] ?? '',
    );
    _tipologiaController = TextEditingController(
      text: _localUserCopy.additionalData['tipologia'] ?? '',
    );
    _atividadeComercialController = TextEditingController(
      text: _localUserCopy.additionalData['atividadeComercial'] ?? '',
    );
    _commercialCodeController = TextEditingController(
      text: _localUserCopy.additionalData['commercialCode'] ?? '',
    );
    _companyNifController = TextEditingController(
      text: _localUserCopy.additionalData['companyNif'] ?? '',
    );
    _ibanController = TextEditingController(
      text: _localUserCopy.additionalData['iban'] ?? '',
    );
    _resellerNameController = TextEditingController(
      text: _localUserCopy.additionalData['resellerName']?.toString().trim().isNotEmpty == true
          ? _localUserCopy.additionalData['resellerName']
          : (_localUserCopy.additionalData['revendedorRetail']?.toString().trim().isNotEmpty == true
              ? _localUserCopy.additionalData['revendedorRetail']
              : ''),
    );

    if (_localUserCopy.additionalData['joinedDate'] != null) {
      _joinedDate = DateTime.parse(_localUserCopy.additionalData['joinedDate']);
    } else {
      _joinedDate = null;
    }
    if (_localUserCopy.additionalData['birthDate'] != null) {
      _birthDate = DateTime.parse(_localUserCopy.additionalData['birthDate']);
    } else {
      _birthDate = null;
    }
  }

   // --- ADDED: Cancel Edit --- //
  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      // Restore original data by re-initializing controllers/dates from the current _localUserCopy
      _initializeControllersAndDates();
    });
  }

   // --- NEW: Toggle Edit --- //
  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
         // If cancelling, restore original data from the current _localUserCopy
         _initializeControllersAndDates();
      }
    });
  }

  void _initOpportunitiesFuture() {
    final salesforceId = _getSalesforceId();
    if (salesforceId.isNotEmpty && salesforceId != 'Não vinculado') {
      final salesforceRepo = ref.read(salesforceRepositoryProvider);
      _opportunitiesFuture = salesforceRepo.getResellerOpportunities(salesforceId);
    } else {
      _opportunitiesFuture = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 700;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: _isLoading
          ? null // No AppBar when loading
          : AppBar(
              leading: IconButton(
                icon: Icon(CupertinoIcons.chevron_left, color: theme.colorScheme.onSurface),
                onPressed: () => context.pop(),
              ),
              title: LogoWidget(height: 60, darkMode: isDarkMode),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              scrolledUnderElevation: 0.0,
            ),
      body: _isLoading
          ? const AppLoadingIndicator() // Use AppLoadingIndicator instead of CircularProgressIndicator
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                    // Page Title (centered, no actions)
                    Padding(
                      padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 0),
                child: Row(
                  children: [
                          // Title (left-aligned)
                          Text(
                            'Detalhes do Utilizador',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.left,
                          ),
                          const Spacer(),
                          // Action buttons (middle/right) - only show when not editing
                          if (!_isEditing) ...[
                            IconButton(
                              icon: Icon(Icons.lock_reset, color: theme.colorScheme.primary),
                              tooltip: 'Enviar email de redefinição de senha',
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Alterar Senha'),
                                    content: const Text('Tem a certeza que deseja enviar um email de redefinição de senha para este utilizador?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text('Confirmar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await _resetPassword();
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(CupertinoIcons.paperplane, color: theme.colorScheme.primary),
                              tooltip: 'Enviar notificação',
                              onPressed: () async {
                                await showDialog(
                                  context: context,
                                  builder: (context) => _NotificationDialog(userId: _localUserCopy.uid),
                                );
                              },
                            ),
                            const SizedBox(width: 24),
                          ],
                          // Edit/cancel/save buttons (right)
                          if (_isEditing) ...[
                            IconButton(
                              icon: Icon(Icons.close, color: theme.colorScheme.error, size: 28),
                              tooltip: 'Cancelar Edição',
                              onPressed: _cancelEdit,
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (_tabController.index == 0) // Only show edit button on Informação Pessoal tab
                            IconButton(
                              icon: _isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                      ),
                                    )
                                  : Icon(
                                      _isEditing ? Icons.save_outlined : CupertinoIcons.pencil,
                                      color: theme.colorScheme.primary,
                                      size: 28,
                                    ),
                              onPressed: _isLoading ? null : (_isEditing ? _saveUserProfile : _toggleEdit),
                              tooltip: _isEditing ? 'Guardar' : 'Editar',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shape: _isEditing ? const CircleBorder() : null,
                                padding: _isEditing ? const EdgeInsets.all(0) : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildUserHeader(context, theme),
                    const SizedBox(height: 24),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(2, (i) {
                            final selected = _tabController.index == i;
                            final color = theme.colorScheme.primary;
                            final label = i == 0 ? 'Informação Pessoal' : 'Oportunidades';
                            final icon = i == 0 ? Icons.person_outline : Icons.work_outline;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => setState(() => _tabController.index = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected ? color.withAlpha((255 * 0.06).round()) : Colors.transparent,
                                    border: Border.all(
                                      color: selected ? color : Colors.transparent,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(icon, color: color, size: 18),
                          const SizedBox(width: 8),
                                      Text(
                                        label,
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          color: color,
                                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
              ),
            ),
            const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                controller: _tabController,
                  children: [
                          _buildProfileTab(context, isSmallScreen),
                  _buildOpportunitiesTab(context),
                ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // --- New Method for User Header ---
  Widget _buildUserHeader(BuildContext context, ThemeData theme) {
    // Use _localUserCopy for displaying name and email
    final bool isDark = theme.brightness == Brightness.dark;

    // Replicate style from ProfilePage's _buildProfileContent -> Centered Avatar section
    return Center(
                child: Column(
                  children: [
          // Centered avatar
                    CircleAvatar(
            radius: 50,
            backgroundColor: theme.colorScheme.primary.withAlpha((255 * (isDark ? 0.2 : 0.1)).round()), // Use theme color with opacity
                      child: Text(
              _getInitials(), // Use existing _getInitials method
              style: TextStyle(
                fontSize: 36,
                  fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary, // Use theme color
                        ),
                      ),
                    ),
          const SizedBox(height: 12), // Spacing between avatar and name/email
          // Name and email centered below avatar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0, // Adjust padding for consistency
            ),
                  child: Column(
                    children: [
                Text(
                          _localUserCopy.displayName?.isNotEmpty == true
                              ? _localUserCopy.displayName!
                              : 'Utilizador Desconhecido', // Hardcoded Portuguese
                  style: theme.textTheme.headlineSmall?.copyWith( // Use headlineSmall as in ProfilePage
                            fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface, // Use theme color
                          ),
                          textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4), // Spacing between name and email
                Text(
                  _localUserCopy.email, // Use _localUserCopy for email
                  style: theme.textTheme.bodyMedium?.copyWith( // Use bodyMedium as in ProfilePage (approximated) with opacity
                    fontSize: 14, // Explicitly set font size for consistency
                    color: theme.colorScheme.onSurface.withAlpha((255 * 0.7).round()), // Use theme color with opacity
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(
    BuildContext context,
    bool isSmallScreen,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0), // Adjust padding
      child: SingleChildScrollView(
                  child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
            if (_errorMessage != null) ...[ // Keep error message display
              const SizedBox(height: 16), // Add spacing before error message
                          Container(
                padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                  color: Colors.red.withAlpha((255 * 0.1).round()), // Use withOpacity as per lint rules
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red), // Use standard error color
                    const SizedBox(width: 8),
                    Expanded(
                            child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red), // Use standard error color
                      ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16), // Add spacing after error message
            ],

            // --- Informação Pessoal Section ---
            _buildUserDetailSectionTwoColumn(
              context,
              'Informação Pessoal', // Hardcoded Portuguese
              [
                // LEFT COLUMN
                [
                    AppInputField(
                      controller: _displayNameController,
                      label: 'Nome do Colaborador',
                      readOnly: !_isEditing,
                      onChanged: _isEditing ? (v) => setState(() {}) : null,
                    ),
                    AppInputField(
                      controller: _emailController,
                      label: 'Email Principal',
                      readOnly: !_isEditing,
                      onChanged: _isEditing ? (v) => setState(() {}) : null,
                    ),
                    AppInputField(
                      controller: _phoneController,
                      label: 'Telefone Principal',
                      readOnly: !_isEditing,
                      onChanged: _isEditing ? (v) => setState(() {}) : null,
                    ),
                  AppInputField(
                    controller: _emailSecondaryController,
                    label: 'Email Secundário',
                    readOnly: !_isEditing,
                    onChanged: _isEditing ? (v) => setState(() {}) : null,
                  ),
                  AppInputField(
                    controller: _phoneSecondaryController,
                    label: 'Telefone Secundário',
                    readOnly: !_isEditing,
                    onChanged: _isEditing ? (v) => setState(() {}) : null,
                  ),
                ],
                // RIGHT COLUMN
                [
                   _isEditing
                      ? AppDateInputField(
                          label: 'Data de Nascimento',
                          value: _birthDate,
                          onChanged: (pickedDate) => setState(() => _birthDate = pickedDate),
                        )
                      : AppInputField(
                          controller: _birthDateController,
                          label: 'Data de Nascimento',
                          readOnly: true,
                        ),
                   _isEditing
                      ? AppInputField(
                          controller: _resellerNameController,
                          label: 'Nome do Revendedor',
                          readOnly: !_isEditing,
                          onChanged: _isEditing ? (v) => setState(() {}) : null,
                        )
                      : AppInputField(
                          controller: _resellerNameController,
                          label: 'Nome do Revendedor',
                          readOnly: true,
                        ),
                    _isEditing
                      ? AppDateInputField(
                          label: 'Data de Registo',
                          value: _joinedDate,
                          onChanged: (pickedDate) => setState(() => _joinedDate = pickedDate),
                        )
                      : AppInputField(
                          controller: _joinedDateController,
                          label: 'Data de Registo',
                          readOnly: true,
                        ),
                  AppInputField(
                    controller: TextEditingController(text: _getSalesforceId()),
                    label: 'ID Salesforce',
                    readOnly: true,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24), // Spacing between sections

            // --- Identificadores & Legal Section ---
             _buildUserDetailSectionTwoColumn(
                        context,
              'Informação Legal', // Hardcoded Portuguese
              [
                // LEFT COLUMN
                [
                  AppInputField(
                    controller: _collaboratorNifController,
                    label: 'NIF (Pessoal)',
                    readOnly: !_isEditing,
                    onChanged: _isEditing ? (v) => setState(() {}) : null,
                  ),
                   AppInputField(
                    controller: _ccNumberController,
                    label: 'CC',
                    readOnly: !_isEditing,
                    onChanged: _isEditing ? (v) => setState(() {}) : null,
                  ),
                   AppInputField(
                    controller: _ssNumberController,
                    label: 'SS',
                    readOnly: !_isEditing,
                    onChanged: _isEditing ? (v) => setState(() {}) : null,
                  ),
                ],
                // RIGHT COLUMN
                [
                   AppInputField(
                    controller: _companyNifController,
                    label: 'NIF (Empresa)',
                    readOnly: !_isEditing,
                    onChanged: _isEditing ? (v) => setState(() {}) : null,
                  ),
                    AppInputField(
                    controller: _commercialCodeController,
                    label: 'Código Comercial',
                    readOnly: !_isEditing,
                    onChanged: _isEditing ? (v) => setState(() {}) : null,
                  ),
                     AppInputField(
                    controller: _ibanController,
                    label: 'IBAN',
                    readOnly: !_isEditing,
                    onChanged: _isEditing ? (v) => setState(() {}) : null,
                  ),
                ],
              ],
            ),

             const SizedBox(height: 24), // Spacing between sections

            // --- Localização Section ---
            _buildUserDetailSectionTwoColumn(
                        context,
              'Localização', // Hardcoded Portuguese
              [
                // LEFT COLUMN
                [
                   AppInputField(
                    controller: _addressController,
                    label: 'Morada',
                    readOnly: !_isEditing,
                    onChanged: _isEditing ? (v) => setState(() {}) : null,
                  ),
                   AppInputField(
                    controller: _postalCodeController,
                    label: 'Código Postal',
                    readOnly: !_isEditing,
                    onChanged: _isEditing ? (v) => setState(() {}) : null,
                  ),
                   AppInputField(
                    controller: _cityController,
                    label: 'Localidade',
                    readOnly: !_isEditing,
                    onChanged: _isEditing ? (v) => setState(() {}) : null,
                  ),
                ],
                // RIGHT COLUMN
                [
                   AppInputField(
                    controller: _districtController,
                    label: 'Distrito',
                    readOnly: !_isEditing,
                    onChanged: _isEditing ? (v) => setState(() {}) : null,
                  ),
                   AppInputField(
                    controller: _tipologiaController,
                    label: 'Tipologia',
                    readOnly: !_isEditing,
                    onChanged: _isEditing ? (v) => setState(() {}) : null,
                  ),
                    AppInputField(
                    controller: _atividadeComercialController,
                    label: 'Atividade Comercial',
                    readOnly: !_isEditing,
                    onChanged: _isEditing ? (v) => setState(() {}) : null,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpportunitiesTab(BuildContext context) {
    final String salesforceId = _getSalesforceId();
    final theme = Theme.of(context);
    final salesforceAuthState = ref.watch(salesforceAuthProvider);

    if (salesforceAuthState != SalesforceAuthState.authenticated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withAlpha((255 * 0.5).round()),
              ),
              const SizedBox(height: 16),
              Text(
                'Salesforce não está conectado',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Para ver as oportunidades, conecte o Salesforce nas definições.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (salesforceId.isEmpty || salesforceId == 'Não vinculado') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withAlpha((255 * 0.5).round()),
              ),
              const SizedBox(height: 16),
              Text(
                'Salesforce Não Vinculado',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Este utilizador não tem um ID Salesforce vinculado.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<List<SalesforceOpportunity>>(
      future: _opportunitiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Erro ao Carregar Oportunidades',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Não foi possível obter as oportunidades do Salesforce. Por favor, tente novamente mais tarde.\nErro: ˜snapshot.error}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Recarregar'),
                    onPressed: () {
                      setState(_initOpportunitiesFuture);
                    },
                  ),
                ],
              ),
            ),
          );
        }
        final opportunities = snapshot.data ?? [];
        if (opportunities.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha((255 * 0.5).round()),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma Oportunidade Encontrada',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nenhuma oportunidade Salesforce encontrada para este revendedor.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          itemCount: opportunities.length,
          separatorBuilder: (_, __) => const SizedBox(height: 0),
          itemBuilder: (context, index) {
            final opportunity = opportunities[index];
            return SimpleListItem(
              title: opportunity.name,
              onTap: () {
                context.push('/admin/salesforce-opportunity-detail/${opportunity.id}');
              },
            );
          },
        );
      },
    );
  }

  // --- NEW: Helper to build a two-column detail section card ---
  Widget _buildUserDetailSectionTwoColumn(BuildContext context, String title, List<List<Widget>> columns) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1, // Add subtle elevation
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8), // Rounded corners
        side: BorderSide(color: theme.dividerColor.withAlpha(25)), // Subtle border
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Consistent padding
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start, // Align columns to the top
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: columns[0].expand((widget) => [widget, const SizedBox(height: 16)]).toList(), // Add spacing between items
                    ),
                  ),
                  const SizedBox(width: 32), // Spacing between columns
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                       children: columns[1].expand((widget) => [widget, const SizedBox(height: 16)]).toList(), // Add spacing between items
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper method to get initials (Keep as is) ---
  String _getInitials() {
    // Use _localUserCopy for initials display
    final name = _localUserCopy.displayName ?? ''; // Use local user copy, default to empty string if null
    final email = _localUserCopy.email; // Use local user copy (email is required in model)

    if (name.isEmpty) {
      return email.isNotEmpty ? email[0].toUpperCase() : '?';
    }

    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?'; // Should not be empty here due to check above
  }

  String _getSalesforceId() {
    final topLevel = _localUserCopy.salesforceId;
    final additional = _localUserCopy.additionalData['salesforceId'];
    if (topLevel != null && topLevel.toString().trim().isNotEmpty) return topLevel;
    if (additional != null && additional.toString().trim().isNotEmpty) return additional;
    return 'Não vinculado';
  }
}

class _NotificationDialog extends ConsumerStatefulWidget {
  final String userId;
  const _NotificationDialog({required this.userId});

  @override
  ConsumerState<_NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends ConsumerState<_NotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSending = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 60, 0), // Leave space for close button
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Icon(Icons.notification_important, color: colorScheme.primary, size: 24),
                              const SizedBox(width: 8),
                              Text('Enviar Notificação', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(CupertinoIcons.xmark, size: 22),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Fechar',
                          splashRadius: 20,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(_error!, style: TextStyle(color: colorScheme.error)),
                    ),
                  if (_success != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(_success!, style: TextStyle(color: colorScheme.secondary)),
                    ),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Título',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Insira um título' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      labelText: 'Mensagem',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                    ),
                    minLines: 3,
                    maxLines: 6,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Insira uma mensagem' : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        icon: _isSending
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send),
                        label: const Text('Enviar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSending
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) return;
                                setState(() {
                                  _isSending = true;
                                  _error = null;
                                  _success = null;
                                });
                                try {
                                  final repo = ref.read(notificationRepositoryProvider);
                                  await repo.createNotification(
                                    userId: widget.userId,
                                    title: _titleController.text.trim(),
                                    message: _messageController.text.trim(),
                                    type: NotificationType.system,
                                  );
                                  if (!mounted) return;
                                  setState(() {
                                    _success = 'Notificação enviada!';
                                  });
                                  await Future.delayed(const Duration(seconds: 1));
                                  if (mounted) Navigator.of(context).pop();
                                } catch (e) {
                                  if (!mounted) return;
                                  setState(() {
                                    _error = 'Erro ao enviar notificação: $e';
                                  });
                                } finally {
                                  if (mounted) {
                                  setState(() {
                                    _isSending = false;
                                  });
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
