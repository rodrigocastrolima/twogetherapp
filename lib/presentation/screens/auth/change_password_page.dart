import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../presentation/layout/main_layout.dart';
import '../../../app/router/app_router.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../features/chat/data/repositories/chat_repository.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  void _handleChangePassword() async {
    // Validate password
    if (_newPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter a new password');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    if (_newPasswordController.text.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Update password in Firebase
      await AppRouter.authNotifier.updatePassword(_newPasswordController.text);

      // Ensure firstLogin is marked as completed
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.completeFirstLogin();
      debugPrint('First login marked as completed');

      // Ensure the conversation is created for reseller users
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          // Get the user role from Firestore
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
              // For resellers, ensure conversation exists
              debugPrint(
                'First login completed for reseller, ensuring conversation exists',
              );
              final chatRepository = ChatRepository();
              await chatRepository.ensureResellerHasConversation(user.uid);
              debugPrint('Conversation created or verified for reseller');
            }
          }
        } catch (e) {
          debugPrint('Error ensuring conversation after password change: $e');
          // Don't block the completion process for this error
        }
      }

      // Add a short delay to ensure Firebase operations complete
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully')),
        );

        // Force the app to recognize the first login is complete
        Future.delayed(const Duration(milliseconds: 500), () {
          // Navigate back to home page
          if (mounted) {
            // Additional guard to prevent navigation when widget is disposed
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to update password: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final double padding = size.width < 400 ? 16.0 : 24.0;

    return MainLayout(
      currentIndex: -1,
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
                    SizedBox(height: isSmallScreen ? 32 : 48),

                    // Title
                    Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Please set a new password for your account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.foreground.withAlpha(179),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 24 : 32),

                    // Form Container
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: isSmallScreen ? size.width * 0.8 : 320,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // New Password field
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: TextField(
                                controller: _newPasswordController,
                                decoration: InputDecoration(
                                  labelText: 'New Password',
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
                                  fillColor: Colors.white.withAlpha(26),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withAlpha(51),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withAlpha(51),
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

                          // Confirm Password field
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: TextField(
                                controller: _confirmPasswordController,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
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
                                  fillColor: Colors.white.withAlpha(26),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withAlpha(51),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withAlpha(51),
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

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontSize: 14,
                              ),
                            ),
                          ],

                          const SizedBox(height: 32),

                          // Submit button
                          FilledButton(
                            onPressed:
                                _isLoading ? null : _handleChangePassword,
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
                                    ? SizedBox(
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
                                      'Change Password',
                                      style: TextStyle(
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
