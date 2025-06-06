import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../features/chat/data/repositories/chat_repository.dart';
import '../../widgets/success_dialog.dart';
import '../../widgets/logo.dart';
import '../../widgets/standard_app_bar.dart';


class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _promptForReauthenticationAndRetry() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Utilizador não encontrado para reautenticação.';
          _isLoading = false;
        });
      }
      return;
    }

    _currentPasswordController.clear();
    bool obscureCurrentPasswordDialog = true;

    bool? reauthSuccess = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.all(0),
              title: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Text(
                      'Reautenticação Necessária',
                      style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(CupertinoIcons.xmark, size: 22),
                      onPressed: () => Navigator.pop(dialogContext, false),
                      tooltip: 'Fechar',
                      splashRadius: 20,
                    ),
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Por favor, insira a sua palavra-passe atual para continuar.',
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 56,
                    child: TextFormField(
                      controller: _currentPasswordController,
                      obscureText: obscureCurrentPasswordDialog,
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Palavra-passe Atual',
                        labelStyle: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        hintText: '',
                        hintStyle: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withAlpha((255 * 0.7).round()),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.outline.withAlpha((255 * 0.2).round())),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.primary, width: 2),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.outline.withAlpha((255 * 0.08).round())),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrentPasswordDialog ? Icons.visibility_off : Icons.visibility,
                            color: colorScheme.onSurfaceVariant.withAlpha((255 * 0.7).round()),
                            size: 20,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureCurrentPasswordDialog = !obscureCurrentPasswordDialog;
                            });
                          },
                        ),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actionsPadding: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
              actions: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_currentPasswordController.text.isEmpty) return;
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null || user.email == null) throw Exception("User not found for re-auth");
                        final credential = EmailAuthProvider.credential(
                          email: user.email!,
                          password: _currentPasswordController.text,
                        );
                        await user.reauthenticateWithCredential(credential);
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      } on FirebaseAuthException catch (e) {
                        if (dialogContext.mounted) Navigator.pop(dialogContext, false);
                        if (mounted) setState(() { _errorMessage = 'Falha na reautenticação: ${e.message ?? e.code}'; _isLoading = false; });
                      } catch (e) {
                        if (dialogContext.mounted) Navigator.pop(dialogContext, false);
                        if (mounted) setState(() { _errorMessage = 'Ocorreu um erro durante a reautenticação.'; _isLoading = false; });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Confirmar',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (reauthSuccess == true) {
      try {
        final freshUser = FirebaseAuth.instance.currentUser;
        if (freshUser == null) {
          throw Exception('User became null after re-auth');
        }

        await freshUser.updatePassword(_newPasswordController.text);

        await _handleSuccessfulPasswordUpdate();
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Falha ao atualizar palavra-passe após reautenticação: ${e.code}';
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Erro ao atualizar palavra-passe após reautenticação.';
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _errorMessage ??= 'Reautenticação cancelada ou falhou.';
        });
      }
    }
  }

  Future<void> _handleSuccessfulPasswordUpdate() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
        if (userDoc.exists) {
          final roleData = userDoc.data()?['role'];
          final String roleString = roleData is String ? roleData : 'unknown';
          final normalizedRole = roleString.trim().toLowerCase();
          if (normalizedRole == 'reseller') {
            final chatRepository = ChatRepository();
            await chatRepository.ensureResellerHasConversation(user.uid);
          }
        }
      } catch (e) {
        // Error handling for chat repository setup - silent fail
      }
    }

    try {
      await AppRouter.authNotifier.completeFirstLogin();

      if (!mounted) return;

      await showSuccessDialog(
        context: context,
        message: 'Palavra-passe atualizada com sucesso!',
        onDismissed: () {
          if (mounted) {
            context.go('/');
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao finalizar o processo de primeiro login.';
          _isLoading = false;
        });
      }
    }
  }

  void _handleChangePassword() async {
    if (_newPasswordController.text.isEmpty) {
      setState(
        () => _errorMessage = 'A nova palavra-passe não pode estar vazia.',
      );
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'As palavras-passe não coincidem.');
      return;
    }
    if (_newPasswordController.text.length < 8) {
      setState(
        () =>
            _errorMessage = 'A palavra-passe deve ter pelo menos 8 caracteres.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AppRouter.authNotifier.updatePassword(_newPasswordController.text);

      await _handleSuccessfulPasswordUpdate();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        await _promptForReauthenticationAndRetry();
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Erro de autenticação: ${e.code}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao atualizar palavra-passe.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  // Helper method for responsive font sizing
  double _getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final width = MediaQuery.of(context).size.width;
    return width < 600 ? baseFontSize - 2 : baseFontSize;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    Widget pageContent = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Responsive spacing after SafeArea - no spacing for mobile, 24px for desktop
            SizedBox(height: MediaQuery.of(context).size.width < 600 ? 0 : 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Alterar Palavra-passe',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                  fontSize: _getResponsiveFontSize(context, 24),
                ),
                textAlign: TextAlign.left,
              ),
            ),
            // Responsive spacing after title - 16px for mobile, 24px for desktop
            SizedBox(height: MediaQuery.of(context).size.width < 600 ? 16 : 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crie uma nova palavra-passe segura para a sua conta.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildPasswordField(
                      controller: _newPasswordController,
                      label: 'Nova Palavra-passe',
                      obscureText: _obscureNewPassword,
                      onToggleObscure: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirmar Nova Palavra-passe',
                      obscureText: _obscureConfirmPassword,
                      onToggleObscure: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          _errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleChangePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20, 
                                width: 20, 
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, 
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : Text(
                                'Guardar Palavra-passe',
                                style: textTheme.labelLarge?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: const StandardAppBar(
        showBackButton: true,
        showLogo: true,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: pageContent,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleObscure,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return SizedBox(
      height: 56,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          hintText: (controller.text.isEmpty) ? '' : '',
          hintStyle: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant.withAlpha((255 * 0.7).round()),
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outline.withAlpha((255 * 0.2).round())),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outline.withAlpha((255 * 0.08).round())),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off : Icons.visibility,
              color: colorScheme.onSurfaceVariant.withAlpha((255 * 0.7).round()),
              size: 20,
            ),
            onPressed: onToggleObscure,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
    );
  }
}
