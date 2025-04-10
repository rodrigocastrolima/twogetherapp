import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../presentation/layout/main_layout.dart';
import '../../../app/router/app_router.dart';
import '../../../core/theme/ui_styles.dart';
import '../../../core/services/loading_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _handleLogin() async {
    try {
      // Validate the login credentials
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Simple validation
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Please enter email and password');
      }

      // Use loading service to show loading overlay
      final loadingService = ref.read(loadingServiceProvider);
      loadingService.show(context, message: 'Logging in...', showLogo: true);

      try {
        // Attempt login
        await AppRouter.authNotifier.signInWithEmailAndPassword(
          email,
          password,
        );
      } finally {
        // Always hide loading overlay
        loadingService.hide();
      }

      // No need to navigate manually - the router redirect will handle it
    } catch (e) {
      // Handle login error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}')),
        );
      }
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
    final l10n = AppLocalizations.of(context)!;
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
          // Login content
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
                      minHeight: isSmallScreen ? 0.0 : 520,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Form Container
                        Container(
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
                          constraints: BoxConstraints(
                            maxWidth: isSmallScreen ? size.width * 0.7 : 340,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 18 : 24,
                              vertical: isSmallScreen ? 16 : 24,
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
                                SizedBox(height: isSmallScreen ? 16 : 24),

                                // Email field
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
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outlineVariant
                                              .withOpacity(0.4),
                                          width: 1.0,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: AppTheme.primary,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _emailController,
                                    decoration: InputDecoration(
                                      hintText: l10n.loginUsername,
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
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 13,
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Password field
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
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outlineVariant
                                              .withOpacity(0.4),
                                          width: 1.0,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: AppTheme.primary,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _passwordController,
                                    decoration: InputDecoration(
                                      hintText: l10n.loginPassword,
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
                                      isDense: true,
                                    ),
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 13,
                                    ),
                                    obscureText: true,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _handleLogin(),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 26 : 34),

                                // Login button
                                SizedBox(
                                  width: double.infinity,
                                  height: 38,
                                  child: FilledButton(
                                    onPressed: _handleLogin,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor:
                                          AppTheme.primaryForeground,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      l10n.loginButton,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
