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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    print('ChangePasswordPage: initState called.');
  }

  Future<void> _promptForReauthenticationAndRetry() async {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      if (mounted) {
        setState(() {
          _errorMessage = l10n.reauthErrorUserNotFound;
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
              title: Text(l10n.reauthRequiredTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.reauthRequiredMessage),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _currentPasswordController,
                    obscureText: _obscureCurrentPassword,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.reauthCurrentPasswordLabel,
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
                  child: Text(l10n.cancel),
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
                          _errorMessage = l10n.reauthFailedError(e.code);
                          _isLoading = false;
                        });
                      }
                    } catch (e) {
                      if (context.mounted) Navigator.pop(context, false);
                      if (mounted) {
                        setState(() {
                          _errorMessage = l10n.reauthFailedGenericError;
                          _isLoading = false;
                        });
                      }
                    }
                  },
                  child: Text(l10n.confirm),
                ),
              ],
            );
          },
        );
      },
    );

    if (reauthSuccess == true) {
      print(
        'ChangePasswordPage: Re-authentication successful. Retrying password update...',
      );
      try {
        final freshUser = FirebaseAuth.instance.currentUser;
        if (freshUser == null)
          throw Exception('User became null after re-auth');

        await freshUser.updatePassword(_newPasswordController.text);
        print(
          'ChangePasswordPage: Password update successful after re-authentication.',
        );

        await _handleSuccessfulPasswordUpdate();
      } on FirebaseAuthException catch (e) {
        print(
          'ChangePasswordPage: Error during password update AFTER re-auth: ${e.code}',
        );
        if (mounted) {
          setState(() {
            _errorMessage = l10n.passwordUpdateFailedAfterReauthError(e.code);
            _isLoading = false;
          });
        }
      } catch (e) {
        print(
          'ChangePasswordPage: Generic error during password update AFTER re-auth: $e',
        );
        if (mounted) {
          setState(() {
            _errorMessage = l10n.passwordUpdateFailedAfterReauthGenericError;
            _isLoading = false;
          });
        }
      }
    } else {
      print('ChangePasswordPage: Re-authentication cancelled or failed.');
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          if (_errorMessage == null) {
            _errorMessage = l10n.reauthCancelledError;
          }
        });
      }
    }
  }

  Future<void> _handleSuccessfulPasswordUpdate() async {
    final l10n = AppLocalizations.of(context)!;
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
        print(
          'ChangePasswordPage: Error ensuring conversation after password change: $e',
        );
      }
    }

    print(
      'ChangePasswordPage: Password update successful. Calling completeFirstLogin...',
    );
    try {
      await AppRouter.authNotifier.completeFirstLogin();
      print('ChangePasswordPage: completeFirstLogin finished.');

      if (!mounted) return;

      await showSuccessDialog(
        context: context,
        message: l10n.passwordUpdateSuccessMessage,
        onDismissed: () {
          if (mounted) {
            context.go('/');
          }
        },
      );
    } catch (e) {
      print('ChangePasswordPage: Error during completeFirstLogin: $e');
      if (mounted) {
        setState(() {
          _errorMessage = l10n.passwordUpdateCompleteFirstLoginError;
          _isLoading = false;
        });
      }
    }
  }

  void _handleChangePassword() async {
    final l10n = AppLocalizations.of(context)!;
    print('ChangePasswordPage: _handleChangePassword called.');

    if (_newPasswordController.text.isEmpty) {
      setState(() => _errorMessage = l10n.validationPasswordEmpty);
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = l10n.validationPasswordMismatch);
      return;
    }
    if (_newPasswordController.text.length < 8) {
      setState(() => _errorMessage = l10n.validationPasswordTooShort);
      return;
    }

    setState(() {
      print('ChangePasswordPage: Starting password update process...');
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print(
        'ChangePasswordPage: Attempting direct password update via AuthNotifier...',
      );
      await AppRouter.authNotifier.updatePassword(_newPasswordController.text);

      print(
        'ChangePasswordPage: Direct password update via AuthNotifier successful.',
      );
      await _handleSuccessfulPasswordUpdate();
    } on FirebaseAuthException catch (e) {
      print(
        'ChangePasswordPage: FirebaseAuthException during password update: ${e.code}',
      );
      if (e.code == 'requires-recent-login') {
        print('ChangePasswordPage: Requires recent login. Prompting user...');
        await _promptForReauthenticationAndRetry();
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = l10n.firebaseAuthError(e.code);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('ChangePasswordPage: Generic error during password update: $e');
      if (mounted) {
        setState(() {
          _errorMessage = l10n.passwordUpdateFailedGenericError;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    print('ChangePasswordPage: Dispose called.');
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                l10n.changePasswordTitle,
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  l10n.changePasswordSubtitle,
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
                labelText: l10n.changePasswordNewLabel,
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
                labelText: l10n.changePasswordConfirmLabel,
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
                          l10n.changePasswordButton,
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
        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
      ),
      filled: true,
      fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
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
        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
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
