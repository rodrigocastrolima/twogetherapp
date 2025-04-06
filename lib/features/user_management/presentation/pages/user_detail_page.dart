import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../features/auth/domain/models/app_user.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

class UserDetailPage extends ConsumerWidget {
  final AppUser user;

  const UserDetailPage({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final bool isEnabled = user.additionalData?['isEnabled'] ?? true;

    // Get screen size to determine layout
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 700;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminUserManagement),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Implement edit functionality
              if (kDebugMode) {
                print('Edit user: ${user.uid}');
              }
            },
            tooltip: l10n.commonEdit,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User header with avatar and name
              Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            user.role == UserRole.admin
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.primary,
                        radius: 48,
                        child: Text(
                          user.displayName?.isNotEmpty == true
                              ? user.displayName![0].toUpperCase()
                              : user.email.isNotEmpty
                              ? user.email[0].toUpperCase()
                              : l10n.userInitialsDefault,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.displayName ?? l10n.unknownUser,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (user.role == UserRole.admin
                                      ? Theme.of(context).colorScheme.secondary
                                      : Theme.of(context).colorScheme.primary)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              user.role == UserRole.admin
                                  ? 'Admin'
                                  : 'Reseller',
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(
                                color:
                                    user.role == UserRole.admin
                                        ? Theme.of(
                                          context,
                                        ).colorScheme.secondary
                                        : Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!isEnabled) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.error.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                l10n.inactive,
                                style: Theme.of(
                                  context,
                                ).textTheme.labelLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
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
              ),

              const SizedBox(height: 24),

              // User information
              Text(
                l10n.profilePersonalInfo,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildInfoItem(
                        context,
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: user.email,
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.phone_outlined,
                        label: l10n.loginUsername,
                        value: user.additionalData?['phoneNumber'] ?? 'N/A',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.calendar_today,
                        label: l10n.commonDate,
                        value: _formatDate(user.additionalData?['createdAt']),
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.login,
                        label: 'Last Login',
                        value: _formatDate(user.additionalData?['lastLoginAt']),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Actions
              Text(
                l10n.clientsFilterAction,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.password,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        l10n.profileChangePassword,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // TODO: Implement password reset functionality
                        if (kDebugMode) {
                          print('Reset password for user: ${user.uid}');
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        isEnabled ? Icons.block : Icons.check_circle,
                        color:
                            isEnabled
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.secondary,
                      ),
                      title: Text(
                        isEnabled ? l10n.inactive : l10n.active,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // TODO: Implement toggle user status functionality
                        if (kDebugMode) {
                          print('Toggle status for user: ${user.uid}');
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.delete,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        l10n.commonDelete,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // TODO: Implement delete user functionality
                        if (kDebugMode) {
                          print('Delete user: ${user.uid}');
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Back button
              Center(
                child: FilledButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: Text(l10n.servicesBackButton),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => context.pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime date;
    if (timestamp is DateTime) {
      date = timestamp;
    } else if (timestamp is Map && timestamp['seconds'] != null) {
      // Handle Firestore Timestamp
      date = DateTime.fromMillisecondsSinceEpoch(
        (timestamp['seconds'] * 1000) + (timestamp['nanoseconds'] ~/ 1000000),
      );
    } else {
      return 'N/A';
    }

    return DateFormat('MMM dd, yyyy - HH:mm').format(date);
  }
}
