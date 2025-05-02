import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/theme.dart';
import '../../../../features/auth/domain/models/app_user.dart';
import '../../../../features/auth/domain/repositories/auth_repository.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/opportunity/data/models/salesforce_opportunity.dart';
import '../../../../features/salesforce/presentation/providers/salesforce_providers.dart';
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
  bool _isLoading = false;
  String? _errorMessage;

  // Controllers for editable fields
  late TextEditingController _displayNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _departmentController;

  // Additional data
  Map<String, dynamic> _additionalData = {};
  bool _isEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _displayNameController = TextEditingController(
      text: widget.user.displayName ?? '',
    );
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(
      text: widget.user.additionalData['phoneNumber'] ?? '',
    );
    _departmentController = TextEditingController(
      text: widget.user.additionalData['department'] ?? '',
    );
    _additionalData = Map<String, dynamic>.from(widget.user.additionalData);
    _isEnabled = widget.user.additionalData['isEnabled'] ?? true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  // Save user profile changes
  Future<void> _saveUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // Update user data in Firestore
      await firestore.collection('users').doc(widget.user.uid).update({
        'displayName': _displayNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'department': _departmentController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Email requires Firebase Auth update - typically done through Cloud Functions
      if (_emailController.text.trim() != widget.user.email) {
        // In a real app, you'd call a Cloud Function to update the email
        // For now, just update the Firestore record
        await firestore.collection('users').doc(widget.user.uid).update({
          'email': _emailController.text.trim(),
        });
      }

      // Refresh additional data
      final updatedDoc =
          await firestore.collection('users').doc(widget.user.uid).get();
      setState(() {
        _additionalData = updatedDoc.data() ?? {};
        _isEditing = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso'),
          ), // Hardcoded Portuguese
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Erro ao atualizar perfil: ${e.toString()}'; // Hardcoded Portuguese
      });
    }
  }

  // Toggle user enabled/disabled status
  Future<void> _toggleUserStatus() async {
    final newStatus = !_isEnabled;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.setUserEnabled(widget.user.uid, newStatus);

      setState(() {
        _isEnabled = newStatus;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Utilizador ${newStatus ? "ativado" : "desativado"} com sucesso', // Hardcoded Portuguese
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Erro ao atualizar estado do utilizador: ${e.toString()}'; // Hardcoded Portuguese
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

  @override
  Widget build(BuildContext context) {
    // final l10n = AppLocalizations.of(context)!; // Remove l10n variable
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 700;

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestão de Utilizadores'), // Hardcoded Portuguese
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: 'Editar', // Hardcoded Portuguese
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveUserProfile,
              tooltip: 'Guardar', // Hardcoded Portuguese
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Informação Pessoal'), // Hardcoded Portuguese
            Tab(text: 'Oportunidades'), // Hardcoded Portuguese
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  // Profile Tab
                  _buildProfileTab(
                    context,
                    isSmallScreen,
                  ), // Removed l10n param
                  // Opportunities Tab
                  _buildOpportunitiesTab(context),
                ],
              ),
    );
  }

  Widget _buildProfileTab(
    BuildContext context,
    bool isSmallScreen,
    // AppLocalizations l10n, // Removed l10n param
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(
                    (255 * 0.1).round(),
                  ), // Replace withOpacity
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // User header with avatar and name
            Card(
              margin: EdgeInsets.zero,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          widget.user.role == UserRole.admin
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).colorScheme.primary,
                      radius: 48,
                      child: Text(
                        _displayNameController.text.isNotEmpty
                            ? _displayNameController.text[0].toUpperCase()
                            : _emailController.text.isNotEmpty
                            ? _emailController.text[0].toUpperCase()
                            : 'U', // Default initial
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _isEditing
                        ? TextField(
                          controller: _displayNameController,
                          decoration: InputDecoration(
                            labelText:
                                'Nome de Exibição', // Hardcoded Portuguese
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        )
                        : Text(
                          _displayNameController.text.isNotEmpty
                              ? _displayNameController.text
                              : 'Utilizador Desconhecido', // Hardcoded Portuguese
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (widget.user.role == UserRole.admin
                                    ? Theme.of(context).colorScheme.secondary
                                    : Theme.of(context).colorScheme.primary)
                                .withAlpha(
                                  (255 * 0.2).round(),
                                ), // Replace withOpacity
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            widget.user.role == UserRole.admin
                                ? 'Admin'
                                : 'Revendedor', // Hardcoded Portuguese
                            style: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(
                              color:
                                  widget.user.role == UserRole.admin
                                      ? Theme.of(context).colorScheme.secondary
                                      : Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!_isEnabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.error.withAlpha(
                                (255 * 0.2).round(),
                              ), // Replace withOpacity
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Inativo', // Hardcoded Portuguese
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // User information
            Text(
              'Informação Pessoal', // Hardcoded Portuguese
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _isEditing
                        ? _buildEditableInfoItem(
                          context,
                          icon: Icons.email_outlined,
                          label: 'Email',
                          controller: _emailController,
                        )
                        : _buildInfoItem(
                          context,
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: _emailController.text,
                        ),
                    const Divider(),
                    _isEditing
                        ? _buildEditableInfoItem(
                          context,
                          icon: Icons.phone_outlined,
                          label: 'Telefone', // Hardcoded Portuguese
                          controller: _phoneController,
                        )
                        : _buildInfoItem(
                          context,
                          icon: Icons.phone_outlined,
                          label: 'Telefone', // Hardcoded Portuguese
                          value:
                              _phoneController.text.isNotEmpty
                                  ? _phoneController.text
                                  : 'N/D', // Hardcoded Portuguese
                        ),
                    const Divider(),
                    _isEditing
                        ? _buildEditableInfoItem(
                          context,
                          icon: Icons.business_outlined,
                          label: 'Departamento', // Hardcoded Portuguese
                          controller: _departmentController,
                        )
                        : _buildInfoItem(
                          context,
                          icon: Icons.business_outlined,
                          label: 'Departamento', // Hardcoded Portuguese
                          value:
                              _departmentController.text.isNotEmpty
                                  ? _departmentController.text
                                  : 'N/D', // Hardcoded Portuguese
                        ),
                    const Divider(),
                    _buildInfoItem(
                      context,
                      icon: Icons.calendar_today,
                      label: 'Data Criação', // Hardcoded Portuguese
                      value: _formatDate(_additionalData['createdAt']),
                    ),
                    const Divider(),
                    _buildInfoItem(
                      context,
                      icon: Icons.login,
                      label: 'Último Login', // Hardcoded Portuguese
                      value: _formatDate(_additionalData['lastLoginAt']),
                    ),
                    const Divider(),
                    _buildInfoItem(
                      context,
                      icon: Icons.sync,
                      label: 'ID Salesforce', // Hardcoded Portuguese
                      value:
                          _additionalData['salesforceId'] ??
                          'Não vinculado', // Hardcoded Portuguese
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Business information for resellers
            if (widget.user.role == UserRole.reseller) ...[
              Text(
                'Informação Comercial', // Hardcoded Portuguese
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildInfoItem(
                        context,
                        icon: Icons.business,
                        label: 'Nome da Empresa', // Hardcoded Portuguese
                        value: _additionalData['companyName'] ?? 'N/D',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.location_on_outlined,
                        label: 'Morada da Empresa', // Hardcoded Portuguese
                        value: _additionalData['companyAddress'] ?? 'N/D',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.numbers,
                        label: 'NIF', // Hardcoded Portuguese
                        value: _additionalData['taxId'] ?? 'N/D',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.assignment_ind_outlined,
                        label: 'Registo Comercial', // Hardcoded Portuguese
                        value: _additionalData['companyRegistration'] ?? 'N/D',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Performance metrics for resellers
              Text(
                'Métricas de Desempenho', // Hardcoded Portuguese
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildInfoItem(
                        context,
                        icon: Icons.groups_outlined,
                        label: 'Total de Clientes', // Hardcoded Portuguese
                        value:
                            _additionalData['totalClients']?.toString() ?? '0',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.check_circle_outline,
                        label:
                            'Submissões Bem-sucedidas', // Hardcoded Portuguese
                        value:
                            _additionalData['successfulSubmissions']
                                ?.toString() ??
                            '0',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.pending_actions_outlined,
                        label: 'Submissões Pendentes', // Hardcoded Portuguese
                        value:
                            _additionalData['pendingSubmissions']?.toString() ??
                            '0',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.paid_outlined,
                        label: 'Receita Total', // Hardcoded Portuguese
                        value: _formatCurrency(_additionalData['totalRevenue']),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Actions
            Text(
              'Ações', // Hardcoded Portuguese
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.password,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      'Alterar Senha',
                      style: Theme.of(context).textTheme.titleMedium,
                    ), // Hardcoded Portuguese
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _resetPassword,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      _isEnabled ? Icons.block : Icons.check_circle,
                      color:
                          _isEnabled
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.secondary,
                    ),
                    title: Text(
                      _isEnabled ? 'Desativar' : 'Ativar',
                      style: Theme.of(context).textTheme.titleMedium,
                    ), // Hardcoded Portuguese
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _toggleUserStatus,
                  ),
                  // Add reseller-specific actions
                  if (widget.user.role == UserRole.reseller) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.message_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        'Ver Mensagens',
                        style: Theme.of(context).textTheme.titleMedium,
                      ), // Hardcoded Portuguese
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // TODO: Navigate to reseller messages
                        if (kDebugMode) {
                          print(
                            'View messages for reseller: ${widget.user.uid}',
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.people_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        'Ver Clientes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ), // Hardcoded Portuguese
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // TODO: Navigate to reseller clients
                        if (kDebugMode) {
                          print(
                            'View clients for reseller: ${widget.user.uid}',
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpportunitiesTab(BuildContext context) {
    final String? salesforceId = _additionalData['salesforceId'] as String?;
    final theme = Theme.of(context);

    if (salesforceId == null || salesforceId.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.nosign,
              size: 64,
              color: theme.colorScheme.primary.withAlpha(
                (255 * 0.5).round(),
              ), // Replace withOpacity
            ),
            const SizedBox(height: 16),
            Text(
              'Salesforce Não Vinculado', // Hardcoded Portuguese
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Este utilizador não tem um ID Salesforce vinculado.', // Hardcoded Portuguese
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final salesforceRepo = ref.read(salesforceRepositoryProvider);
    return FutureBuilder<List<SalesforceOpportunity>>(
      future: salesforceRepo.getResellerOpportunities(salesforceId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Erro ao Carregar Oportunidades', // Hardcoded Portuguese
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Não foi possível obter as oportunidades do Salesforce. Por favor, tente novamente mais tarde.\nErro: ${snapshot.error}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        final opportunities = snapshot.data ?? [];
        if (opportunities.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.briefcase,
                  size: 64,
                  color: theme.colorScheme.primary.withAlpha(
                    (255 * 0.5).round(),
                  ), // Replace withOpacity
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhuma Oportunidade Encontrada', // Hardcoded Portuguese
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Nenhuma oportunidade Salesforce encontrada para este revendedor.', // Hardcoded Portuguese
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: opportunities.length,
          itemBuilder: (context, index) {
            final opportunity = opportunities[index];
            return _buildOpportunityCard(context, opportunity);
          },
        );
      },
    );
  }

  Widget _buildOpportunityCard(
    BuildContext context,
    SalesforceOpportunity opportunity,
  ) {
    final theme = Theme.of(context);
    final statusColor = _getPhaseColor(opportunity.Fase__c);
    final creationDate = _formatSalesforceDate(opportunity.CreatedDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          final salesforceOpportunityId = opportunity.id;
          context.push(
            '/admin/salesforce-opportunity-detail/$salesforceOpportunityId',
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(
                        (255 * 0.1).round(),
                      ), // Replace withOpacity
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        CupertinoIcons.briefcase_fill,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opportunity.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          opportunity.accountName ?? 'Sem Nome de Conta',
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ), // Hardcoded Portuguese
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(
                        (255 * 0.1).round(),
                      ), // Replace withOpacity
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      (opportunity.Fase__c ?? 'DESCONHECIDO')
                          .replaceAll('_', ' ')
                          .toUpperCase(), // Hardcoded Portuguese
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Criado: $creationDate',
                    style: theme.textTheme.bodySmall,
                  ), // Hardcoded Portuguese
                  Text(
                    'ID: ${opportunity.id.substring(0, 6)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: theme.colorScheme.primary.withAlpha((255 * 0.7).round()),
          ), // Replace withOpacity
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(
                    (255 * 0.6).round(),
                  ), // Replace withOpacity
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required TextEditingController controller,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: theme.colorScheme.primary.withAlpha((255 * 0.7).round()),
          ), // Replace withOpacity
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/D'; // Hardcoded Portuguese
    DateTime date;
    if (timestamp is DateTime) {
      date = timestamp;
    } else if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is Map && timestamp['_seconds'] != null) {
      // Handle potential map representation (less common)
      date = DateTime.fromMillisecondsSinceEpoch(
        (timestamp['_seconds'] * 1000) +
            (timestamp['_nanoseconds'] ?? 0) ~/ 1000000,
      );
    } else {
      return 'Data Inválida'; // Hardcoded Portuguese
    }
    // Using Portuguese locale format explicitly
    return DateFormat('dd MMM, yyyy - HH:mm', 'pt_PT').format(date);
  }

  String _formatSalesforceDate(String? dateString) {
    if (dateString == null) return 'N/D'; // Hardcoded Portuguese
    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } catch (e) {
      return dateString;
    }
  }

  Color _getPhaseColor(String? phase) {
    // ... (Color logic remains the same)
    switch (phase?.toLowerCase()) {
      case 'closed_won':
        return Colors.green;
      case 'proposal_sent':
      case 'negotiation':
        return Colors.blue;
      case 'qualification':
      case 'needs_analysis':
        return Colors.orange;
      case 'closed_lost':
        return Colors.red;
      case 'pending_approval':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) {
      return '€0.00';
    }
    double numericAmount;
    if (amount is int) {
      numericAmount = amount.toDouble();
    } else if (amount is double) {
      numericAmount = amount;
    } else if (amount is String) {
      numericAmount = double.tryParse(amount) ?? 0.0;
    } else {
      return '€0.00';
    }
    // Use Portuguese Euro format
    final formatter = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    return formatter.format(numericAmount);
  }
}
