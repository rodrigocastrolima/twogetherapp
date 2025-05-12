import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../presentation/layout/main_layout.dart';
import '../../../app/router/app_router.dart';
import '../../../core/theme/ui_styles.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isForgotPasswordMode = false;
  bool _isSendingRecovery = false;
  bool _recoveryEmailSent = false;

  void _handleLogin() async {
    // Get email and password first for validation
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Simple validation
    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, insira email e senha')),
        );
      }
      return; // Stop if validation fails
    }

    try {
      // Navigate to the loading route BEFORE attempting login
      // Ensure context is still mounted before navigating
      if (mounted) {
        GoRouter.of(context).go('/auth-loading');
      }

      // Attempt login - No need for try/finally for loading here
      await AppRouter.authNotifier.signInWithEmailAndPassword(email, password);

      // On successful login, GoRouter's redirect logic will handle navigation
      // away from /auth-loading automatically.
    } catch (e) {
      // If login fails, navigate BACK to login page to show the error
      if (mounted) {
        // Check if we are currently on the loading page before going back
        final currentRoute = GoRouterState.of(context).matchedLocation;
        if (currentRoute == '/auth-loading') {
          GoRouter.of(context).go('/login');
        }

        // Delay showing the SnackBar slightly to ensure the login page is visible
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Falha no login: ${e.toString()}')),
            );
          }
        });
      }
    }
  }

  void _sendRecoveryEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, insira seu endereço de email.')),
      );
      return;
    }

    setState(() {
      _isSendingRecovery = true;
      _recoveryEmailSent =
          false; // Ensure success message isn't shown during send
    });

    try {
      final authNotifier = AppRouter.authNotifier;
      final success = await authNotifier.requestPasswordReset(email);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Email de redefinição de senha enviado para $email. Verifique sua caixa de entrada.',
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Set state to show success message
          setState(() {
            _recoveryEmailSent = true;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Falha ao enviar email de redefinição. Verifique o endereço de email ou tente novamente mais tarde.',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ocorreu um erro inesperado: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingRecovery = false;
        });
      }
    }
  }

  void _switchToLoginMode() {
    if (mounted) {
      setState(() {
        _isForgotPasswordMode = false;
        _recoveryEmailSent = false;
      });
    }
  }

  void _switchToForgotPasswordMode() {
    if (mounted) {
      setState(() {
        _isForgotPasswordMode = true;
        _recoveryEmailSent = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final double padding = size.width < 400 ? 12.0 : 16.0;

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/banner.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Overlay to darken the image and improve text readability
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.4),
          ),
          // Main Login Content within SafeArea
          SafeArea(
            child: Center(
              child: NoScrollbarBehavior.noScrollbars(
                context,
                SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: padding,
                    vertical: padding,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isSmallScreen ? size.width * 0.8 : 400,
                    ),
                    // Form content is now just the Column
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Form Container
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 18 : 24,
                              vertical: isSmallScreen ? 24 : 32,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Logo inside the form
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        isSmallScreen ? size.width * 0.38 : 180,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 2.0,
                                    child: Image.asset(
                                      'assets/images/twogether_logo_dark_br.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 24 : 32),
                                // --- Conditional Content ---
                                if (!_isForgotPasswordMode)
                                  _buildLoginForm(context)
                                else if (_isForgotPasswordMode &&
                                    !_recoveryEmailSent)
                                  _buildForgotPasswordForm(context)
                                else
                                  _buildSuccessMessage(context),
                              ],
                            ),
                          ),
                        ),
                        // --- Links Below Form ---
                        Visibility(
                          visible: !_isForgotPasswordMode,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: TextButton(
                              onPressed: _switchToForgotPasswordMode,
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                textStyle: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              child: Text('Esqueceu sua senha?'),
                            ),
                          ),
                        ),
                        Visibility(
                          visible: _isForgotPasswordMode,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: TextButton(
                              onPressed: _switchToLoginMode,
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                textStyle: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              child: Text('Voltar ao Login'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Powered by Upgraide Trademark (Outside SafeArea, inside main Stack)
          Positioned(
            bottom: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.only(
                right: 20.0,
                bottom: 0.0,
              ), // Keep same padding
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'powered by',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(width: 1),
                  Image.asset(
                    'assets/images/upgraide.png',
                    height: 100, // Keep the desired size
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets for Form States ---

  Widget _buildLoginForm(BuildContext context) {
    // Get the input decoration theme defaults from the main context
    final themeDefaults = Theme.of(context).inputDecorationTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Email TextField
        TextField(
          controller: _emailController,
          // Create InputDecoration based on theme, then override
          decoration: InputDecoration(
            // Apply theme defaults first (like fill color, border)
            filled: themeDefaults.filled,
            fillColor: themeDefaults.fillColor,
            border: themeDefaults.border,
            enabledBorder: themeDefaults.enabledBorder,
            focusedBorder: themeDefaults.focusedBorder,
            contentPadding: themeDefaults.contentPadding,
            isDense: themeDefaults.isDense,
            // Now apply specific overrides
            hintText: 'Email',
            hintStyle: TextStyle(
              color: Colors.black45,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.email_outlined,
              color: Colors.black45,
              size: 17,
            ),
          ),
          style: TextStyle(color: Colors.black87, fontSize: 13),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 10),
        // Password TextField
        TextField(
          controller: _passwordController,
          // Create InputDecoration based on theme, then override
          decoration: InputDecoration(
            // Apply theme defaults first
            filled: themeDefaults.filled,
            fillColor: themeDefaults.fillColor,
            border: themeDefaults.border,
            enabledBorder: themeDefaults.enabledBorder,
            focusedBorder: themeDefaults.focusedBorder,
            contentPadding: themeDefaults.contentPadding,
            isDense: themeDefaults.isDense,
            // Now apply specific overrides
            hintText: 'Senha',
            hintStyle: TextStyle(
              color: Colors.black45,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.lock_outline,
              color: Colors.black45,
              size: 17,
            ),
          ),
          style: TextStyle(color: Colors.black87, fontSize: 13),
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleLogin(),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 38,
          child: FilledButton(
            onPressed: _handleLogin,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.primaryForeground,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Entrar',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordForm(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withOpacity(0.4),
                  width: 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.primary, width: 1),
              ),
            ),
          ),
          child: TextField(
            controller: _emailController,
            decoration: InputDecoration(
              hintText: 'Email',
              hintStyle: TextStyle(
                color: Colors.black45,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                Icons.email_outlined,
                color: Colors.black45,
                size: 17,
              ),
              isDense: true,
            ),
            style: TextStyle(color: Colors.black87, fontSize: 13),
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 38,
          child: FilledButton(
            onPressed: _isSendingRecovery ? null : _sendRecoveryEmail,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.primaryForeground,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child:
                _isSendingRecovery
                    ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryForeground,
                      ),
                    )
                    : Text(
                      'Recuperar Senha',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
          const SizedBox(height: 16),
          Text(
            'Email de recuperação enviado com sucesso!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
