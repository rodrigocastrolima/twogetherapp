import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/theme/theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/ui_styles.dart';
import '../../../features/notifications/presentation/providers/notification_provider.dart';
import '../../../core/models/notification.dart';
import '../../../features/services/data/repositories/service_submission_repository.dart';

class AdminHomePage extends ConsumerStatefulWidget {
  const AdminHomePage({super.key});

  @override
  ConsumerState<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends ConsumerState<AdminHomePage> {
  @override
  void initState() {
    super.initState();

    // Set up callback to refresh notifications when a new one is created
    ServiceSubmissionRepository.onNotificationCreated = () {
      if (kDebugMode) {
        print('AdminHomePage: Notification creation callback triggered');
      }

      // Run this in the next frame to ensure it happens after build
      Future.microtask(() {
        if (mounted) {
          refreshAdminNotifications(ref);
        }
      });
    };
  }

  @override
  void dispose() {
    // Clean up callback
    ServiceSubmissionRepository.onNotificationCreated = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final dateFormatter = DateFormat.yMMMMd().format(now);
    final timeFormatter = DateFormat.jm().format(now);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section with date/time
            _buildWelcomeSection(context, dateFormatter, timeFormatter),

            const SizedBox(height: 24),

            // Quick stats section
            _buildQuickStatsSection(context, l10n),

            const SizedBox(height: 24),

            // Recent actions section
            _buildRecentActionsSection(context),

            const SizedBox(height: 24),

            // Submissions notification section
            _buildSubmissionsNotificationSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, String date, String time) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: AppStyles.glassCard(context),
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome text and date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to Admin Panel',
                  style: AppTextStyles.h2.copyWith(
                    color: AppTheme.foreground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  date,
                  style: AppTextStyles.body1.copyWith(
                    color: AppTheme.mutedForeground,
                  ),
                ),
                Text(
                  time,
                  style: AppTextStyles.body2.copyWith(
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),

          // Quick actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildQuickActionButton(
                context: context,
                icon: CupertinoIcons.person_add,
                label: l10n.navResellers,
                onTap: () => context.push('/admin/user-management'),
              ),
              const SizedBox(height: 8),
              _buildQuickActionButton(
                context: context,
                icon: CupertinoIcons.graph_square,
                label: l10n.navOpportunities,
                onTap: () => context.push('/admin/opportunities'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accentColor = Color(0xFFffbe45); // Tulip Tree color

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accentColor.withOpacity(0.5), width: 1),
            color: accentColor.withOpacity(0.1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatsSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Dashboard Statistics',
            style: AppTextStyles.h3.copyWith(color: AppTheme.foreground),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                CupertinoIcons.person_2_fill,
                '12', // Placeholder value
                'Active Resellers',
                Color(0xFF60A5FA), // Light blue
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context,
                CupertinoIcons.doc_text_fill,
                '28', // Placeholder value
                'Pending Submissions',
                Color(0xFFffbe45), // Tulip Tree
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context,
                CupertinoIcons.graph_square_fill,
                '18', // Placeholder value
                'Monthly Opportunities',
                Color(0xFF34D399), // Green
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.glassCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              color: AppTheme.foreground,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.body2.copyWith(
              color: AppTheme.mutedForeground,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActionsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Quick Actions',
            style: AppTextStyles.h3.copyWith(color: AppTheme.foreground),
          ),
        ),
        Container(
          decoration: AppStyles.glassCard(context),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  context,
                  CupertinoIcons.chat_bubble_2_fill,
                  l10n.navMessages,
                  'Check and respond to messages',
                  () => context.push('/admin/messages'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionTile(
                  context,
                  CupertinoIcons.graph_square,
                  'View Opportunities',
                  'Manage sales opportunities',
                  () => context.push('/admin/opportunities'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionTile(
                  context,
                  CupertinoIcons.person_2,
                  'User Management',
                  'Manage resellers and users',
                  () => context.push('/admin/user-management'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: AppTheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTextStyles.body2.copyWith(
                  color: AppTheme.mutedForeground,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmissionsNotificationSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Recent Activity',
            style: AppTextStyles.h3.copyWith(color: AppTheme.foreground),
          ),
        ),
        Container(
          height: 400, // Fixed height for the submissions list
          decoration: AppStyles.glassCard(context),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: AppStyles.standardCardPadding,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Notifications',
                      style: AppTextStyles.h4.copyWith(
                        color: AppTheme.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        return Row(
                          children: [
                            // Refresh Button
                            IconButton(
                              icon: const Icon(CupertinoIcons.refresh),
                              tooltip: 'Refresh Notifications',
                              onPressed: () {
                                // Force refresh notifications
                                refreshAdminNotifications(ref);
                                if (kDebugMode) {
                                  print('Notifications manually refreshed');
                                }
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(CupertinoIcons.checkmark_circle),
                              label: Text('Mark All as Read'),
                              onPressed: () {
                                // Mark all notifications as read
                                final notificationActions = ref.read(
                                  notificationActionsProvider,
                                );
                                notificationActions.markAllAsRead();
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Divider
              const Divider(height: 1),

              // Notifications list
              Expanded(child: _buildNotificationsList(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notificationsStream = ref.watch(refreshableAdminSubmissionsProvider);
    final notificationActions = ref.read(notificationActionsProvider);

    return notificationsStream.when(
      data: (notifications) {
        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.doc_text,
                  size: 48,
                  color: AppTheme.mutedForeground,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Submissions Yet',
                  style: AppTextStyles.body1.copyWith(
                    color: AppTheme.mutedForeground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'New submissions will appear here',
                  style: AppTextStyles.body2.copyWith(
                    color: AppTheme.mutedForeground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(CupertinoIcons.refresh),
                  label: Text('Refresh'),
                  onPressed: () {
                    refreshAdminNotifications(ref);
                  },
                ),
              ],
            ),
          );
        }

        // Wrap with RefreshIndicator for pull-to-refresh
        return RefreshIndicator(
          onRefresh: () async {
            // Force refresh by invalidating the provider
            refreshAdminNotifications(ref);
          },
          child: ListView.separated(
            padding: AppStyles.standardCardPadding,
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];

              return _buildSubmissionNotificationItem(
                context,
                notification,
                onTap: () async {
                  // Mark as read
                  await notificationActions.markAsRead(notification.id);

                  // Navigate to opportunities page instead of submission details
                  if (notification.metadata.containsKey('submissionId')) {
                    if (context.mounted) {
                      // Redirect to opportunities page since submissions page is removed
                      context.push('/admin/opportunities');
                    }
                  }
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  size: 48,
                  color: Colors.amber,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load notifications',
                  style: AppTextStyles.body1.copyWith(
                    color: AppTheme.foreground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: AppTextStyles.body2.copyWith(
                    color: AppTheme.mutedForeground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(CupertinoIcons.refresh),
                  label: Text('Try Again'),
                  onPressed: () {
                    refreshAdminNotifications(ref);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildSubmissionNotificationItem(
    BuildContext context,
    UserNotification notification, {
    required VoidCallback onTap,
  }) {
    final dateFormatter = DateFormat.yMMMd().add_jm();
    final formattedDate = dateFormatter.format(notification.createdAt);

    // Extract metadata
    final resellerName =
        notification.metadata['resellerName'] ?? 'Unknown reseller';
    final clientName = notification.metadata['clientName'] ?? 'Unknown client';
    final serviceType =
        notification.metadata['serviceType'] ?? 'Unknown service';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppStyles.standardCardPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      notification.isRead
                          ? AppTheme.mutedForeground.withOpacity(0.1)
                          : Colors.amber.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        notification.isRead
                            ? AppTheme.mutedForeground.withOpacity(0.2)
                            : Colors.amber.withOpacity(0.5),
                    width: notification.isRead ? 1 : 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.doc_text,
                    color:
                        notification.isRead
                            ? AppTheme.mutedForeground
                            : Colors.amber,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Notification content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Service type label
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            serviceType,
                            style: AppTextStyles.caption.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Date
                        Text(
                          formattedDate,
                          style: AppTextStyles.caption.copyWith(
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Notification title and unread indicator
                    Row(
                      children: [
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (!notification.isRead) const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTextStyles.body1.copyWith(
                              color: AppTheme.foreground,
                              fontWeight:
                                  notification.isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Submission details
                    RichText(
                      text: TextSpan(
                        style: AppTextStyles.body2.copyWith(
                          color: AppTheme.mutedForeground,
                        ),
                        children: [
                          const TextSpan(text: 'From '),
                          TextSpan(
                            text: resellerName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.foreground,
                            ),
                          ),
                          const TextSpan(text: ' for client '),
                          TextSpan(
                            text: clientName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow indicator
              Icon(
                CupertinoIcons.chevron_right,
                color: AppTheme.mutedForeground,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
