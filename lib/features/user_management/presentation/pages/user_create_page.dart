import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../presentation/widgets/logo.dart';
import '../../../../features/auth/domain/models/app_user.dart';
import '../../../../presentation/widgets/app_input_field.dart';
import '../../../../presentation/widgets/success_dialog.dart';

class UserCreatePage extends ConsumerStatefulWidget {
  const UserCreatePage({super.key});

  @override
  ConsumerState<UserCreatePage> createState() => _UserCreatePageState();
}

class _UserCreatePageState extends ConsumerState<UserCreatePage> {
  final _formKey = GlobalKey<FormState>();
  // Controllers for all fields
  final _resellerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _salesforceIdController = TextEditingController();
  final _collaboratorNameController = TextEditingController();
  final _mainPhoneController = TextEditingController();
  final _secondaryPhoneController = TextEditingController();
  final _secondaryEmailController = TextEditingController();
  DateTime? _birthDate;
  DateTime? _joinedDate;
  final _nifController = TextEditingController();
  final _ccController = TextEditingController();
  final _ssController = TextEditingController();
  final _companyNifController = TextEditingController();
  final _comercialCodeController = TextEditingController();
  final _ibanController = TextEditingController();
  final _addressController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _localityController = TextEditingController();
  final _districtController = TextEditingController();
  final _typologyController = TextEditingController();
  final _activityController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  // Add role dropdown state
  UserRole _selectedRole = UserRole.reseller;

  @override
  void dispose() {
    _resellerNameController.dispose();
    _emailController.dispose();
    _salesforceIdController.dispose();
    _collaboratorNameController.dispose();
    _mainPhoneController.dispose();
    _secondaryPhoneController.dispose();
    _secondaryEmailController.dispose();
    _nifController.dispose();
    _ccController.dispose();
    _ssController.dispose();
    _companyNifController.dispose();
    _comercialCodeController.dispose();
    _ibanController.dispose();
    _addressController.dispose();
    _postalCodeController.dispose();
    _localityController.dispose();
    _districtController.dispose();
    _typologyController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final email = _emailController.text.trim();
      final password = 'twogether2025';
      final role = _selectedRole.name;
      final firestoreData = {
        'displayName': _collaboratorNameController.text.trim(),
        'salesforceId': _salesforceIdController.text.trim(),
        'resellerName': _resellerNameController.text.trim(),
        'collaboratorName': _collaboratorNameController.text.trim(),
        'phoneNumber': _mainPhoneController.text.trim(),
        'mobilePhone': _mainPhoneController.text.trim(),
        'secondaryPhone': _secondaryPhoneController.text.trim(),
        'secondaryEmail': _secondaryEmailController.text.trim(),
        'birthDate': _birthDate != null ? DateFormat('yyyy-MM-dd').format(_birthDate!) : null,
        'joinedDate': _joinedDate != null ? DateFormat('yyyy-MM-dd').format(_joinedDate!) : null,
        'nif': _nifController.text.trim(),
        'cc': _ccController.text.trim(),
        'ss': _ssController.text.trim(),
        'companyNif': _companyNifController.text.trim(),
        'comercialCode': _comercialCodeController.text.trim(),
        'iban': _ibanController.text.trim(),
        'address': _addressController.text.trim(),
        'postalCode': _postalCodeController.text.trim(),
        'locality': _localityController.text.trim(),
        'district': _districtController.text.trim(),
        'typology': _typologyController.text.trim(),
        'activity': _activityController.text.trim(),
      };
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('createUserWithFirestore');
      final result = await callable.call({
        'email': email,
        'password': password,
        'role': role,
        'firestoreData': firestoreData,
      });
      // Show success dialog
      if (!mounted) return;
      await showSuccessDialog(
        context: context,
        message: 'Utilizador criado com sucesso',
        onDismissed: () {},
      );
      // Refresh user management page
      if (mounted) context.pop(true);
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? 'Erro ao criar utilizador (função).');
    } catch (e) {
      setState(() => _error = 'Erro ao criar utilizador: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTwoColumnSection(String title, List<Widget> left, List<Widget> right) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    // Pad columns to equal length for alignment
    final int maxLen = left.length > right.length ? left.length : right.length;
    final paddedLeft = List<Widget>.from(left)..addAll(List.generate(maxLen - left.length, (_) => const SizedBox.shrink()));
    final paddedRight = List<Widget>.from(right)..addAll(List.generate(maxLen - right.length, (_) => const SizedBox.shrink()));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.dividerColor.withAlpha(25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 16),
              isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: paddedLeft.map((w) => Padding(padding: const EdgeInsets.only(bottom: 4), child: w)).toList(),
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            children: paddedRight.map((w) => Padding(padding: const EdgeInsets.only(bottom: 4), child: w)).toList(),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        ...left.map((w) => Padding(padding: const EdgeInsets.only(bottom: 4), child: w)),
                        ...right.map((w) => Padding(padding: const EdgeInsets.only(bottom: 4), child: w)),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left),
          color: colorScheme.onSurface,
          onPressed: () => context.pop(),
        ),
        title: LogoWidget(height: 60, darkMode: theme.brightness == Brightness.dark),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'Criar Novo Utilizador',
                      style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTwoColumnSection(
                    'Tipo de Utilizador',
                    [
                      AppDropdownField<UserRole>(
                        label: 'Tipo de Utilizador',
                        value: _selectedRole,
                        items: const [
                          DropdownMenuItem(value: UserRole.admin, child: Text('Administrador')),
                          DropdownMenuItem(value: UserRole.reseller, child: Text('Revendedor')),
                        ],
                        onChanged: (role) {
                          if (role != null) setState(() => _selectedRole = role);
                        },
                      ),
                    ],
                    [],
                  ),
                  // --- Informação Pessoal ---
                  _buildTwoColumnSection(
                    'Informação Pessoal',
                    [
                      AppInputField(controller: _collaboratorNameController, label: 'Nome do Colaborador'),
                      AppInputField(controller: _emailController, label: 'Email *', keyboardType: TextInputType.emailAddress, validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null),
                      AppInputField(controller: _mainPhoneController, label: 'Telefone Principal', keyboardType: TextInputType.phone),
                      AppInputField(controller: _secondaryEmailController, label: 'Email Secundário', keyboardType: TextInputType.emailAddress),
                      AppInputField(controller: _secondaryPhoneController, label: 'Telefone Secundário', keyboardType: TextInputType.phone),
                    ],
                    [
                      AppDateInputField(label: 'Data de Nascimento', value: _birthDate, onChanged: (date) => setState(() => _birthDate = date)),
                      AppInputField(controller: _resellerNameController, label: 'Nome do Revendedor *', validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null),
                      AppDateInputField(label: 'Data de Registo', value: _joinedDate, onChanged: (date) => setState(() => _joinedDate = date)),
                      AppInputField(controller: _salesforceIdController, label: 'ID Salesforce *', validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // --- Informação Legal ---
                  _buildTwoColumnSection(
                    'Informação Legal',
                    [
                      AppInputField(controller: _nifController, label: 'NIF (Pessoal)'),
                      AppInputField(controller: _ccController, label: 'CC'),
                      AppInputField(controller: _ssController, label: 'SS'),
                    ],
                    [
                      AppInputField(controller: _companyNifController, label: 'NIF (Empresa)'),
                      AppInputField(controller: _comercialCodeController, label: 'Código Comercial'),
                      AppInputField(controller: _ibanController, label: 'IBAN'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // --- Localização ---
                  _buildTwoColumnSection(
                    'Localização',
                    [
                      AppInputField(controller: _addressController, label: 'Morada'),
                      AppInputField(controller: _postalCodeController, label: 'Código Postal'),
                      AppInputField(controller: _localityController, label: 'Localidade'),
                    ],
                    [
                      AppInputField(controller: _districtController, label: 'Distrito'),
                      AppInputField(controller: _typologyController, label: 'Tipologia'),
                      AppInputField(controller: _activityController, label: 'Atividade Comercial'),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(_error!, style: TextStyle(color: colorScheme.error)),
                    ),
                  const SizedBox(height: 24),
                  Center(
                    child: SizedBox(
                      width: 260,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _createUser,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Criar Utilizador'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 