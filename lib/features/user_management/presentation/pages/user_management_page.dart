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
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../providers/user_creation_provider.dart';

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
  List<AppUser> _users = [];
  String? _errorMessage;
  late final String _currentUserId;
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  AppUser? _selectedUser;
  String _loadingMessage = '';
  bool _isDialogShowing = false; // Flag to prevent duplicate dialogs

  // State for inline form
  bool _isCreatingUserMode = false;
  final _createUserFormKey = GlobalKey<FormState>();
  final _salesforceIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadUsers();
  }

  @override
  void dispose() {
    _salesforceIdController.dispose(); // Dispose controller
    searchController.dispose();
    super.dispose();
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
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 700;
    final l10n = AppLocalizations.of(context)!;
    final userCreationState = ref.watch(userCreationProvider);

    // Listener with revised logic
    ref.listen<UserCreationState>(userCreationProvider, (previous, next) {
      // Log the state details for debugging
      if (kDebugMode) {
        print("[UserManagementPage Listener] State change detected.");
        print("  Previous State: ${previous?.toString()}");
        print("  Next State    : ${next.toString()}");
        print("  _isDialogShowing (before checks): $_isDialogShowing");
        print(
          "  VERIFY_CHECK: next.showVerificationDialog (${next.showVerificationDialog}) && !_isDialogShowing (${!_isDialogShowing})",
        );
        print(
          "  SUCCESS_CHECK: next.showSuccessDialog (${next.showSuccessDialog}) && !_isDialogShowing (${!_isDialogShowing})",
        );
        print(
          "  ERROR_CHECK: next.showErrorDialog (${next.showErrorDialog}) && !_isDialogShowing (${!_isDialogShowing})",
        );
      }

      // Use addPostFrameCallback for dialogs
      // Check if verification dialog should be shown
      if (next.showVerificationDialog && !_isDialogShowing) {
        print(
          "[UserManagementPage Listener] CONDITION MET for showVerificationDialog.",
        );
        if (next.verificationData != null) {
          setState(() {
            _isDialogShowing = true; // Set flag before showing
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print(
                "[UserManagementPage Listener] Calling _showVerificationDialogFromState.",
              );
              _showVerificationDialogFromState(next.verificationData!).then((
                _,
              ) {
                // Reset flag when dialog is dismissed (or state changes)
                // Note: This might reset too early if another dialog should show immediately.
                // Consider resetting only when the corresponding state flag becomes false.
                // if (mounted && !ref.read(userCreationProvider).showVerificationDialog) {
                //   setState(() => _isDialogShowing = false);
                // }
              });
            } else {
              print(
                "[UserManagementPage Listener] Verification NOT shown - page not mounted. Resetting flag.",
              );
              if (mounted)
                setState(
                  () => _isDialogShowing = false,
                ); // Reset if showing failed
            }
          });
        } else {
          print(
            "[UserManagementPage Listener] Verification NOT shown - verificationData is null.",
          );
        }
      }
      // Check if success dialog should be shown
      else if (next.showSuccessDialog && !_isDialogShowing) {
        print(
          "[UserManagementPage Listener] CONDITION MET for showSuccessDialog.",
        );
        if (next.successData != null) {
          setState(() {
            _isDialogShowing = true; // Set flag before showing
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print(
                "[UserManagementPage Listener] Calling _showSuccessDialogFromState.",
              );
              _showSuccessDialogFromState(next.successData!).then((_) {
                // Reset flag when dialog is dismissed (or state changes)
                // if (mounted && !ref.read(userCreationProvider).showSuccessDialog) {
                //   setState(() => _isDialogShowing = false);
                // }
              });
            } else {
              print(
                "[UserManagementPage Listener] Success NOT shown - page not mounted. Resetting flag.",
              );
              if (mounted)
                setState(
                  () => _isDialogShowing = false,
                ); // Reset if showing failed
            }
          });
        } else {
          print(
            "[UserManagementPage Listener] Success NOT shown - successData is null.",
          );
        }
      }
      // Check if error dialog should be shown
      else if (next.showErrorDialog && !_isDialogShowing) {
        print(
          "[UserManagementPage Listener] CONDITION MET for showErrorDialog.",
        );
        if (next.errorMessage != null) {
          setState(() {
            _isDialogShowing = true; // Set flag before showing
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print(
                "[UserManagementPage Listener] Calling _showErrorDialogFromState.",
              );
              _showErrorDialogFromState(next.errorMessage!).then((_) {
                // Reset flag when dialog is dismissed (or state changes)
                // if (mounted && !ref.read(userCreationProvider).showErrorDialog) {
                //   setState(() => _isDialogShowing = false);
                // }
              });
            } else {
              print(
                "[UserManagementPage Listener] Error NOT shown - page not mounted. Resetting flag.",
              );
              if (mounted)
                setState(
                  () => _isDialogShowing = false,
                ); // Reset if showing failed
            }
          });
        } else {
          print(
            "[UserManagementPage Listener] Error NOT shown - errorMessage is null.",
          );
        }
      }

      // Reset the flag if no dialogs are supposed to be showing according to the state
      // This handles cases where the provider resets the flags (e.g., on new loading state)
      if (!next.showVerificationDialog &&
          !next.showSuccessDialog &&
          !next.showErrorDialog) {
        if (_isDialogShowing) {
          print(
            "[UserManagementPage Listener] Resetting _isDialogShowing flag as no dialogs are active in state.",
          );
          // Use WidgetsBinding to avoid calling setState during build/listen phase directly
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _isDialogShowing = false);
            }
          });
        }
      }
    });

    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header - Conditionally hide search/add when form is shown?
          if (!_isCreatingUserMode) _buildHeader(context, isSmallScreen, l10n),
          if (!_isCreatingUserMode) const SizedBox(height: 16),

          // Content Area
          Expanded(
            child:
                _isCreatingUserMode
                    ? _buildCreateUserForm(context, l10n, userCreationState)
                    : _buildUserListContent(context, l10n, userCreationState),
          ),
        ],
      ),
    );
  }

  // Extracted Header build method
  Widget _buildHeader(
    BuildContext context,
    bool isSmallScreen,
    AppLocalizations l10n,
  ) {
    return isSmallScreen
        ? Column(
          // Mobile header...
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.resellerRole,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
              onChanged: (value) => setState(() => searchQuery = value.trim()),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
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
                  onPressed: () => setState(() => _isCreatingUserMode = true),
                ),
              ],
            ),
          ],
        )
        : Row(
          // Desktop header...
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.resellerRole,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
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
            _buildDesktopActionButtons(), // Contains the "New Reseller" button
          ],
        );
  }

  // Extracted User List/Loading/Error build method
  Widget _buildUserListContent(
    BuildContext context,
    AppLocalizations l10n,
    UserCreationState userCreationState,
  ) {
    if (_isLoading) {
      return Center(
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
              ),
            ),
          ],
        ),
      );
    } else if (_errorMessage != null) {
      return Center(
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
            ),
          ],
        ),
      );
    } else if (_users.isEmpty) {
      return Center(
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
              ),
            ),
            // Optionally add the "New Reseller" button here too?
          ],
        ),
      );
    } else {
      return _buildUserTable(); // Assumes _buildUserTable is defined elsewhere
    }
  }

  // New method to build the inline creation form
  Widget _buildCreateUserForm(
    BuildContext context,
    AppLocalizations l10n,
    UserCreationState userCreationState,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
      child: Form(
        key: _createUserFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.newReseller,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the Salesforce User ID to fetch details and create a new reseller account.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _salesforceIdController,
              decoration: const InputDecoration(
                labelText: 'Salesforce User ID',
                hintText: 'Enter the 18-character Salesforce ID',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a Salesforce User ID';
                }
                if (value.trim().length != 18) {
                  return 'Salesforce ID must be 18 characters long';
                }
                return null;
              },
              enabled: !userCreationState.isLoading, // Disable when loading
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      userCreationState.isLoading
                          ? null
                          : () {
                            setState(() => _isCreatingUserMode = false);
                            _salesforceIdController.clear();
                            // Optionally reset provider state if needed
                          },
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon:
                      userCreationState.isLoading
                          ? Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.only(right: 8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                          : const Icon(Icons.cloud_sync, size: 16),
                  label: Text(
                    userCreationState.isLoading
                        ? (userCreationState.loadingMessage ??
                            l10n.commonLoading)
                        : 'Verify User',
                  ),
                  onPressed:
                      userCreationState.isLoading
                          ? null
                          : () {
                            if (_createUserFormKey.currentState?.validate() ==
                                true) {
                              ref
                                  .read(userCreationProvider.notifier)
                                  .verifySalesforceUser(
                                    _salesforceIdController.text.trim(),
                                  );
                            }
                          },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Dialog methods called by the listener (Keep these) ---
  Future<void> _showVerificationDialogFromState(
    Map<String, dynamic> data,
  ) async {
    final String? name = data['name'] as String?;
    final String? email = data['email'] as String?;
    final String password = data['password'] as String; // Should be present

    // Ensure context is still valid before showing dialog
    if (!mounted) return;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent accidental dismiss
      builder:
          (dialogContext) => Dialog(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verify Salesforce User',
                    style: Theme.of(dialogContext).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  // User info...
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(dialogContext)
                          .colorScheme
                          .surfaceContainerHighest
                          .withAlpha((255 * 0.5).round()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Name: ${name ?? 'Not provided'}'),
                        const SizedBox(height: 8),
                        Text('Email: ${email ?? 'Not provided'}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Create user with credentials?',
                    style: Theme.of(dialogContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  // Credentials...
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(dialogContext).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            Theme.of(dialogContext).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email: ${email ?? 'Not available'}'),
                        const SizedBox(height: 12),
                        const Text('Role: Reseller'),
                        const SizedBox(height: 12),
                        Text('Initial Password: $password'),
                        const SizedBox(height: 4),
                        const Text(
                          'User must change password on first login.',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed:
                              ref.read(userCreationProvider).isLoading
                                  ? null
                                  : () {
                                    // Reset the flag when canceling
                                    if (mounted)
                                      setState(() => _isDialogShowing = false);
                                    Navigator.of(dialogContext).pop();
                                  },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed:
                              ref.read(userCreationProvider).isLoading
                                  ? null
                                  : () {
                                    Navigator.of(dialogContext).pop();
                                    // Call provider to confirm and create user
                                    ref
                                        .read(userCreationProvider.notifier)
                                        .confirmAndCreateUser();
                                  },
                          child: Text(
                            ref.read(userCreationProvider).isLoading
                                ? 'Creating...'
                                : 'Create User',
                          ), // Update button text while loading
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

  Future<void> _showSuccessDialogFromState(Map<String, dynamic> data) async {
    final String displayName = data['displayName'] as String;
    final String email = data['email'] as String;
    final String password = data['password'] as String;

    // Ensure context is still valid
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => Dialog(
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
                    style: Theme.of(dialogContext).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha((255 * 0.1).round()),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withAlpha((255 * 0.3).round()),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Account for $displayName created and synced.',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Login Credentials',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Please securely share these credentials:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(dialogContext).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            Theme.of(dialogContext).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(
                                'Email:',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(child: Text(email)),
                          ],
                        ),
                        const SizedBox(height: 12),
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
                                color:
                                    Theme.of(
                                      dialogContext,
                                    ).colorScheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      Theme.of(
                                        dialogContext,
                                      ).colorScheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SelectableText(
                                      password,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 18),
                                    tooltip: 'Copy Password',
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: password),
                                      );
                                      if (!dialogContext.mounted) return;
                                      ScaffoldMessenger.of(
                                        dialogContext,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Password copied'),
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
                  Text(
                    'User must change password on first login.',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () {
                        // Reset the flag when closing
                        if (mounted) setState(() => _isDialogShowing = false);
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
    // Refresh user list after successful creation
    _loadUsers();
  }

  Future<void> _showErrorDialogFromState(String errorMessage) async {
    // Ensure context is still valid
    if (!mounted) return;

    await showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Error'), // Generic title for errors
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () {
                  // Reset the flag when closing
                  if (mounted) setState(() => _isDialogShowing = false);
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _navigateToUserDetailPage(AppUser user) {
    if (kDebugMode) {
      print('Navigating to user detail page for user ID: ${user.uid}');
    }

    // Navigate all users to the general user detail page, regardless of role
    context.push('/admin/users/${user.uid}', extra: user);
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
    // Watch loading state from the list loading, NOT creation loading
    final bool isListLoading = _isLoading;
    return Row(
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh, size: 16),
          label: Text(l10n.refresh),
          // Disable refresh if list is loading
          onPressed: isListLoading ? null : _loadUsers,
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: Text(l10n.newReseller),
          // Disable if list is loading, set mode on press
          onPressed:
              isListLoading
                  ? null
                  : () => setState(() => _isCreatingUserMode = true),
        ),
      ],
    );
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
}
