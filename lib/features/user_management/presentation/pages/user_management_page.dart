import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/domain/models/app_user.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/auth/presentation/providers/cloud_functions_provider.dart';
import '../widgets/user_list_item.dart';
import '../widgets/create_user_form.dart';

class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> {
  bool _isLoading = true;
  bool _isCreatingUser = false;
  List<AppUser> _users = [];
  String? _errorMessage;
  bool _usingCloudFunctions = false;

  @override
  void initState() {
    super.initState();
    _checkCloudFunctions();
    _loadUsers();
  }

  void _checkCloudFunctions() {
    // Read from the Cloud Functions provider we set in main.dart
    _usingCloudFunctions = ref.read(cloudFunctionsAvailableProvider);
    debugPrint('Cloud Functions available: $_usingCloudFunctions');
  }

  Future<void> _loadUsers() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final authRepository = ref.read(authRepositoryProvider);

      // Get all resellers
      final resellers = await authRepository.getAllResellers();

      // For a complete user list, we should get admin users too
      final adminUsers =
          await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'admin')
              .get();

      final admins =
          adminUsers.docs.map((doc) {
            final data = doc.data();
            return AppUser(
              uid: doc.id,
              email: data['email'] as String? ?? '',
              role: UserRole.admin,
              displayName: data['displayName'] as String?,
              photoURL: data['photoURL'] as String?,
              isFirstLogin: data['isFirstLogin'] as bool? ?? false,
              isEmailVerified: data['isEmailVerified'] as bool? ?? false,
              additionalData: data,
            );
          }).toList();

      if (mounted) {
        setState(() {
          _users = [...admins, ...resellers];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load users: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _createUser({
    required String email,
    required String password,
    String? displayName,
  }) async {
    setState(() {
      _isCreatingUser = true;
      _errorMessage = null;
    });

    try {
      debugPrint('Creating user: $email, displayName: $displayName');
      final authRepository = ref.read(authRepositoryProvider);

      // Create the user
      final newUser = await authRepository.createUserWithEmailAndPassword(
        email: email,
        password: password,
        role: UserRole.reseller,
        displayName: displayName,
      );

      debugPrint('User created successfully: ${newUser.uid}');

      // Show success message and close the dialog
      if (mounted) {
        Navigator.of(context).pop(); // Close the dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the user list
        await _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreatingUser = false;
          _errorMessage = e.toString();
        });

        // First show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating user: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(
              seconds: 10,
            ), // Longer duration for important errors
          ),
        );

        // If the error message indicates admin was logged out, handle this specially
        if (e.toString().toLowerCase().contains('logged out') ||
            e.toString().toLowerCase().contains('sign in')) {
          // Close the dialog
          Navigator.of(context).pop();

          // Wait a moment to let the user see the error message
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              // Show a more direct message to the user
              showDialog(
                context: context,
                barrierDismissible: false,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Session Expired'),
                      content: const Text(
                        'Your admin session has expired while creating the user. '
                        'The user was created successfully, but you need to sign in again.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            // Navigate to login page
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                            context.go('/login');
                          },
                          child: const Text('GO TO LOGIN'),
                        ),
                      ],
                    ),
              );
            }
          });
        }
      }
    }
  }

  Future<void> _setUserEnabled(String uid, bool enabled) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.setUserEnabled(uid, enabled);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User ${enabled ? 'enabled' : 'disabled'} successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refresh the user list
      if (mounted) {
        await _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to update user status: ${e.toString()}';
          _isLoading = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetPassword(String email) async {
    try {
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.sendPasswordResetEmail(email);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send password reset email: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Update cloud functions status whenever the widget rebuilds
    _usingCloudFunctions = ref.watch(cloudFunctionsAvailableProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          // Indicator for Cloud Functions status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Tooltip(
              message:
                  _usingCloudFunctions
                      ? 'Cloud Functions enabled - admin won\'t be logged out on user creation'
                      : 'Cloud Functions not available - admin will be logged out on user creation',
              child: Chip(
                label: Text(
                  _usingCloudFunctions
                      ? 'Cloud Functions: ON'
                      : 'Cloud Functions: OFF',
                  style: TextStyle(
                    fontSize: 12,
                    color: _usingCloudFunctions ? Colors.white : Colors.black,
                  ),
                ),
                backgroundColor:
                    _usingCloudFunctions ? Colors.green : Colors.amber,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
              : _users.isEmpty
              ? const Center(child: Text('No users found'))
              : ListView.builder(
                itemCount: _users.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return UserListItem(
                    user: user,
                    onToggleEnabled: _setUserEnabled,
                    onResetPassword: _resetPassword,
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateUserDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateUserDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.grey[850],
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.person_add, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        'Create New User',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_usingCloudFunctions) ...[
                            const Text(
                              'Important Notice:',
                              style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Cloud Functions are not available. You will be automatically signed out when creating a new user. You will need to sign back in after user creation.',
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white24),
                            const SizedBox(height: 16),
                          ],
                          CreateUserForm(
                            onSubmit: _createUser,
                            onCancel: () {
                              Navigator.of(context).pop();
                            },
                            isLoading: _isCreatingUser,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
