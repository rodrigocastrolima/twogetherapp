import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/theme/ui_styles.dart';
import '../../../../app/router/app_router.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  String? _errorMessage;
  bool _isChangingPassword = false;
  String? _passwordChangeMessage;
  bool _passwordChangeSuccess = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Usuário não autenticado';
        });
        return;
      }

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      if (!userDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Dados do usuário não encontrados';
        });
        return;
      }

      setState(() {
        _userData = userDoc.data();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao carregar dados: ${e.toString()}';
      });
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isChangingPassword = true;
      _passwordChangeMessage = null;
      _passwordChangeSuccess = false;
    });

    try {
      // Send password reset email to current user's email
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);

      setState(() {
        _isChangingPassword = false;
        _passwordChangeSuccess = true;
        _passwordChangeMessage =
            'Email de redefinição de senha enviado para ${user.email}';
      });
    } catch (e) {
      setState(() {
        _isChangingPassword = false;
        _passwordChangeSuccess = false;
        _passwordChangeMessage = 'Erro ao enviar email: ${e.toString()}';
      });
    }
  }

  void _showPasswordChangeDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Alterar Senha'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Um email de redefinição de senha será enviado para seu endereço de email.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  user.email ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _changePassword();
                },
                child: const Text('Enviar Email'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            }
          },
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: AppTheme.destructive),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              : _buildProfileContent(theme),
    );
  }

  Widget _buildProfileContent(ThemeData theme) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header with centered avatar
          Center(
            child: Column(
              children: [
                // Centered avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                  child: Text(
                    _getInitials(),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Name and email centered below avatar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacing16,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _userData?['displayName'] ??
                            currentUser?.email?.split('@').first ??
                            'Usuário',
                        style: AppTextStyles.h3,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser?.email ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onBackground.withOpacity(
                            0.7,
                          ),
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
          ),

          const SizedBox(height: 20),

          // Password change status message
          if (_passwordChangeMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacing16,
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      _passwordChangeSuccess
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _passwordChangeSuccess
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      color: _passwordChangeSuccess ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _passwordChangeMessage!,
                        style: TextStyle(
                          color:
                              _passwordChangeSuccess
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Add spacing if message is shown
          if (_passwordChangeMessage != null) const SizedBox(height: 12),

          // User information
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacing16,
            ),
            child: _buildProfileSection('Informações Pessoais', [
              _buildProfileItem(
                'Nome completo',
                _userData?['displayName'] ?? 'Não informado',
                icon: Icons.person_outline,
                theme: theme,
              ),
              _buildProfileItem(
                'E-mail',
                currentUser?.email ?? 'Não informado',
                icon: Icons.email_outlined,
                theme: theme,
              ),
              _buildProfileItem(
                'Telefone',
                _userData?['phoneNumber'] ?? 'Não informado',
                icon: Icons.phone_outlined,
                theme: theme,
              ),
            ], theme),
          ),

          const SizedBox(height: 12),

          // Account information
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacing16,
            ),
            child: _buildProfileSection('Informações da Conta', [
              _buildProfileItem(
                'Tipo de conta',
                _formatRole(_userData?['role']),
                icon: Icons.badge_outlined,
                theme: theme,
              ),
              _buildProfileItem(
                'Membro desde',
                _formatDate(_userData?['createdAt']),
                icon: Icons.calendar_today_outlined,
                theme: theme,
              ),
            ], theme),
          ),

          const SizedBox(height: 12),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacing16,
            ),
            child: _buildProfileSection('Ações', [
              _buildActionItem(
                'Comissões',
                icon: Icons.monetization_on_outlined,
                onTap: () => context.push('/dashboard'),
                theme: theme,
              ),
              _buildActionItem(
                'Alterar Senha',
                icon: Icons.lock_outline,
                onTap: () => context.push('/change-password'),
                theme: theme,
              ),
            ], theme),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    String title, {
    required IconData icon,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final onSurfaceColor = theme.colorScheme.onSurface;
    // Use a slightly less prominent background for actions
    final bgColor =
        isDark
            ? AppTheme.darkSecondary.withAlpha(100)
            : AppTheme.secondary.withAlpha(150);
    final borderColor =
        isDark
            ? AppTheme.darkBorder.withAlpha(100)
            : AppTheme.border.withAlpha(100);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: AppStyles.standardBlur, // Keep blur if desired
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ), // Adjusted padding
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                ), // Use theme border color
              ),
              child: Row(
                children: [
                  Icon(icon, color: primaryColor, size: 22),
                  const SizedBox(width: 16),
                  Expanded(
                    // Removed Column, just show title
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: onSurfaceColor, // Use standard text color
                      ),
                    ),
                  ),
                  // Keep chevron for visual cue
                  Icon(
                    Icons.chevron_right,
                    color: onSurfaceColor.withAlpha(128),
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

  String _getInitials() {
    final name = _userData?['displayName'] as String? ?? '';
    if (name.isEmpty) {
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      return email.isNotEmpty ? email[0].toUpperCase() : '?';
    }

    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatRole(String? role) {
    if (role == null) return 'Usuário';
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrador';
      case 'reseller':
        return 'Revendedor';
      default:
        return 'Usuário';
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Não disponível';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'Não disponível';
  }

  Widget _buildProfileSection(
    String title,
    List<Widget> items,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...items,
      ],
    );
  }

  Widget _buildProfileItem(
    String label,
    String value, {
    required IconData icon,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: theme.colorScheme.primary.withOpacity(0.7),
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onBackground.withOpacity(
                            0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onBackground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
