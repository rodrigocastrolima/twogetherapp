import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';

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
    return Scaffold(
      body: Container(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Submissions notification section
            _buildSubmissionsNotificationSection(context),

            // You can add more sections here for other admin dashboard widgets
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionsNotificationSection(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: AppStyles.standardBlur,
          child: Container(
            decoration: AppStyles.glassCard(context),
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
                        'Recent Submissions',
                        style: AppTextStyles.h3.copyWith(
                          color: AppTheme.foreground,
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          return Row(
                            children: [
                              // Refresh Button
                              IconButton(
                                icon: const Icon(CupertinoIcons.refresh),
                                tooltip: 'Refresh notifications',
                                onPressed: () {
                                  // Force refresh notifications
                                  refreshAdminNotifications(ref);
                                  if (kDebugMode) {
                                    print('Notifications manually refreshed');
                                  }
                                },
                              ),
                              TextButton.icon(
                                icon: const Icon(
                                  CupertinoIcons.checkmark_circle,
                                ),
                                label: const Text('Mark all as read'),
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

                // Notifications list
                Expanded(child: _buildNotificationsList(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsList(BuildContext context) {
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
                  'No submissions yet',
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
                  label: const Text('Refresh'),
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

                  // Navigate to submission details
                  if (notification.metadata.containsKey('submissionId')) {
                    final submissionId = notification.metadata['submissionId'];
                    if (context.mounted) {
                      context.push('/admin/submissions/$submissionId');
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
                  label: const Text('Try Again'),
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
