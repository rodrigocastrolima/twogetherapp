import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/theme/ui_styles.dart';
import '../../../app/router/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../features/chat/data/repositories/chat_repository.dart';
import '../../widgets/success_dialog.dart';

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
  bool _obscureCurrentPassword = true;

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
    bool? reauthSuccess = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Reautenticação Necessária'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Por favor, insira a sua palavra-passe atual para continuar.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _currentPasswordController,
                    obscureText: _obscureCurrentPassword,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Palavra-passe Atual',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrentPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            _obscureCurrentPassword = !_obscureCurrentPassword;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_currentPasswordController.text.isEmpty) {
                      return;
                    }
                    try {
                      final credential = EmailAuthProvider.credential(
                        email: user.email!,
                        password: _currentPasswordController.text,
                      );
                      await user.reauthenticateWithCredential(credential);
                      if (context.mounted) Navigator.pop(context, true);
                    } on FirebaseAuthException catch (e) {
                      if (context.mounted) Navigator.pop(context, false);
                      if (mounted) {
                        setState(() {
                          _errorMessage = 'Falha na reautenticação: ${e.code}';
                          _isLoading = false;
                        });
                      }
                    } catch (e) {
                      if (context.mounted) Navigator.pop(context, false);
                      if (mounted) {
                        setState(() {
                          _errorMessage =
                              'Ocorreu um erro durante a reautenticação.';
                          _isLoading = false;
                        });
                      }
                    }
                  },
                  child: Text('Confirmar'),
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
        if (freshUser == null)
          throw Exception('User became null after re-auth');

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
      } catch (e) {}
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final double horizontalPadding = isSmallScreen ? 24.0 : 32.0;
    final double verticalPadding = isSmallScreen ? 32.0 : 48.0;

    Widget pageContent = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isSmallScreen ? size.width * 0.9 : 400,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Alterar Palavra-passe',
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Crie uma nova palavra-passe segura para a sua conta.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 32 : 40),

              _buildPasswordField(
                context: context,
                controller: _newPasswordController,
                labelText: 'Nova Palavra-passe',
                obscureText: _obscureNewPassword,
                onToggleObscure: () {
                  setState(() {
                    _obscureNewPassword = !_obscureNewPassword;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                context: context,
                controller: _confirmPasswordController,
                labelText: 'Confirmar Nova Palavra-passe',
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
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 32),

              FilledButton(
                onPressed: _isLoading ? null : _handleChangePassword,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child:
                    _isLoading
                        ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.onPrimary,
                            ),
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
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back),
          color: colorScheme.onSurface,
          onPressed: () => context.pop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
      ),
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: pageContent,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required BuildContext context,
    required TextEditingController controller,
    required String labelText,
    required bool obscureText,
    required VoidCallback onToggleObscure,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final InputDecoration effectiveDecoration = InputDecoration(
      hintText: labelText,
      hintStyle: textTheme.bodyLarge?.copyWith(
        color: Color.alphaBlend(
          colorScheme.onSurfaceVariant.withAlpha((255 * 0.6).round()),
          Colors.transparent,
        ),
      ),
      filled: true,
      fillColor: Color.alphaBlend(
        colorScheme.surfaceContainerHighest.withAlpha((255 * 0.3).round()),
        Colors.transparent,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      suffixIcon: IconButton(
        icon: Icon(obscureText ? CupertinoIcons.eye_slash : CupertinoIcons.eye),
        color: Color.alphaBlend(
          colorScheme.onSurfaceVariant.withAlpha((255 * 0.7).round()),
          Colors.transparent,
        ),
        iconSize: 20,
        tooltip: obscureText ? 'Show password' : 'Hide password',
        onPressed: onToggleObscure,
      ),
    );

    return TextField(
      controller: controller,
      decoration: effectiveDecoration,
      style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
      obscureText: obscureText,
      keyboardType: TextInputType.visiblePassword,
      autocorrect: false,
      enableSuggestions: false,
      obscuringCharacter: '●',
    );
  }
}
