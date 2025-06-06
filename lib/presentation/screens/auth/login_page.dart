import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/theme.dart';

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
  String? _errorMessage; // For displaying errors directly on the form

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_clearError);
    _passwordController.addListener(_clearError);
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  void _handleLogin() async {
    _clearError(); // Clear previous errors
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Por favor, insira email e senha';
        });
      }
      return;
    }

    try {
      if (mounted) {
        GoRouter.of(context).go('/auth-loading');
      }
      await AppRouter.authNotifier.signInWithEmailAndPassword(email, password);
    } catch (e) {
      if (mounted) {
        GoRouter.of(context).pushReplacement('/login');
        // Delay slightly for navigation to complete before setting state
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            setState(() {
              _errorMessage =
                  'Falha no login: Credenciais inválidas ou problema de conexão.';
              if (kDebugMode) {
                print('Login error: ${e.toString()}');
              }
            });
          }
        });
      }
    }
  }

  void _sendPasswordRecoveryEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, insira seu e-mail.';
      });
      return;
    }

    setState(() {
      _isSendingRecovery = true;
      _recoveryEmailSent = false;
    });

    try {
      final authNotifier = AppRouter.authNotifier;
      await authNotifier.requestPasswordReset(email);
      if (mounted) {
        // SnackBar removed, _recoveryEmailSent will trigger the success message in the form
        setState(() {
          _recoveryEmailSent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ocorreu um erro inesperado. Tente novamente.';
          if (kDebugMode) {
            print('Password reset error: ${e.toString()}');
          }
        });
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
        _errorMessage = null; // Clear error on mode switch
      });
    }
  }

  void _switchToForgotPasswordMode() {
    if (mounted) {
      setState(() {
        _isForgotPasswordMode = true;
        _recoveryEmailSent = false;
        _errorMessage = null; // Clear error on mode switch
      });
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_clearError);
    _passwordController.removeListener(_clearError);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final double horizontalPadding =
        size.width < 400 ? 12.0 : 16.0; // Renamed for clarity
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background Image
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Overlay
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withAlpha((255 * 0.25).round()),
          ),
          SafeArea(
            child: Center(
              child: NoScrollbarBehavior.noScrollbars(
                context,
                SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                  ), // Removed vertical padding
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isSmallScreen ? size.width * 0.85 : 420,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 10.0,
                                sigmaY: 10.0,
                              ),
                              child: Container(
                                width: double.infinity,
                                decoration: AppStyles.glassCard(context),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 20 : 28,
                                    vertical: isSmallScreen ? 28 : 36,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              isSmallScreen
                                                  ? size.width * 0.45
                                                  : 230,
                                          maxHeight: 110,
                                        ),
                                        child: SvgPicture.asset(
                                          'assets/images/twogether-retail_logo-04.svg',
                                          fit: BoxFit.contain,
                                          colorFilter: ColorFilter.mode(
                                            isDarkMode
                                                ? Colors.white.withAlpha((255 * 0.9).round())
                                                : Colors.black.withAlpha((255 * 0.8).round()),
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 24 : 30),
                                      if (_errorMessage != null &&
                                          _errorMessage!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 16.0,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withAlpha((255 * 0.10).round()), // subtle glassy red
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.error_outline_rounded,
                                                  color: Colors.red.shade700,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 10),
                                                Flexible(
                                                  child: Text(
                                                    _errorMessage!,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: Colors.red.shade700,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      if (!_isForgotPasswordMode)
                                        _buildLoginForm(context, isDarkMode)
                                      else if (_isForgotPasswordMode &&
                                          !_recoveryEmailSent)
                                        _buildForgotPasswordForm(
                                          context,
                                          isDarkMode,
                                        )
                                      else
                                        _buildSuccessMessage(context),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Visibility(
                          visible: !_isForgotPasswordMode,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 30.0),
                            child: TextButton(
                              onPressed: _switchToForgotPasswordMode,
                              style: ButtonStyle(
                                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                  if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) {
                                    return isDarkMode 
                                        ? Colors.white.withAlpha((255 * 0.9).round())
                                        : AppTheme.primary.withAlpha((255 * 0.8).round());
                                  }
                                  return isDarkMode 
                                      ? Colors.white.withAlpha((255 * 0.85).round())
                                      : AppTheme.primary;
                                }),
                                overlayColor: WidgetStateProperty.all(Colors.transparent),
                                textStyle: WidgetStateProperty.all(
                                  TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              child: Text('Esqueceu sua senha?'),
                            ),
                          ),
                        ),
                        Visibility(
                          visible: _isForgotPasswordMode,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 30.0),
                            child: TextButton(
                              onPressed: _switchToLoginMode,
                              style: ButtonStyle(
                                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                  if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) {
                                    return isDarkMode 
                                        ? Colors.white.withAlpha((255 * 0.9).round())
                                        : AppTheme.primary.withAlpha((255 * 0.8).round());
                                  }
                                  return isDarkMode 
                                      ? Colors.white.withAlpha((255 * 0.85).round())
                                      : AppTheme.primary;
                                }),
                                overlayColor: WidgetStateProperty.all(Colors.transparent),
                                textStyle: WidgetStateProperty.all(
                                  TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
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
          Positioned(
            bottom: 0,
            right: 0,
            left: 0,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18.0, top: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'powered by',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha((255 * 0.87).round()),
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/images/upgraide.png',
                    height: 80, // Even larger for maximum visibility
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context, bool isDarkMode) {
    final Color fieldFillColor =
        isDarkMode
            ? Colors.white.withAlpha((255 * 0.08).round())
            : Colors.white.withAlpha((255 * 0.15).round());
    final Color hintAndIconColor =
        isDarkMode
            ? Colors.white.withAlpha((255 * 0.65).round())
            : Colors.black.withAlpha((255 * 0.55).round());
    final Color inputTextColor =
        isDarkMode
            ? Colors.white.withAlpha((255 * 0.9).round())
            : Colors.black.withAlpha((255 * 0.85).round());
    
    final BorderSide inputEnabledBorderSide = BorderSide(
        color: isDarkMode ? Colors.white.withAlpha((255 * 0.2).round()) : Colors.white.withAlpha((255 * 0.3).round()),
        width: 1.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            filled: true,
            fillColor: fieldFillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: inputEnabledBorderSide,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: inputEnabledBorderSide,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isDarkMode ? AppTheme.darkPrimary : AppTheme.primary,
                width: 1.0,
              ), 
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            hintText: 'Email',
            hintStyle: TextStyle(
              color: hintAndIconColor.withAlpha((255 * 0.7).round()),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14.0, right: 10.0),
              child: Icon(
                Icons.email_outlined,
                color: hintAndIconColor.withAlpha((255 * 0.7).round()),
                size: 21,
              ),
            ),
            isDense: true,
          ),
          style: TextStyle(
            color: inputTextColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            filled: true,
            fillColor: fieldFillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: inputEnabledBorderSide,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: inputEnabledBorderSide,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isDarkMode ? AppTheme.darkPrimary : AppTheme.primary,
                width: 1.0,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            hintText: 'Senha',
            hintStyle: TextStyle(
              color: hintAndIconColor.withAlpha((255 * 0.7).round()),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14.0, right: 10.0),
              child: Icon(
                Icons.lock_outline,
                color: hintAndIconColor.withAlpha((255 * 0.7).round()),
                size: 21,
              ),
            ),
            isDense: true,
          ),
          style: TextStyle(
            color: inputTextColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleLogin(),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: _handleLogin,
            style: FilledButton.styleFrom(
              backgroundColor: isDarkMode ? AppTheme.darkPrimary : AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              'Entrar',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordForm(BuildContext context, bool isDarkMode) {
    final Color fieldFillColor =
        isDarkMode
            ? Colors.white.withAlpha((255 * 0.08).round())
            : Colors.white.withAlpha((255 * 0.15).round());
    final Color hintAndIconColor =
        isDarkMode
            ? Colors.white.withAlpha((255 * 0.65).round())
            : Colors.black.withAlpha((255 * 0.55).round());
    final Color inputTextColor =
        isDarkMode
            ? Colors.white.withAlpha((255 * 0.9).round())
            : Colors.black.withAlpha((255 * 0.85).round());

    final BorderSide inputEnabledBorderSide = BorderSide(
      color: isDarkMode ? Colors.white.withAlpha((255 * 0.2).round()) : Colors.white.withAlpha((255 * 0.3).round()),
      width: 1.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            filled: true,
            fillColor: fieldFillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: inputEnabledBorderSide,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: inputEnabledBorderSide,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isDarkMode ? AppTheme.darkPrimary : AppTheme.primary,
                width: 1.0,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            hintText: 'Email',
            hintStyle: TextStyle(
              color: hintAndIconColor.withAlpha((255 * 0.7).round()),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14.0, right: 10.0),
              child: Icon(
                Icons.email_outlined,
                color: hintAndIconColor.withAlpha((255 * 0.7).round()),
                size: 21,
              ),
            ),
            isDense: true,
          ),
          style: TextStyle(
            color: inputTextColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: _isSendingRecovery ? null : _sendPasswordRecoveryEmail,
            style: FilledButton.styleFrom(
              backgroundColor: isDarkMode ? AppTheme.darkPrimary : AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: EdgeInsets.symmetric(vertical: 12),
              disabledBackgroundColor: isDarkMode 
                ? AppTheme.darkPrimary.withAlpha((255 * 0.6).round())
                : AppTheme.primary.withAlpha((255 * 0.6).round()),
            ),
            child:
                _isSendingRecovery
                    ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        color: Colors.white.withAlpha((255 * 0.92).round()),
                      ),
                    )
                    : Text(
                      'Recuperar Senha',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.green.withAlpha((255 * 0.10).round()), // subtle glassy green
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade700,
              size: 22,
            ),
            const SizedBox(height: 10),
            Text(
              'Email de recuperação enviado com sucesso!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
