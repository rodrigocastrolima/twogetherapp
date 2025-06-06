import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/theme/ui_styles.dart';
import '../../core/theme/theme.dart';

class UserProfileDialog extends StatefulWidget {
  final String? userId;
  final String? currentRole;
  final bool isCurrentlyActive;
  final bool isNewUser;

  const UserProfileDialog({
    super.key,
    this.userId,
    this.currentRole,
    this.isCurrentlyActive = true,
    this.isNewUser = false,
  });

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool isActive = true;
  String role = 'reseller';
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    isActive = widget.isCurrentlyActive;
    role = widget.currentRole ?? 'reseller';
    if (widget.userId != null && !widget.isNewUser) {
      _loadUserData();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get();

      if (doc.exists) {
        setState(() {
          userData = doc.data();
          nameController.text = userData?['displayName'] ?? '';
          emailController.text = userData?['email'] ?? '';
          isActive = userData?['isActive'] ?? true;
          role = userData?['role'] ?? 'reseller';
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user data: ${e.toString()}'),
            backgroundColor: AppTheme.destructive.withAlpha(204),
          ),
        );
      }
    }
  }

  Future<void> _saveUser() async {
    if (nameController.text.trim().isEmpty) {
      _showError('Name cannot be empty');
      return;
    }

    if (emailController.text.trim().isEmpty) {
      _showError('Email cannot be empty');
      return;
    }

    if (widget.isNewUser && passwordController.text.trim().isEmpty) {
      _showError('Password cannot be empty for new users');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      if (widget.isNewUser) {
        // Create new user
        // This is a simplified example - in a real app, you'd use Firebase Auth
        final userData = {
          'displayName': nameController.text.trim(),
          'email': emailController.text.trim(),
          'role': role,
          'isActive': isActive,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance.collection('users').add(userData);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('User created successfully'),
              backgroundColor: Colors.green.withAlpha(204),
            ),
          );
        }
      } else {
        // Update existing user
        final userData = {
          'displayName': nameController.text.trim(),
          'email': emailController.text.trim(),
          'role': role,
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .update(userData);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('User updated successfully'),
              backgroundColor: Colors.green.withAlpha(204),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showError('Error saving user: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.destructive.withAlpha(204),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: AppStyles.standardBlur,
          child: Container(
            width: 450,
            decoration: AppStyles.glassCard(context),
            padding: const EdgeInsets.all(24),
            child:
                isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                      ),
                    )
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isNewUser ? 'Add New User' : 'Edit User',
                          style: AppTextStyles.h3.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          controller: nameController,
                          label: 'Name',
                          icon: CupertinoIcons.person,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: emailController,
                          label: 'Email',
                          icon: CupertinoIcons.mail,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        if (widget.isNewUser) ...[
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: passwordController,
                            label: 'Password',
                            icon: CupertinoIcons.lock,
                            isPassword: true,
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          'Role',
                          style: AppTextStyles.body1.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: AppStyles.inputContainer(context),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: role,
                              isExpanded: true,
                              dropdownColor: AppColors.withOpacity(AppColors.logoBlack, 0.7),
                              style: AppTextStyles.body1.copyWith(
                                color: Colors.white,
                              ),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    role = value;
                                  });
                                }
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: 'reseller',
                                  child: Text('Reseller'),
                                ),
                                DropdownMenuItem(
                                  value: 'admin',
                                  child: Text('Admin'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: Text(
                            'Active Account',
                            style: AppTextStyles.body1.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            'Users with inactive accounts cannot login',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.withOpacity(AppColors.logoWhite, 0.7),
                            ),
                          ),
                          value: isActive,
                          activeColor: Colors.green,
                          onChanged: (value) {
                            setState(() {
                              isActive = value;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: AppTextStyles.button.copyWith(
                                  color: AppColors.withOpacity(AppColors.logoWhite, 0.9),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: _saveUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFBE45), // tulip tree color
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                widget.isNewUser
                                    ? 'Create User'
                                    : 'Save Changes',
                                style: AppTextStyles.button.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.body1.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          decoration: AppStyles.inputContainer(context),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            style: AppTextStyles.body1.copyWith(color: Colors.white),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: InputBorder.none,
              prefixIcon: Icon(icon, color: AppColors.withOpacity(AppColors.logoWhite, 0.7), size: 20),
            ),
          ),
        ),
      ],
    );
  }
}
