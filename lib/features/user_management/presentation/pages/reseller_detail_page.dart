import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../features/auth/domain/models/app_user.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

class ResellerDetailPage extends ConsumerWidget {
  final AppUser reseller;

  const ResellerDetailPage({Key? key, required this.reseller})
    : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final bool isEnabled = reseller.additionalData?['isEnabled'] ?? true;

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
                print('Edit reseller: ${reseller.uid}');
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
              // Reseller header with avatar and name
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        radius: 48,
                        child: Text(
                          reseller.displayName?.isNotEmpty == true
                              ? reseller.displayName![0].toUpperCase()
                              : reseller.email.isNotEmpty
                              ? reseller.email[0].toUpperCase()
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
                        reseller.displayName ?? l10n.unknownUser,
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
                              color: Theme.of(context).colorScheme.primary
                                  .withAlpha((255 * 0.2).round()),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Reseller',
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
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
                                color: Theme.of(context).colorScheme.error
                                    .withAlpha((255 * 0.2).round()),
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

              // Personal information
              Text(
                l10n.profilePersonalInfo,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
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
                        value: reseller.email,
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.phone_outlined,
                        label: l10n.loginUsername,
                        value: reseller.additionalData?['phoneNumber'] ?? 'N/A',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.calendar_today,
                        label: l10n.commonDate,
                        value: _formatDate(
                          reseller.additionalData?['createdAt'],
                        ),
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.login,
                        label: 'Last Login',
                        value: _formatDate(
                          reseller.additionalData?['lastLoginAt'],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Business information
              Text(
                'Business Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
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
                        icon: Icons.business,
                        label: 'Company Name',
                        value: reseller.additionalData?['companyName'] ?? 'N/A',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.location_on_outlined,
                        label: 'Company Address',
                        value:
                            reseller.additionalData?['companyAddress'] ?? 'N/A',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.numbers,
                        label: 'Tax ID',
                        value: reseller.additionalData?['taxId'] ?? 'N/A',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.assignment_ind_outlined,
                        label: 'Company Registration',
                        value:
                            reseller.additionalData?['companyRegistration'] ??
                            'N/A',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Performance metrics
              Text(
                'Performance Metrics',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
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
                        icon: Icons.groups_outlined,
                        label: 'Total Clients',
                        value:
                            reseller.additionalData?['totalClients']
                                ?.toString() ??
                            '0',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.check_circle_outline,
                        label: 'Successful Submissions',
                        value:
                            reseller.additionalData?['successfulSubmissions']
                                ?.toString() ??
                            '0',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.pending_actions_outlined,
                        label: 'Pending Submissions',
                        value:
                            reseller.additionalData?['pendingSubmissions']
                                ?.toString() ??
                            '0',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.paid_outlined,
                        label: 'Total Revenue',
                        value: _formatCurrency(
                          reseller.additionalData?['totalRevenue'],
                        ),
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
                  color: Theme.of(context).colorScheme.onSurface,
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
                          print('Reset password for reseller: ${reseller.uid}');
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
                        isEnabled ? 'Disable Account' : 'Enable Account',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // TODO: Implement account toggling functionality
                        if (kDebugMode) {
                          print(
                            'Toggle account status for reseller: ${reseller.uid}',
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.message_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        'View Messages',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // TODO: Navigate to reseller messages
                        if (kDebugMode) {
                          print('View messages for reseller: ${reseller.uid}');
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.people_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        'View Clients',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // TODO: Navigate to reseller clients
                        if (kDebugMode) {
                          print('View clients for reseller: ${reseller.uid}');
                        }
                      },
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

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24.0),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) {
      return 'N/A';
    }

    DateTime? date;
    if (timestamp is DateTime) {
      date = timestamp;
    } else if (timestamp is Map &&
        timestamp.containsKey('seconds') &&
        timestamp.containsKey('nanoseconds')) {
      // Handle Firestore Timestamp
      final seconds = timestamp['seconds'] as int;
      final nanoseconds = timestamp['nanoseconds'] as int;
      date = DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000 + (nanoseconds / 1000000).round(),
      );
    }

    if (date == null) {
      return 'N/A';
    }

    final formatter = DateFormat('MMM d, y h:mm a');
    return formatter.format(date);
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) {
      return '\$0.00';
    }

    double numericAmount;
    if (amount is int) {
      numericAmount = amount.toDouble();
    } else if (amount is double) {
      numericAmount = amount;
    } else if (amount is String) {
      numericAmount = double.tryParse(amount) ?? 0.0;
    } else {
      return '\$0.00';
    }

    final formatter = NumberFormat.currency(symbol: '\$');
    return formatter.format(numericAmount);
  }
}
