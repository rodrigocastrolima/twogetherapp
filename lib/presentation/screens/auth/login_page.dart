import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../core/theme/theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../presentation/layout/main_layout.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  final bool _isLoading = false;

  void _handleLogin() {
    // For now, just navigate to main layout without validation
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MainLayout(showNavigation: true),
      ),
    );
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
    final double padding = size.width < 400 ? 16.0 : 24.0;

    return MainLayout(
      showBackButton: false,
      showNavigation: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: padding,
                vertical: padding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isSmallScreen ? size.width * 0.9 : 400,
                  minHeight: isSmallScreen ? 0.0 : 520,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isSmallScreen ? size.width * 0.8 : 360,
                        ),
                        child: AspectRatio(
                          aspectRatio: 2.0,
                          child: Image.asset(
                            'assets/images/twogether_logo_light_br.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 48 : 64),

                    // Form Container
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: isSmallScreen ? size.width * 0.8 : 320,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email field
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: TextField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: l10n.loginUsername,
                                  labelStyle: TextStyle(
                                    color: AppTheme.foreground,
                                    fontSize: 15,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    color: AppTheme.foreground,
                                    size: 20,
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppTheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                ),
                                style: TextStyle(
                                  color: AppTheme.foreground,
                                  fontSize: 15,
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password field
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: TextField(
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  labelText: l10n.loginPassword,
                                  labelStyle: TextStyle(
                                    color: AppTheme.foreground,
                                    fontSize: 15,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    color: AppTheme.foreground,
                                    size: 20,
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppTheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                ),
                                style: TextStyle(
                                  color: AppTheme.foreground,
                                  fontSize: 15,
                                ),
                                obscureText: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Remember me checkbox
                          Transform.translate(
                            offset: const Offset(-8, 0),
                            child: Row(
                              children: [
                                Transform.scale(
                                  scale: 0.9,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) {
                                      setState(() {
                                        _rememberMe = value ?? false;
                                      });
                                    },
                                    activeColor: AppTheme.primary,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                Text(
                                  l10n.loginRememberMe,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.foreground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Login button
                          FilledButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: AppTheme.primaryForeground,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : Text(
                                      l10n.loginButton,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
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
        ),
      ),
    );
  }
}
