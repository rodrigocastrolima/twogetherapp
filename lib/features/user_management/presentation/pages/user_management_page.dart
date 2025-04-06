import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../features/auth/domain/models/app_user.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/auth/presentation/providers/cloud_functions_provider.dart';
import '../widgets/create_user_form.dart';
import 'package:flutter/foundation.dart';

class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  UserManagementPageState createState() => UserManagementPageState();
}

class UserManagementPageState extends ConsumerState<UserManagementPage> {
  bool _isLoading = true;
  bool _isCreatingUser = false;
  List<AppUser> _users = [];
  String? _errorMessage;
  late final String _currentUserId;
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadUsers();
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
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isCreatingUser = true;
      _errorMessage = null;
    });

    try {
      final authRepository = ref.read(authRepositoryProvider);

      await authRepository.createUserWithEmailAndPassword(
        email: email,
        password: password,
        role: UserRole.reseller,
        displayName: displayName,
      );

      // Show success message and close the dialog
      if (mounted) {
        Navigator.of(context).pop(); // Close the dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonSave),
            backgroundColor: Theme.of(context).colorScheme.secondary,
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
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
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
                      title: Text(l10n.profileEndSession),
                      content: Text(
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
                          child: Text(l10n.loginButton),
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
    final l10n = AppLocalizations.of(context)!;

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
            content: Text(enabled ? l10n.active : l10n.inactive),
            backgroundColor: Theme.of(context).colorScheme.secondary,
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
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _resetPassword(String uid, String email) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.sendPasswordResetEmail(email);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileChangePassword),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _deleteUser(String uid) async {
    final l10n = AppLocalizations.of(context)!;

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
          SnackBar(
            content: Text(l10n.commonDelete),
            backgroundColor: Theme.of(context).colorScheme.secondary,
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
            backgroundColor: Theme.of(context).colorScheme.error,
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
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder:
          (context) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surface.withAlpha((255 * 0.9).round()),
              title: Text(
                '${l10n.commonMore}: ${user.displayName ?? user.email}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.password,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      l10n.profileChangePassword,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _resetPassword(user.uid, user.email);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      user.additionalData['isEnabled'] == false
                          ? Icons.check_circle
                          : Icons.block,
                      color:
                          user.additionalData['isEnabled'] == false
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      user.additionalData['isEnabled'] == false
                          ? l10n.active
                          : l10n.inactive,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _setUserEnabled(
                        user.uid,
                        !(user.additionalData['isEnabled'] ?? true),
                      );
                    },
                  ),
                  Divider(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.2).round()),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      l10n.commonDelete,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                  ),
                  child: Text(l10n.commonCancel),
                ),
              ],
            ),
          ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AppUser user) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder:
          (context) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surface.withAlpha((255 * 0.9).round()),
              title: Text(
                l10n.commonDelete,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                ),
              ),
              content: Text(
                'Are you sure you want to permanently delete ${user.displayName ?? user.email}? This action cannot be undone.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                  ),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _deleteUser(user.uid);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: Text(l10n.commonDelete),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildUserTable() {
    final l10n = AppLocalizations.of(context)!;
    
    // Filter users based on search query
    final filteredUsers = searchQuery.isEmpty
        ? _users
        : _users.where((user) {
            final name = user.displayName?.toLowerCase() ?? '';
            final email = user.email.toLowerCase();
            final query = searchQuery.toLowerCase();
            return name.contains(query) || email.contains(query);
          }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if we're on a small screen (mobile)
        final isSmallScreen = constraints.maxWidth < 700;

        if (isSmallScreen) {
          // Mobile-friendly card layout
          return filteredUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.5).round()),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.noRetailUsersFound,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredUsers.length,
            padding: const EdgeInsets.only(bottom: 16),
            itemBuilder: (context, index) {
                    final user = filteredUsers[index];
              final bool isEnabled = user.additionalData['isEnabled'] ?? true;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Theme.of(context).colorScheme.surface.withAlpha((255 * 0.2).round()),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.1).round()),
                    width: 0.5,
                  ),
                ),
                child: InkWell(
                  onTap: () => _navigateToUserDetailPage(user),
                  borderRadius: BorderRadius.circular(12),
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
                                              ? Theme.of(context).colorScheme.secondary
                                              : Theme.of(context).colorScheme.primary,
                              radius: 20,
                              child: Text(
                                user.displayName?.isNotEmpty == true
                                    ? user.displayName![0].toUpperCase()
                                    : user.email.isNotEmpty
                                    ? user.email[0].toUpperCase()
                                            : l10n.userInitialsDefault,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
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
                                            user.displayName ?? l10n.unknownUser,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyLarge?.copyWith(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
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
                                                        ? Theme.of(
                                                          context,
                                                        ).colorScheme.secondary
                                                        : Theme.of(
                                                          context,
                                                        ).colorScheme.primary)
                                            .withAlpha((255 * 0.2).round()),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        user.role == UserRole.admin
                                            ? 'Admin'
                                            : 'Reseller',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.labelSmall?.copyWith(
                                          color:
                                              user.role == UserRole.admin
                                                          ? Theme.of(
                                                            context,
                                                          ).colorScheme.secondary
                                                          : Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
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
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.error.withAlpha((255 * 0.2).round()),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                                child: Text(
                                                  l10n.inactive,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.labelSmall?.copyWith(
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.error,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            // Action button
                            IconButton(
                              icon: Icon(
                                Icons.more_vert,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              onPressed: () => _showUserActionMenu(context, user),
                              tooltip: l10n.commonMore,
                            ),
                          ],
                        ),
                        Divider(
                          color: Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.2).round()),
                          height: 24,
                        ),
                        // Email
                        _buildInfoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: user.email.isEmpty
                              ? l10n.noEmailProvided
                              : user.email,
                        ),
                        const SizedBox(height: 8),
                        // Created at
                        _buildInfoRow(
                          icon: Icons.calendar_today,
                          label: l10n.commonDate,
                          value: _formatDate(user.additionalData['createdAt']),
                        ),
                        const SizedBox(height: 8),
                        // Last login
                        _buildInfoRow(
                          icon: Icons.login,
                          label: 'Last Login',
                          value: _formatDate(user.additionalData['lastLoginAt']),
                        ),
                      ],
                    ),
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
                color: Theme.of(
                  context,
                ).colorScheme.surface.withAlpha((255 * 0.2).round()),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withAlpha((255 * 0.3).round()),
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha((255 * 0.1).round()),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            l10n.adminUserManagement,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Email',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Role',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            l10n.commonDate,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Last Login',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 60), // Actions column width
                      ],
                    ),
                  ),

                  // Table content
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.5).round()),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.noRetailUsersFound,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredUsers.length,
                      padding: EdgeInsets.zero,
                      separatorBuilder:
                          (context, index) => Divider(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withAlpha((255 * 0.1).round()),
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                      itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                        final bool isEnabled =
                            user.additionalData['isEnabled'] ?? true;

                              return InkWell(
                                onTap: () => _navigateToUserDetailPage(user),
                                child: Container(
                          color:
                              index % 2 == 0
                                  ? Colors.transparent
                                          : Theme.of(
                                            context,
                                          ).colorScheme.onSurface.withAlpha((255 * 0.05).round()),
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
                                                        ? Theme.of(
                                                          context,
                                                        ).colorScheme.secondary
                                                        : Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                        radius: 16,
                                        child: Text(
                                          user.displayName?.isNotEmpty == true
                                              ? user.displayName![0]
                                                  .toUpperCase()
                                              : user.email.isNotEmpty
                                              ? user.email[0].toUpperCase()
                                                      : l10n.userInitialsDefault,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium?.copyWith(
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.onPrimary,
                                            fontWeight: FontWeight.bold,
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
                                                      user.displayName ??
                                                          l10n.unknownUser,
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.bodyMedium?.copyWith(
                                                        color:
                                                            Theme.of(
                                                              context,
                                                            ).colorScheme.onSurface,
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
                                                        l10n.inactive,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                              color:
                                                                  Theme.of(
                                                                    context,
                                                                  ).colorScheme.error,
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
                                            user.email.isEmpty
                                                ? l10n.noEmailProvided
                                                : user.email,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withAlpha((255 * 0.8).round()),
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
                                                      ? Theme.of(
                                                        context,
                                                      ).colorScheme.secondary
                                                      : Theme.of(
                                                        context,
                                                      ).colorScheme.primary)
                                          .withAlpha((255 * 0.2).round()),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      user.role == UserRole.admin
                                          ? 'Admin'
                                          : 'Reseller',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelSmall?.copyWith(
                                        color:
                                            user.role == UserRole.admin
                                                        ? Theme.of(
                                                          context,
                                                        ).colorScheme.secondary
                                                        : Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
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
                                      user.additionalData['createdAt'],
                                    ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withAlpha((255 * 0.8).round()),
                                    ),
                                  ),
                                ),

                                // Last login
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatDate(
                                      user.additionalData['lastLoginAt'],
                                    ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withAlpha((255 * 0.8).round()),
                                    ),
                                  ),
                                ),

                                // Actions
                                SizedBox(
                                  width: 60,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    onPressed: () => _showUserActionMenu(context, user),
                                    tooltip: l10n.commonMore,
                                  ),
                                ),
                              ],
                                    ),
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
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size to determine layout
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 700;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header - responsive layout
          if (isSmallScreen) ...[
            // Mobile layout - stacked vertically
            Text(
              l10n.adminUserManagement,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.adminUserManagementDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
              ),
            ),
            const SizedBox(height: 16),
            // Search filter
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: l10n.commonSearch,
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withAlpha((255 * 0.3).round()),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.trim();
                });
              },
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  color: Theme.of(context).colorScheme.onSurface,
                  onPressed: _loadUsers,
                  tooltip: l10n.refresh,
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.1).round()),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l10n.clientsPageAddClient),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  onPressed: _showCreateUserDialog,
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
                      l10n.adminUserManagement,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.adminUserManagementDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      color: Theme.of(context).colorScheme.onSurface,
                      onPressed: _loadUsers,
                      tooltip: l10n.refresh,
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha((255 * 0.1).round()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(l10n.clientsPageAddClient),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
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
            const SizedBox(height: 16),
            // Search filter
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: l10n.commonSearch,
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withAlpha((255 * 0.3).round()),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.trim();
                });
              },
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
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.commonLoading,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
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
                            color: Theme.of(
                              context,
                            ).colorScheme.error.withAlpha((255 * 0.8).round()),
                          ),
                          const SizedBox(height: 16),
                          Text(
                  _errorMessage!,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.error.withAlpha((255 * 0.9).round()),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _loadUsers,
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.tryAgain),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha((255 * 0.5).round()),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noRetailUsersFound,
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
        onPressed: _showCreateUserDialog,
                            icon: const Icon(Icons.person_add),
                            label: Text(l10n.clientsPageAddClient),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
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
    final l10n = AppLocalizations.of(context)!;

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
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withAlpha((255 * 0.8).round()),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.2).round()),
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
                            Icon(
                              Icons.person_add,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              l10n.clientsPageAddClient,
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                              ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withAlpha((255 * 0.1).round()),
                              ),
                      ),
                    ],
                  ),
                ),
                      Divider(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha((255 * 0.2).round()),
                      ),
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

  // Navigate to user details page when a user is clicked
  void _navigateToUserDetailPage(AppUser user) {
    if (kDebugMode) {
      print('Navigating to user detail page for user ID: ${user.uid}');
    }
    
    // Navigate to user detail page with the user data
    context.push('/admin/users/${user.uid}', extra: user);
  }
}
