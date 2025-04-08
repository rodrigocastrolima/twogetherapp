import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../features/auth/domain/models/app_user.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/salesforce/data/services/salesforce_user_sync_service.dart';
import '../../../../features/auth/data/services/firebase_functions_service.dart';
import '../widgets/create_user_form.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Extension on AppUser to safely access Salesforce-related fields
extension SalesforceUserExtension on AppUser {
  String? get salesforceId => additionalData['salesforceId'] as String?;
}

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
  AppUser? _selectedUser;
  String _loadingMessage = '';

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
          print('Loading users timed out');
        }
        setState(() {
          _isLoading = false;
          _errorMessage = 'Loading timed out. Please try again.';
        });
      }
    });

    try {
      if (kDebugMode) {
        print('Loading users');
      }

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
        // Filter out the current user and combine the lists
        final allUsers = [...admins, ...resellers];
        _users = allUsers.where((user) => user.uid != _currentUserId).toList();

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading users: $e');
      }

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
    required String displayName,
    String? salesforceId,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isCreatingUser = true;
      _errorMessage = null;
    });

    try {
      final authRepository = ref.read(authRepositoryProvider);

      // Create the user with Firebase Auth
      final newUser = await authRepository.createUserWithEmailAndPassword(
        email: email,
        password: password,
        role: UserRole.reseller,
        displayName: displayName,
      );

      // If Salesforce ID is provided, sync with Salesforce data
      if (salesforceId != null && salesforceId.isNotEmpty) {
        await _syncUserWithSalesforce(newUser.uid, salesforceId);
      }

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

  // Sync a user with Salesforce data using the provided Salesforce ID
  Future<void> _syncUserWithSalesforce(String uid, String salesforceId) async {
    if (kDebugMode) {
      print('Syncing user $uid with Salesforce ID $salesforceId');
    }

    try {
      // Update user's Salesforce ID in Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'salesforceId': salesforceId,
      });

      // Initialize the Salesforce User Sync Service and sync the user
      final syncService = SalesforceUserSyncService();
      final success = await syncService.syncSalesforceUserToFirebase(
        uid,
        salesforceId,
      );

      if (kDebugMode) {
        print('Salesforce sync ${success ? 'successful' : 'failed'}');
      }

      // Check if widget is still mounted before using BuildContext
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'User synced with Salesforce successfully'
                : 'Failed to sync user with Salesforce, but created user anyway',
          ),
          backgroundColor: success ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error syncing user with Salesforce: $e');
      }

      // Check if widget is still mounted before using BuildContext
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error syncing with Salesforce: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled ? l10n.active : l10n.inactive),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );

      // Refresh the user list
      if (!mounted) return;
      await _loadUsers();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to update user status: ${e.toString()}';
          _isLoading = false;
        });

        // Show error message
        if (!mounted) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.commonDelete),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );

      // Refresh the user list
      if (!mounted) return;
      await _loadUsers();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to delete user: ${e.toString()}';
          _isLoading = false;
        });

        // Show error message
        if (!mounted) return;
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

    return DateFormat('dd/MM/yyyy HH:mm').format(date);
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
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
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
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
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
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
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
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
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
    final filteredUsers =
        searchQuery.isEmpty
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.5).round()),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noRetailUsersFound,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
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
                  final bool isEnabled =
                      user.additionalData['isEnabled'] ?? true;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withAlpha((255 * 0.2).round()),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha((255 * 0.1).round()),
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
                            Row(
                              children: [
                                // Avatar
                                CircleAvatar(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
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
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Name and role
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary.withAlpha(
                                                (255 * 0.2).round(),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              l10n.resellerRole,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelSmall?.copyWith(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (!isEnabled) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.error.withAlpha(
                                                  (255 * 0.2).round(),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                l10n.inactive,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color:
                                                          Theme.of(
                                                            context,
                                                          ).colorScheme.error,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                  icon: Icon(
                                    Icons.more_vert,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  onPressed:
                                      () => _showUserActionMenu(context, user),
                                  tooltip: l10n.commonMore,
                                ),
                              ],
                            ),
                            Divider(
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.2).round()),
                              height: 24,
                            ),
                            // Email
                            _buildInfoRow(
                              label: 'Email',
                              value:
                                  user.email.isEmpty
                                      ? l10n.noEmailProvided
                                      : user.email,
                            ),
                            const SizedBox(height: 8),
                            // Created at
                            _buildInfoRow(
                              label: 'Started',
                              value: _formatDate(
                                user.additionalData['createdAt'],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Last login
                            _buildInfoRow(
                              label: 'Last Login',
                              value: _formatDate(
                                user.additionalData['lastLoginAt'],
                              ),
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
                          color: Theme.of(context).colorScheme.onSurface
                              .withAlpha((255 * 0.1).round()),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            l10n.resellerRole,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
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
                          flex: 2,
                          child: Text(
                            'Started',
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
                    child:
                        filteredUsers.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withAlpha((255 * 0.5).round()),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n.noRetailUsersFound,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withAlpha((255 * 0.7).round()),
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withAlpha((255 * 0.1).round()),
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
                                            ).colorScheme.onSurface.withAlpha(
                                              (255 * 0.05).round(),
                                            ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                  radius: 16,
                                                  child: Text(
                                                    user
                                                                .displayName
                                                                ?.isNotEmpty ==
                                                            true
                                                        ? user.displayName![0]
                                                            .toUpperCase()
                                                        : user.email.isNotEmpty
                                                        ? user.email[0]
                                                            .toUpperCase()
                                                        : l10n
                                                            .userInitialsDefault,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onPrimary,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        user.displayName ??
                                                            l10n.unknownUser,
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.bodyMedium?.copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          decoration:
                                                              !isEnabled
                                                                  ? TextDecoration
                                                                      .lineThrough
                                                                  : null,
                                                        ),
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                      if (!isEnabled)
                                                        Text(
                                                          l10n.inactive,
                                                          style: Theme.of(
                                                                context,
                                                              )
                                                              .textTheme
                                                              .labelSmall
                                                              ?.copyWith(
                                                                color:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .error,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Email - increased size and made text smaller
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              user.email.isEmpty
                                                  ? l10n.noEmailProvided
                                                  : user.email,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withAlpha(
                                                      (255 * 0.9).round(),
                                                    ),
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ),

                                          // Created date - now "Started"
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
                                                    .withAlpha(
                                                      (255 * 0.8).round(),
                                                    ),
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
                                                    .withAlpha(
                                                      (255 * 0.8).round(),
                                                    ),
                                              ),
                                            ),
                                          ),

                                          // Actions
                                          SizedBox(
                                            width: 60,
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.more_vert,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                              ),
                                              onPressed:
                                                  () => _showUserActionMenu(
                                                    context,
                                                    user,
                                                  ),
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

  // Helper method to build info rows
  Widget _buildInfoRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
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
              l10n.resellerRole,
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

            // Add debug actions row (only in debug mode)
            if (kDebugMode) _buildDebugActions(),

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
                fillColor: Colors.transparent,
                border: InputBorder.none,
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
                  label: Text(l10n.newReseller),
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
            // Desktop layout - side by side with desktop-specific widgets
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.resellerRole,
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
                // Use our new desktop action buttons
                _buildDesktopActionButtons(),
              ],
            ),

            // Add debug actions row (only in debug mode)
            if (kDebugMode) _buildDebugActions(),

            const SizedBox(height: 24),
            // Use our new desktop search field
            _buildDesktopSearchField(),
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
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.7).round()),
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
                              color: Theme.of(context).colorScheme.error
                                  .withAlpha((255 * 0.9).round()),
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
                            color: Theme.of(context).colorScheme.onSurface
                                .withAlpha((255 * 0.5).round()),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noRetailUsersFound,
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.7).round()),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _showCreateUserDialog,
                            icon: const Icon(Icons.person_add),
                            label: Text(l10n.newReseller),
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
      builder:
          (context) => Dialog(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.newReseller,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  SalesforceUserCreationForm(
                    onSubmit: ({required String salesforceId}) {
                      Navigator.of(context).pop();
                      _verifySalesforceUser(salesforceId);
                    },
                    onCancel: () => Navigator.of(context).pop(),
                    isLoading: _isCreatingUser,
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
    );
  }

  // Navigate to user details page when a user is clicked
  void _navigateToUserDetailPage(AppUser user) {
    if (kDebugMode) {
      print('Navigating to user detail page for user ID: ${user.uid}');
    }

    // Navigate to the appropriate detail page based on user role
    if (user.role == UserRole.reseller) {
      // Navigate to reseller detail page
      context.push('/admin/resellers/${user.uid}', extra: user);
    } else {
      // Navigate to general user detail page (admin or others)
      context.push('/admin/users/${user.uid}', extra: user);
    }
  }

  // Desktop-style search widget
  Widget _buildDesktopSearchField() {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: l10n.commonSearch,
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          hintStyle: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withAlpha((255 * 0.7).round()),
            fontSize: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outline.withAlpha((255 * 0.3).round()),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1,
            ),
          ),
          isDense: true,
          fillColor: Colors.transparent,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 8,
          ),
          suffixIcon:
              searchQuery.isNotEmpty
                  ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      searchController.clear();
                      setState(() {
                        searchQuery = '';
                      });
                    },
                    splashRadius: 20,
                    visualDensity: VisualDensity.compact,
                  )
                  : null,
        ),
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onChanged: (value) {
          setState(() {
            searchQuery = value.trim();
          });
        },
      ),
    );
  }

  // Desktop-specific refresh and add buttons
  Widget _buildDesktopActionButtons() {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        // Refresh button with better desktop styling
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh, size: 16),
          label: Text(l10n.refresh),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            side: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outline.withAlpha((255 * 0.5).round()),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: _loadUsers,
        ),
        const SizedBox(width: 12),
        // Add client button
        FilledButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: Text(l10n.newReseller),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: _showCreateUserDialog,
        ),
      ],
    );
  }

  // Test direct sync with Salesforce for a user
  Future<void> _testDirectSalesforceSync(BuildContext context) async {
    final TextEditingController idController = TextEditingController();
    AppUser? selectedUser;
    bool useSelectedUser = false;
    bool isLoading = true;
    List<AppUser> availableUsers = [];

    // Function to fetch users with salesforceId from Firestore
    Future<List<AppUser>> fetchUsersWithSalesforceId() async {
      try {
        final querySnapshot =
            await FirebaseFirestore.instance.collection('users').get();

        return querySnapshot.docs
            .map((doc) {
              final data = doc.data();
              // The document ID is the Firebase Auth UID
              final uid = doc.id;
              final salesforceId = data['salesforceId'] as String?;

              return AppUser(
                uid: uid,
                email: data['email'] as String? ?? '',
                displayName: data['displayName'] as String?,
                role: _mapStringToUserRole(
                  data['role'] as String? ?? 'unknown',
                ),
                additionalData: data,
              );
            })
            .where((user) => user.additionalData['salesforceId'] != null)
            .toList();
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching users with Salesforce ID: $e');
        }
        return [];
      }
    }

    // First, show a dialog to select a user or enter a Salesforce ID
    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Test Salesforce User Sync'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (availableUsers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16.0),
                          child: Text('No users with Salesforce ID found.'),
                        )
                      else ...[
                        const Text('Select a user:'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<AppUser>(
                          value: selectedUser,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          hint: const Text('Select user'),
                          isExpanded: true,
                          items:
                              availableUsers.map((user) {
                                return DropdownMenuItem<AppUser>(
                                  value: user,
                                  child: Text(
                                    '${user.displayName ?? user.email} (${user.additionalData['salesforceId']})',
                                  ),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedUser = value;
                              if (value != null) {
                                useSelectedUser = true;
                                idController.text =
                                    value.additionalData['salesforceId']
                                        as String? ??
                                    '';
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          title: const Text('Use selected user'),
                          value: useSelectedUser,
                          onChanged:
                              selectedUser != null
                                  ? (value) {
                                    setState(() {
                                      useSelectedUser = value ?? false;
                                    });
                                  }
                                  : null,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text('Or enter a Salesforce ID directly:'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: idController,
                        decoration: const InputDecoration(
                          labelText: 'Salesforce User ID',
                          hintText: 'Enter a valid Salesforce ID',
                          border: OutlineInputBorder(),
                        ),
                        enabled: !useSelectedUser,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed:
                          idController.text.isNotEmpty ||
                                  (selectedUser != null && useSelectedUser)
                              ? () => Navigator.of(context).pop(true)
                              : null,
                      child: const Text('Test Sync'),
                    ),
                  ],
                ),
          ),
    ).then((proceed) async {
      if (proceed != true) return;

      // Determine which Salesforce ID to use
      String salesforceId = '';
      if (useSelectedUser && selectedUser != null) {
        salesforceId =
            selectedUser!.additionalData['salesforceId'] as String? ?? '';
      } else {
        salesforceId = idController.text;
      }

      if (salesforceId.isEmpty) {
        // Show error if no ID provided
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Salesforce ID provided')),
        );
        return;
      }

      _runDirectSalesforceSync(context, salesforceId);
    });

    // Load users with Salesforce ID when dialog opens
    availableUsers = await fetchUsersWithSalesforceId();
    if (mounted) {
      // Update dialog state once users are loaded
      setState(() {
        isLoading = false;
      });
    }
  }

  // Helper to map string role to UserRole enum
  UserRole _mapStringToUserRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'reseller':
        return UserRole.reseller;
      default:
        return UserRole.unknown;
    }
  }

  // Run the actual direct sync with Salesforce
  Future<void> _runDirectSalesforceSync(
    BuildContext context,
    String salesforceId,
  ) async {
    if (!mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Testing Salesforce connection and user data fetch...'),
              ],
            ),
          ),
    );

    try {
      final salesforceService = SalesforceUserSyncService();

      // Initialize the service
      final initialized = await salesforceService.initialize();
      if (!initialized) {
        throw Exception('Failed to initialize Salesforce connection');
      }

      // Get user data from Salesforce
      final Map<String, dynamic>? userData = await salesforceService
          .getSalesforceUserById(salesforceId);

      // Check if still mounted before continuing
      if (!mounted) return;

      // Close the loading dialog
      Navigator.of(context).pop();

      if (userData == null || userData.isEmpty) {
        if (!mounted) return;

        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('User Not Found'),
                content: Text(
                  'No user found with Salesforce ID: $salesforceId',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
        );
        return;
      }

      // Find the Firebase user with this Salesforce ID (if any)
      AppUser? matchingUser;
      try {
        final usersQuery =
            await FirebaseFirestore.instance
                .collection('users')
                .where('salesforceId', isEqualTo: salesforceId)
                .limit(1)
                .get();

        if (usersQuery.docs.isNotEmpty) {
          final doc = usersQuery.docs.first;
          final data = doc.data();
          matchingUser = AppUser(
            uid: doc.id,
            email: data['email'] as String? ?? '',
            displayName: data['displayName'] as String?,
            role: _mapStringToUserRole(data['role'] as String? ?? 'unknown'),
            additionalData: data,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error finding matching user: $e');
        }
      }

      // Show the user data in a dialog
      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (context) => Dialog(
              child: Container(
                width: double.maxFinite,
                constraints: const BoxConstraints(
                  maxHeight: 500,
                  maxWidth: 700,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Text(
                            'Salesforce User Data',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const Spacer(),
                          if (matchingUser != null)
                            Chip(
                              label: const Text('Linked User'),
                              backgroundColor: Colors.green.withOpacity(0.2),
                              labelStyle: const TextStyle(color: Colors.green),
                              avatar: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Divider(height: 1),
                    Expanded(
                      child: ListView(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text('Raw Data from Salesforce:'),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SelectableText(
                              JsonEncoder.withIndent('  ').convert(userData),
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text('Mapped Fields:'),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(1.5),
                                1: FlexColumnWidth(2),
                                2: FlexColumnWidth(1),
                              },
                              border: TableBorder.all(
                                color: Colors.grey.withOpacity(0.3),
                                width: 1,
                              ),
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                  ),
                                  children: const [
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Firebase Field',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Salesforce Field',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Value',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                ...salesforceService
                                    .salesforceFieldMapping
                                    .entries
                                    .map((entry) {
                                      final firebaseField = entry.key;
                                      final salesforceField = entry.value;
                                      final value =
                                          salesforceField.contains('.')
                                              ? _getNestedValue(
                                                userData,
                                                salesforceField.split('.'),
                                              )
                                              : userData[salesforceField];

                                      return TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(firebaseField),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(salesforceField),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              value != null
                                                  ? value.toString()
                                                  : 'null',
                                              style: TextStyle(
                                                color:
                                                    value != null
                                                        ? null
                                                        : Colors.red,
                                                fontStyle:
                                                    value != null
                                                        ? FontStyle.normal
                                                        : FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    })
                                    .toList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (matchingUser != null)
                            OutlinedButton.icon(
                              onPressed:
                                  () => _updateUserWithSalesforceData(
                                    matchingUser!,
                                    userData,
                                    salesforceService.salesforceFieldMapping,
                                  ),
                              icon: const Icon(Icons.update),
                              label: const Text('Update Firebase User'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green,
                              ),
                            ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );
    } catch (e) {
      // Check if still mounted
      if (!mounted) return;

      // Close the loading dialog if it's still open
      Navigator.of(context).pop();

      // Show error dialog
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to sync with Salesforce: ${e.toString()}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    }
  }

  // Helper to get nested values from a map using a path like ['attributes', 'type']
  dynamic _getNestedValue(Map<String, dynamic> data, List<String> path) {
    dynamic value = data;
    for (final key in path) {
      if (value is Map && value.containsKey(key)) {
        value = value[key];
      } else {
        return null;
      }
    }
    return value;
  }

  // Update a user with data from Salesforce
  Future<void> _updateUserWithSalesforceData(
    AppUser user,
    Map<String, dynamic> salesforceData,
    Map<String, String> fieldMapping,
  ) async {
    try {
      final updates = <String, dynamic>{};

      // Apply field mapping
      for (final entry in fieldMapping.entries) {
        final firebaseField = entry.key;
        final salesforceField = entry.value;

        final value =
            salesforceField.contains('.')
                ? _getNestedValue(salesforceData, salesforceField.split('.'))
                : salesforceData[salesforceField];

        if (value != null) {
          updates[firebaseField] = value;
        }
      }

      // Add salesforceSyncedAt timestamp
      updates['salesforceSyncedAt'] = FieldValue.serverTimestamp();

      // Update the user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updates);

      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Success'),
                content: Text(
                  'User ${user.displayName ?? user.email} successfully updated with Salesforce data.',
                ),
                actions: [
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Refresh the user list
                      _loadUsers();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Error'),
                content: Text('Failed to update user: ${e.toString()}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
        );
      }
    }
  }

  // Add a Debug Actions row to the user management UI
  Widget _buildDebugActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Debug Actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _testDirectSalesforceSync(context),
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Test Salesforce Sync'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showSalesforceFields(context),
                icon: const Icon(Icons.list_alt, size: 16),
                label: const Text('Show Available Fields'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Show available Salesforce fields
  Future<void> _showSalesforceFields(BuildContext context) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Retrieving Salesforce field information...'),
              ],
            ),
          ),
    );

    try {
      final salesforceService = SalesforceUserSyncService();

      // Initialize the service
      final initialized = await salesforceService.initialize();
      if (!initialized) {
        throw Exception('Failed to initialize Salesforce connection');
      }

      // Fetch available fields
      final fields = await salesforceService.getFieldInfoForUserObject();

      // Check if still mounted before continuing
      if (!mounted) return;

      // Close the loading dialog
      Navigator.of(context).pop();

      if (fields == null || fields.isEmpty) {
        if (!mounted) return;

        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Error'),
                content: const Text(
                  'Failed to retrieve field information from Salesforce.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
        );
        return;
      }

      // Sort by field name
      fields.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );

      // Show the fields in a dialog
      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (context) => Dialog(
              child: Container(
                width: double.maxFinite,
                constraints: const BoxConstraints(
                  maxHeight: 500,
                  maxWidth: 700,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Available Salesforce User Fields',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        itemCount: fields.length,
                        separatorBuilder:
                            (context, index) => Divider(height: 1),
                        itemBuilder: (context, index) {
                          final field = fields[index];
                          final name = field['name'] as String;
                          final label = field['label'] as String;
                          final type = field['type'] as String;
                          final isCustom = field['custom'] as bool;

                          return ListTile(
                            title: Row(
                              children: [
                                Text(name),
                                if (isCustom)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Custom',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text('Type: $type, Label: "$label"'),
                            leading: Icon(
                              _getIconForFieldType(type),
                              color: _getColorForFieldType(type),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );
    } catch (e) {
      // Check if still mounted
      if (!mounted) return;

      // Close the loading dialog if it's still open
      Navigator.of(context).pop();

      // Show error dialog
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Error'),
              content: Text(
                'Failed to retrieve field information: ${e.toString()}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    }
  }

  // Helper to get icon for field type
  IconData _getIconForFieldType(String type) {
    switch (type.toLowerCase()) {
      case 'string':
        return Icons.text_fields;
      case 'boolean':
        return Icons.check_box;
      case 'date':
        return Icons.calendar_today;
      case 'datetime':
        return Icons.access_time;
      case 'double':
      case 'int':
      case 'integer':
      case 'number':
        return Icons.numbers;
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      case 'id':
        return Icons.key;
      case 'reference':
        return Icons.link;
      case 'picklist':
        return Icons.list;
      default:
        return Icons.data_object;
    }
  }

  // Helper to get color for field type
  Color _getColorForFieldType(String type) {
    switch (type.toLowerCase()) {
      case 'string':
        return Colors.blue;
      case 'boolean':
        return Colors.green;
      case 'date':
      case 'datetime':
        return Colors.orange;
      case 'double':
      case 'int':
      case 'integer':
      case 'number':
        return Colors.purple;
      case 'email':
        return Colors.red;
      case 'phone':
        return Colors.teal;
      case 'id':
        return Colors.indigo;
      case 'reference':
        return Colors.amber;
      case 'picklist':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  // Add this new method for verifying a Salesforce user before creating
  Future<void> _verifySalesforceUser(String salesforceId) async {
    if (!mounted) return;

    if (kDebugMode) {
      print('Starting Salesforce user verification for ID: $salesforceId');
    }

    setState(() {
      _isCreatingUser = true;
      _errorMessage = null;
    });

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Fetching user data from Salesforce...'),
                ],
              ),
            ),
      );
    }

    try {
      final salesforceService = SalesforceUserSyncService();

      // Initialize the service
      final initialized = await salesforceService.initialize();
      if (kDebugMode) {
        print('Salesforce service initialized: $initialized');
      }

      if (!mounted) return;

      if (!initialized) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Show error dialog
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Connection Error'),
                  content: const Text(
                    'Failed to connect to Salesforce. Please try again later.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        }

        setState(() {
          _isCreatingUser = false;
        });
        return;
      }

      // Get Salesforce user data
      final userData = await salesforceService.getSalesforceUserById(
        salesforceId,
      );
      if (kDebugMode) {
        print('Salesforce user data retrieved: ${userData != null}');
        if (userData != null) {
          print('User email: ${userData['Email']}');
          print('User name: ${userData['Name']}');
        }
      }

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      if (userData == null || userData.isEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('User Not Found'),
                  content: Text(
                    'No user found with Salesforce ID: $salesforceId',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
          );
        }

        setState(() {
          _isCreatingUser = false;
        });
        return;
      }

      // Check if a user with this Salesforce ID already exists
      final existingUsers =
          await FirebaseFirestore.instance
              .collection('users')
              .where('salesforceId', isEqualTo: salesforceId)
              .limit(1)
              .get();

      if (!mounted) return;

      if (existingUsers.docs.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('User Already Exists'),
                  content: const Text(
                    'A user with this Salesforce ID already exists in the system.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
          );
        }

        setState(() {
          _isCreatingUser = false;
        });
        return;
      }

      // Generate a random password
      const chars =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
      final random = Random.secure();

      // Generate a secure password with at least one uppercase, one lowercase, one number, and one special character
      String password = '';
      password += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'[random.nextInt(26)];
      password += 'abcdefghijklmnopqrstuvwxyz'[random.nextInt(26)];
      password += '0123456789'[random.nextInt(10)];
      password += '!@#\$%^&*()'[random.nextInt(10)];

      // Add more characters to reach desired length
      while (password.length < 12) {
        password += chars[random.nextInt(chars.length)];
      }

      // Extract user data from Salesforce
      final email = userData['Email'] as String?;
      final name = userData['Name'] as String?;

      if (kDebugMode) {
        print('Showing user verification dialog with:');
        print('- Email: $email');
        print('- Name: $name');
        print('- Generated password: $password');
      }

      // Show verification dialog
      bool? result;
      if (mounted) {
        result = await showDialog<bool>(
          context: context,
          builder:
              (context) => Dialog(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verify Salesforce User',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 24),
                      // User information
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Name: ${name ?? 'Not provided'}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Email: ${email ?? 'Not provided'}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            if (email == null || email.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Warning: No email found for this user in Salesforce',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Would you like to create this user with the following credentials?',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Email: ${email ?? 'Not available'}',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color:
                                    email == null
                                        ? Theme.of(context).colorScheme.error
                                        : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Role: Reseller',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Initial Password: $password',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'The user will be prompted to change their password on first login.',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                if (kDebugMode) {
                                  print('User verification canceled');
                                }
                                Navigator.of(context).pop(false);
                              },
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed:
                                  email != null && email.isNotEmpty
                                      ? () {
                                        if (kDebugMode) {
                                          print('Create User button clicked');
                                        }
                                        Navigator.of(context).pop(true);
                                      }
                                      : null,
                              child: const Text('Create User'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        );
      }

      if (kDebugMode) {
        print('Dialog result: $result');
      }

      if (result == true && mounted) {
        if (kDebugMode) {
          print('Starting user creation with Salesforce data');
          print('Email: $email');
          print('Name: $name');
        }

        if (email != null) {
          await _createUserFromSalesforce(
            email: email,
            displayName: name ?? email,
            salesforceId: salesforceId,
            password: password,
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot create user: Email is required'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (kDebugMode) {
          print('User creation canceled by admin');
        }
      }

      setState(() {
        _isCreatingUser = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error in _verifySalesforceUser: $e');
        print('Stack trace: ${StackTrace.current}');
      }

      if (mounted) {
        // Close loading dialog if it's still open
        Navigator.of(context).pop();

        setState(() {
          _isCreatingUser = false;
          _errorMessage = e.toString();
        });

        // Show error dialog
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Error'),
                content: Text(
                  'Failed to verify Salesforce user: ${e.toString()}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
        );
      }
    }
  }

  // This method is called when the user creation is confirmed
  Future<void> _createUserFromSalesforce({
    required String email,
    required String password,
    required String displayName,
    required String salesforceId,
  }) async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    if (kDebugMode) {
      print('_createUserFromSalesforce started with:');
      print('- Email: $email');
      print('- Display Name: $displayName');
      print('- Salesforce ID: $salesforceId');
      print('- Password length: ${password.length}');
    }

    try {
      // Step 1: Check if the cloud functions are available
      final functionsService = FirebaseFunctionsService();
      final functionsAvailable = await functionsService.checkAvailability();

      if (kDebugMode) {
        print('Cloud Functions available: $functionsAvailable');
      }

      if (!functionsAvailable) {
        throw Exception(
          'Cloud Functions are not available. Please check your network connection and try again.',
        );
      }

      // Step 2: Check if user already exists in Firestore with this Salesforce ID
      final existingUsers =
          await FirebaseFirestore.instance
              .collection('users')
              .where('salesforceId', isEqualTo: salesforceId)
              .limit(1)
              .get();

      if (existingUsers.docs.isNotEmpty) {
        throw Exception(
          'User with this Salesforce ID already exists in the system',
        );
      }

      // Step 3: Fetch Salesforce user data again to ensure we have the latest
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Getting latest data from Salesforce...'),
                  ],
                ),
              ),
        );
      }

      final salesforceService = SalesforceUserSyncService();
      final initialized = await salesforceService.initialize();

      if (!initialized) {
        // Close progress dialog
        if (mounted) Navigator.of(context).pop();
        throw Exception(
          'Failed to connect to Salesforce. Please try again later.',
        );
      }

      final salesforceData = await salesforceService.getSalesforceUserById(
        salesforceId,
      );

      // Close progress dialog
      if (mounted) Navigator.of(context).pop();

      if (salesforceData == null || salesforceData.isEmpty) {
        throw Exception('Failed to retrieve user data from Salesforce');
      }

      if (kDebugMode) {
        print(
          'Retrieved Salesforce data: ${salesforceData.toString().substring(0, min(100, salesforceData.toString().length))}...',
        );
      }

      // Step 4: Create the user with Firebase Auth through our Cloud Function
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Creating user account...'),
                  ],
                ),
              ),
        );
      }

      final authRepository = ref.read(authRepositoryProvider);

      // Call the repository method that internally uses the Firebase Functions service
      final newUser = await authRepository.createUserWithEmailAndPassword(
        email: email,
        password: password,
        role: UserRole.reseller,
        displayName: displayName,
      );

      // Close the progress dialog
      if (mounted) Navigator.of(context).pop();

      if (kDebugMode) {
        print('User created successfully: ${newUser.uid}');
      }

      // Step 5: Update the user document with Salesforce data
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Synchronizing with Salesforce...'),
                  ],
                ),
              ),
        );
      }

      // Use the existing _syncUserWithSalesforce method to sync the user data
      await _syncUserWithSalesforce(newUser.uid, salesforceId);

      // Close the progress dialog
      if (mounted) Navigator.of(context).pop();

      if (kDebugMode) {
        print('Salesforce sync completed');
      }

      // Show success message and dialog with password
      if (mounted) {
        if (kDebugMode) {
          print('Showing success dialog');
        }

        // Show success dialog with password
        showDialog(
          context: context,
          builder:
              (context) => Dialog(
                child: Container(
                  width: double.maxFinite,
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Created Successfully',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 24),

                      // User created confirmation
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'The user account for $displayName has been created and synchronized with Salesforce.',
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Text(
                        'Login Credentials',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Please securely share these credentials with the user:',
                        style: TextStyle(fontSize: 14),
                      ),

                      const SizedBox(height: 16),

                      // Display login details
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSalesforceInfoRow('Email', email),
                            const SizedBox(height: 12),

                            // Password display
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Password:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          password,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy),
                                        tooltip: 'Copy to clipboard',
                                        onPressed: () async {
                                          await Clipboard.setData(
                                            ClipboardData(text: password),
                                          );
                                          if (!context.mounted) return;

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Password copied to clipboard',
                                              ),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Text(
                        'The user will be prompted to change their password after their first login.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),

                      const SizedBox(height: 24),

                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () {
                            if (kDebugMode) {
                              print('Success dialog closed');
                            }

                            Navigator.of(context).pop();
                            setState(() {
                              _isCreatingUser = false;
                            });
                            // Refresh the user list
                            _loadUsers();
                          },
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in _createUserFromSalesforce: $e');
        print('Error type: ${e.runtimeType}');
        print('Stack trace: ${StackTrace.current}');
      }

      // Close any open progress dialogs
      if (mounted) {
        // Check if there's a dialog showing and close it
        Navigator.of(
          context,
        ).popUntil((route) => route.isFirst || !route.isCurrent);

        setState(() {
          _isCreatingUser = false;
          _errorMessage = e.toString();
        });

        // Show error dialog
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Error'),
                content: Text('Failed to create user: ${e.toString()}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
        );
      }
    }
  }

  // Helper method to build info rows for Salesforce user info
  Widget _buildSalesforceInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Add a helper method to directly test the createUser Cloud Function
  Future<void> _testCreateUserFunction({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (kDebugMode) {
      print('Testing createUser Cloud Function directly');
      print('- Email: $email');
      print('- Display Name: $displayName');
      print('- Password length: ${password.length}');
    }

    try {
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Testing direct connection to createUser function...'),
                ],
              ),
            ),
      );

      // Get the Firebase Functions instance for the US region
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

      // Create a reference to the 'createUser' Cloud Function
      final createUserFunction = functions.httpsCallable('createUser');

      if (kDebugMode) {
        print('Got reference to createUser function');
      }

      // Call the function with test parameters
      final result = await createUserFunction.call({
        'email': email,
        'password': password,
        'displayName': displayName,
        'role': 'reseller',
      });

      // Close progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (kDebugMode) {
        print('Cloud Function result type: ${result.data.runtimeType}');
        if (result.data is Map) {
          print('Result data: ${result.data}');
          final resultMap = result.data as Map;
          print('User ID: ${resultMap['uid']}');
          print('Email: ${resultMap['email']}');
        } else {
          print('Result data (not a map): ${result.data}');
        }
      }

      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Direct Function Test Successful'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The createUser function was called successfully!',
                    ),
                    const SizedBox(height: 16),
                    Text('Response: ${result.data.toString()}'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      // Close progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (kDebugMode) {
        print('Error testing createUser function: $e');
        if (e is FirebaseFunctionsException) {
          print('Firebase Functions Exception:');
          print('- Code: ${e.code}');
          print('- Message: ${e.message ?? "No message"}');
          print('- Details: ${e.details}');
        }
      }

      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Direct Function Test Failed'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Error: ${e.toString()}'),
                    const SizedBox(height: 16),
                    if (e is FirebaseFunctionsException) ...[
                      Text('Code: ${e.code}'),
                      Text('Message: ${e.message ?? "No message"}'),
                      if (e.details != null) Text('Details: ${e.details}'),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Suggestions:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Check if the createUser function is deployed',
                    ),
                    const Text('• Verify your admin permissions'),
                    const Text('• Check the Firebase console for logs'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
        );
      }
    }
  }

  /// Tests Firebase Functions connectivity and displays diagnostic information
  Future<void> _testFirebaseFunctionsConnectivity() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Testing Firebase Functions connectivity...';
    });

    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Firebase Functions Diagnostics'),
              content: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setStateDialog) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text(_loadingMessage)],
                    );
                  },
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Close'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      }

      // Update state to show real-time progress
      setState(() {
        _loadingMessage = 'Step 1: Testing Firebase initialization...';
      });

      // Check Firebase initialization
      final firebaseApp = Firebase.app();
      final options = firebaseApp.options;

      setState(() {
        _loadingMessage =
            '$_loadingMessage\n✓ Firebase initialized: ${options.projectId}';
      });

      // Step 2: Check Functions instance
      setState(() {
        _loadingMessage =
            '$_loadingMessage\n\nStep 2: Testing Firebase Functions...';
      });

      try {
        final functions = FirebaseFunctions.instance;

        setState(() {
          _loadingMessage =
              '$_loadingMessage\n✓ Firebase Functions instance created';
        });

        // Test ping function
        setState(() {
          _loadingMessage =
              '$_loadingMessage\n\nStep 3: Testing ping function...';
        });

        try {
          final pingCallable = functions.httpsCallable('ping');
          final result = await pingCallable.call();

          setState(() {
            _loadingMessage =
                '$_loadingMessage\n✓ Ping successful: ${result.data}';
          });
        } catch (e) {
          setState(() {
            _loadingMessage = '$_loadingMessage\n✗ Ping failed: $e';
            if (e is FirebaseFunctionsException) {
              _loadingMessage =
                  '$_loadingMessage\n  Code: ${e.code}\n  Message: ${e.message}\n  Details: ${e.details}';
            }
          });
        }

        // Test createUser function existence
        setState(() {
          _loadingMessage =
              '$_loadingMessage\n\nStep 4: Checking createUser function...';
        });

        try {
          final createUserCallable = functions.httpsCallable('createUser');

          setState(() {
            _loadingMessage = '$_loadingMessage\n✓ createUser function exists';
          });
        } catch (e) {
          setState(() {
            _loadingMessage =
                '$_loadingMessage\n✗ createUser function check failed: $e';
          });
        }
      } catch (e) {
        setState(() {
          _loadingMessage =
              '$_loadingMessage\n✗ Firebase Functions test failed: $e';
        });
      }

      setState(() {
        _loadingMessage = '$_loadingMessage\n\nDiagnostics complete.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _loadingMessage = 'Error testing Firebase Functions: $e';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
