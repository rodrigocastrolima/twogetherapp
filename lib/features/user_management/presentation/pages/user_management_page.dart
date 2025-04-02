import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../../../../features/auth/domain/models/app_user.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/auth/presentation/providers/cloud_functions_provider.dart';
import '../widgets/create_user_form.dart';
import '../../../../core/theme/theme.dart';
import 'package:flutter/foundation.dart';

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
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _checkCloudFunctions();
    _loadUsers();
  }

  void _checkCloudFunctions() {
    // Read from the Cloud Functions provider we set in main.dart
    _usingCloudFunctions = ref.read(cloudFunctionsAvailableProvider);
  }

  Future<void> _loadUsers() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    // Add a timeout mechanism to prevent UI from being stuck in loading state
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        if (kDebugMode) {
          print(
            '_loadUsers: TIMEOUT - Loading state took too long, forcing reset',
          );
        }
        setState(() {
          _isLoading = false;
          _errorMessage = 'Loading timed out. Please try again.';
        });
      }
    });

    try {
      if (kDebugMode) {
        print('=== _loadUsers: Starting to load users ===');
        print('Current user ID: $_currentUserId');
      }

      final authRepository = ref.read(authRepositoryProvider);

      if (kDebugMode) {
        print('_loadUsers: Getting resellers...');
      }

      // Get all resellers
      final resellers = await authRepository.getAllResellers();

      if (kDebugMode) {
        print('_loadUsers: Got ${resellers.length} resellers');
      }

      if (kDebugMode) {
        print('_loadUsers: Getting admin users...');
      }

      // For a complete user list, we should get admin users too
      final adminUsers =
          await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'admin')
              .get();

      if (kDebugMode) {
        print('_loadUsers: Got ${adminUsers.docs.length} admin users');
      }

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
        // Filter out the current user and combine the lists
        final allUsers = [...admins, ...resellers];
        _users = allUsers.where((user) => user.uid != _currentUserId).toList();

        if (kDebugMode) {
          print(
            '_loadUsers: Total users (after filtering current user): ${_users.length}',
          );
          print('_loadUsers: Setting isLoading to false');
        }

        setState(() {
          _isLoading = false;
        });

        if (kDebugMode) {
          print('=== _loadUsers: Completed loading users ===');
        }
      } else {
        if (kDebugMode) {
          print('_loadUsers: Widget no longer mounted, skipping state update');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('_loadUsers ERROR: ${e.toString()}');
        print('Error type: ${e.runtimeType}');
        print(StackTrace.current);
      }

      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load users: ${e.toString()}';
          _isLoading = false;
        });

        if (kDebugMode) {
          print('_loadUsers: Set error message and isLoading to false');
        }
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
      final authRepository = ref.read(authRepositoryProvider);

      // Create the user
      final newUser = await authRepository.createUserWithEmailAndPassword(
        email: email,
        password: password,
        role: UserRole.reseller,
        displayName: displayName,
      );

      // Show success message and close the dialog
      if (mounted) {
        Navigator.of(context).pop(); // Close the dialog

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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

  Future<void> _resetPassword(String uid, String email) async {
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

  Future<void> _deleteUser(String uid) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.deleteUser(uid);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully'),
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
          _errorMessage = 'Failed to delete user: ${e.toString()}';
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

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else {
      return 'N/A';
    }

    return DateFormat('MMM dd, yyyy - HH:mm').format(date);
  }

  void _showUserActionMenu(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder:
          (context) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              backgroundColor: Colors.grey[850],
              title: Text(
                'Manage ${user.displayName ?? user.email}',
                style: const TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.password, color: AppTheme.primary),
                    title: const Text(
                      'Reset Password',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _resetPassword(user.uid, user.email);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      user.additionalData?['isEnabled'] == false
                          ? Icons.check_circle
                          : Icons.block,
                      color:
                          user.additionalData?['isEnabled'] == false
                              ? Colors.green
                              : Colors.red,
                    ),
                    title: Text(
                      user.additionalData?['isEnabled'] == false
                          ? 'Enable User'
                          : 'Disable User',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _setUserEnabled(
                        user.uid,
                        !(user.additionalData?['isEnabled'] ?? true),
                      );
                    },
                  ),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text(
                      'Delete User',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _showDeleteConfirmation(context, user);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text('CLOSE'),
                ),
              ],
            ),
          ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder:
          (context) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              backgroundColor: Colors.grey[850],
              title: const Text(
                'Delete User',
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                'Are you sure you want to permanently delete ${user.displayName ?? user.email}? This action cannot be undone.',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _deleteUser(user.uid);
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('DELETE'),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildUserTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if we're on a small screen (mobile)
        final isSmallScreen = constraints.maxWidth < 700;

        if (isSmallScreen) {
          // Mobile-friendly card layout
          return ListView.builder(
            itemCount: _users.length,
            padding: const EdgeInsets.only(bottom: 16),
            itemBuilder: (context, index) {
              final user = _users[index];
              final bool isEnabled = user.additionalData?['isEnabled'] ?? true;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.black.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User info row with action button
                      Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            backgroundColor:
                                user.role == UserRole.admin
                                    ? Colors.amber
                                    : AppTheme.primary,
                            radius: 20,
                            child: Text(
                              user.displayName?.isNotEmpty == true
                                  ? user.displayName![0].toUpperCase()
                                  : user.email.isNotEmpty
                                  ? user.email[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Name and role
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName ?? 'No Name',
                                  style: TextStyle(
                                    color: AppTheme.foreground,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    decoration:
                                        !isEnabled
                                            ? TextDecoration.lineThrough
                                            : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (user.role == UserRole.admin
                                                ? Colors.amber
                                                : AppTheme.primary)
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        user.role == UserRole.admin
                                            ? 'Admin'
                                            : 'Reseller',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              user.role == UserRole.admin
                                                  ? Colors.amber
                                                  : AppTheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (!isEnabled) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Text(
                                          'Disabled',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Action button
                          IconButton(
                            icon: const Icon(Icons.more_vert),
                            color: AppTheme.foreground,
                            onPressed: () => _showUserActionMenu(context, user),
                            tooltip: 'User Actions',
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 24),
                      // Email
                      _buildInfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: user.email,
                      ),
                      const SizedBox(height: 8),
                      // Created at
                      _buildInfoRow(
                        icon: Icons.calendar_today,
                        label: 'Created',
                        value: _formatDate(user.additionalData?['createdAt']),
                      ),
                      const SizedBox(height: 8),
                      // Last login
                      _buildInfoRow(
                        icon: Icons.login,
                        label: 'Last Login',
                        value: _formatDate(user.additionalData?['lastLoginAt']),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        } else {
          // Desktop table layout - existing implementation
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'User',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.foreground,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Email',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.foreground,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Role',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.foreground,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Created',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.foreground,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Last Login',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.foreground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 60), // Actions column width
                      ],
                    ),
                  ),

                  // Table content
                  Expanded(
                    child: ListView.separated(
                      itemCount: _users.length,
                      padding: EdgeInsets.zero,
                      separatorBuilder:
                          (context, index) => Divider(
                            color: Colors.white.withOpacity(0.1),
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final bool isEnabled =
                            user.additionalData?['isEnabled'] ?? true;

                        return Container(
                          color:
                              index % 2 == 0
                                  ? Colors.transparent
                                  : Colors.white.withOpacity(0.05),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            title: Row(
                              children: [
                                // User name/display name
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            user.role == UserRole.admin
                                                ? Colors.amber
                                                : AppTheme.primary,
                                        radius: 16,
                                        child: Text(
                                          user.displayName?.isNotEmpty == true
                                              ? user.displayName![0]
                                                  .toUpperCase()
                                              : user.email.isNotEmpty
                                              ? user.email[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user.displayName ?? 'No Name',
                                              style: TextStyle(
                                                color: AppTheme.foreground,
                                                fontWeight: FontWeight.w500,
                                                decoration:
                                                    !isEnabled
                                                        ? TextDecoration
                                                            .lineThrough
                                                        : null,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (!isEnabled)
                                              Text(
                                                'Disabled',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Email
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    user.email,
                                    style: TextStyle(
                                      color: AppTheme.foreground.withOpacity(
                                        0.8,
                                      ),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // Role
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (user.role == UserRole.admin
                                              ? Colors.amber
                                              : AppTheme.primary)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      user.role == UserRole.admin
                                          ? 'Admin'
                                          : 'Reseller',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            user.role == UserRole.admin
                                                ? Colors.amber
                                                : AppTheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),

                                // Created date
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatDate(
                                      user.additionalData?['createdAt'],
                                    ),
                                    style: TextStyle(
                                      color: AppTheme.foreground.withOpacity(
                                        0.8,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),

                                // Last login
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatDate(
                                      user.additionalData?['lastLoginAt'],
                                    ),
                                    style: TextStyle(
                                      color: AppTheme.foreground.withOpacity(
                                        0.8,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),

                                // Actions
                                SizedBox(
                                  width: 60,
                                  child: IconButton(
                                    icon: const Icon(Icons.more_vert),
                                    color: AppTheme.foreground,
                                    onPressed:
                                        () =>
                                            _showUserActionMenu(context, user),
                                    tooltip: 'User Actions',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  // Helper method to build info rows for mobile view
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.foreground.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.foreground.withOpacity(0.7),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: AppTheme.foreground),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Update cloud functions status whenever the widget rebuilds
    _usingCloudFunctions = ref.watch(cloudFunctionsAvailableProvider);

    // Get screen size to determine layout
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 700;

    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header - responsive layout
          if (isSmallScreen) ...[
            // Mobile layout - stacked vertically
            Text(
              'User Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create and manage reseller accounts',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.foreground.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create User'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _showCreateUserDialog,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  color: AppTheme.foreground,
                  onPressed: _loadUsers,
                  tooltip: 'Refresh user list',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Desktop layout - side by side
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Management',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create and manage reseller accounts',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.foreground.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      color: AppTheme.foreground,
                      onPressed: _loadUsers,
                      tooltip: 'Refresh user list',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Create User'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _showCreateUserDialog,
                    ),
                  ],
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Content
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading users...',
                            style: TextStyle(
                              color: AppTheme.foreground.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                    : _errorMessage != null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.withOpacity(0.8),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.withOpacity(0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _loadUsers,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    )
                    : _users.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: AppTheme.foreground.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppTheme.foreground.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _showCreateUserDialog,
                            icon: const Icon(Icons.person_add),
                            label: const Text('Create First User'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : _buildUserTable(),
          ),
        ],
      ),
    );
  }

  void _showCreateUserDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Get screen size to check if we're on a small screen
        final Size screenSize = MediaQuery.of(context).size;
        final bool isSmallScreen = screenSize.width < 600;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.transparent,
            // Use more space on small screens
            insetPadding:
                isSmallScreen
                    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
                    : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  constraints: BoxConstraints(
                    maxWidth: isSmallScreen ? double.infinity : 500,
                    maxHeight: isSmallScreen ? screenSize.height * 0.9 : 600,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: isSmallScreen ? 12.0 : 16.0,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person_add, color: AppTheme.primary),
                            const SizedBox(width: 12),
                            Text(
                              'Create New User',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 18 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(color: Colors.white.withOpacity(0.2)),
                      // Form content
                      Flexible(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: EdgeInsets.all(
                              isSmallScreen ? 12.0 : 16.0,
                            ),
                            child: CreateUserForm(
                              onSubmit: _createUser,
                              onCancel: () {
                                Navigator.of(context).pop();
                              },
                              isLoading: _isCreatingUser,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
