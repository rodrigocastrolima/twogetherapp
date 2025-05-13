import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  void _sendRecoveryEmail() async {
    _clearError(); // Clear previous errors
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Por favor, insira seu endereço de email.';
        });
      }
      return;
    }

    setState(() {
      _isSendingRecovery = true;
      _recoveryEmailSent = false;
    });

    try {
      final authNotifier = AppRouter.authNotifier;
      final success = await authNotifier.requestPasswordReset(email);
      if (mounted) {
        if (success) {
          // SnackBar removed, _recoveryEmailSent will trigger the success message in the form
          setState(() {
            _recoveryEmailSent = true;
          });
        } else {
          setState(() {
            _errorMessage =
                'Falha ao enviar email de redefinição. Verifique o endereço ou tente mais tarde.';
          });
        }
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
                image: AssetImage('assets/images/banner.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Overlay
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.25),
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
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    isDarkMode
                                        ? Colors.black.withOpacity(0.10)
                                        : Colors.white.withOpacity(0.15),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 10.0,
                                sigmaY: 10.0,
                              ),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color:
                                      isDarkMode
                                          ? Colors.grey.shade800.withOpacity(
                                            0.25,
                                          )
                                          : Colors.white.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(20),
                                ),
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
                                                ? Colors.white.withOpacity(0.9)
                                                : Colors.black.withOpacity(0.8),
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
                                          child: Text(
                                            _errorMessage!,
                                            style: TextStyle(
                                              color:
                                                  isDarkMode
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .errorContainer
                                                      : Theme.of(
                                                        context,
                                                      ).colorScheme.error,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.center,
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
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                textStyle: TextStyle(
                                  fontSize: 14.5,
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
                            padding: const EdgeInsets.only(top: 30.0),
                            child: TextButton(
                              onPressed: _switchToLoginMode,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                textStyle: TextStyle(
                                  fontSize: 14.5,
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
          Positioned(
            bottom: 0,
            right: 0,
            left: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'powered by',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Image.asset(
                    'assets/images/upgraide.png',
                    height: 20,
                    color: Colors.white.withOpacity(0.8),
                    colorBlendMode: BlendMode.modulate,
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
            ? Colors.white.withOpacity(0.12)
            : Colors.white.withOpacity(0.35);
    final Color hintAndIconColor =
        isDarkMode
            ? Colors.white.withOpacity(0.65)
            : Colors.black.withOpacity(0.55);
    final Color inputTextColor =
        isDarkMode
            ? Colors.white.withOpacity(0.9)
            : Colors.black.withOpacity(0.85);
    final Color focusedBorderColor =
        isDarkMode
            ? Colors.grey.shade400.withOpacity(
              0.7,
            ) // Cleaner grey for dark mode
            : Colors.grey.shade600.withOpacity(
              0.7,
            ); // Cleaner grey for light mode
    final Color buttonBackgroundColor =
        isDarkMode ? Colors.grey.shade800.withOpacity(0.8) : Colors.white;
    final Color buttonTextColor = isDarkMode ? Colors.white : AppTheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            filled: true,
            fillColor: fieldFillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), // Slightly more rounded
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.15),
                width: 0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: focusedBorderColor,
                width: 1.0,
              ), // Thinner border
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            hintText: 'Email',
            hintStyle: TextStyle(
              color: hintAndIconColor,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14.0, right: 10.0),
              child: Icon(
                Icons.email_outlined,
                color: hintAndIconColor,
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
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.15),
                width: 0.7,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: focusedBorderColor,
                width: 1.0,
              ), // Thinner border
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            hintText: 'Senha',
            hintStyle: TextStyle(
              color: hintAndIconColor,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14.0, right: 10.0),
              child: Icon(
                Icons.lock_outline,
                color: hintAndIconColor,
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
              backgroundColor: buttonBackgroundColor,
              foregroundColor: buttonTextColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              'Entrar',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordForm(BuildContext context, bool isDarkMode) {
    final Color fieldFillColor =
        isDarkMode
            ? Colors.white.withOpacity(0.12)
            : Colors.white.withOpacity(0.35);
    final Color hintAndIconColor =
        isDarkMode
            ? Colors.white.withOpacity(0.65)
            : Colors.black.withOpacity(0.55);
    final Color inputTextColor =
        isDarkMode
            ? Colors.white.withOpacity(0.9)
            : Colors.black.withOpacity(0.85);
    final Color focusedBorderColor =
        isDarkMode
            ? Colors.grey.shade400.withOpacity(
              0.7,
            ) // Cleaner grey for dark mode
            : Colors.grey.shade600.withOpacity(
              0.7,
            ); // Cleaner grey for light mode
    final Color buttonBackgroundColor =
        isDarkMode ? Colors.grey.shade800.withOpacity(0.8) : Colors.white;
    final Color buttonTextColor = isDarkMode ? Colors.white : AppTheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            filled: true,
            fillColor: fieldFillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.15),
                width: 0.7,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: focusedBorderColor,
                width: 1.0,
              ), // Thinner border
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            hintText: 'Email',
            hintStyle: TextStyle(
              color: hintAndIconColor,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14.0, right: 10.0),
              child: Icon(
                Icons.email_outlined,
                color: hintAndIconColor,
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
            onPressed: _isSendingRecovery ? null : _sendRecoveryEmail,
            style: FilledButton.styleFrom(
              backgroundColor: buttonBackgroundColor,
              foregroundColor: buttonTextColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
            child:
                _isSendingRecovery
                    ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        color:
                            buttonTextColor, // Use adapted button text color for consistency
                      ),
                    )
                    : Text(
                      'Recuperar Senha',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessMessage(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36.0), // Increased padding
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded, // More rounded icon
            color: Colors.greenAccent.shade700, // Slightly deeper green
            size: 60,
          ),
          const SizedBox(height: 22),
          Text(
            'Email de recuperação enviado com sucesso!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color:
                  isDarkMode
                      ? Colors.white.withOpacity(0.95)
                      : Colors.black.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
