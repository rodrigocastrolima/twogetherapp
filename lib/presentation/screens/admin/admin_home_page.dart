import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../presentation/widgets/logo.dart';
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

            // --- MOVED Recent Activity UP ---
            _buildSubmissionsNotificationSection(context),

            const SizedBox(height: 24),

            // Quick stats section
            _buildQuickStatsSection(context, l10n),

            // --- REMOVED Quick Actions Section ---
            // const SizedBox(height: 24),
            // // Recent actions section
            // _buildRecentActionsSection(context),

            // --- REMOVED redundant notifications section placeholder ---
            // const SizedBox(height: 24),
            // // Submissions notification section
            // _buildSubmissionsNotificationSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, String date, String time) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          LogoWidget(height: 40),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                date,
                style: AppTextStyles.caption.copyWith(
                  color: AppTheme.mutedForeground,
                ),
              ),
              Text(
                time,
                style: AppTextStyles.caption.copyWith(
                  color: AppTheme.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ), // Adjusted padding
          child: Text(
            'Dashboard Statistics',
            style: AppTextStyles.h3.copyWith(color: AppTheme.foreground),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
          ), // Add padding to Row
          child: Row(
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 20,
        horizontal: 16,
      ), // Adjust padding
      decoration: BoxDecoration(
        // Use standard BoxDecoration
        color: theme.colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              theme.brightness == Brightness.dark
                  ? theme.colorScheme.onSurface.withOpacity(0.05)
                  : theme.dividerColor.withOpacity(0.1),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color:
                theme.brightness == Brightness.dark
                    ? theme.colorScheme.shadow.withOpacity(0.2)
                    : theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simpler Icon presentation
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16), // Increased space
          Text(
            value,
            style: AppTextStyles.h1.copyWith(
              // Larger value text
              color: AppTheme.foreground,
              fontWeight: FontWeight.w600, // Slightly less bold
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.body2.copyWith(
              color: AppTheme.mutedForeground,
            ),
            maxLines: 1, // Ensure single line
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionsNotificationSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
          ), // Adjust padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: AppTextStyles.h3.copyWith(color: AppTheme.foreground),
              ),
              // Simplified Header Actions
              Consumer(
                builder: (context, ref, _) {
                  return Row(
                    children: [
                      // Refresh Button (more subtle)
                      CupertinoButton(
                        padding: const EdgeInsets.all(4.0),
                        minSize: 0,
                        child: Icon(
                          CupertinoIcons.refresh,
                          size: 20,
                          color: AppTheme.mutedForeground,
                        ),
                        onPressed: () {
                          refreshAdminNotifications(ref);
                        },
                      ),
                      const SizedBox(width: 8),
                      // Mark All Read Button (more subtle)
                      CupertinoButton(
                        padding: const EdgeInsets.all(4.0),
                        minSize: 0,
                        child: Icon(
                          CupertinoIcons.checkmark_circle,
                          size: 20,
                          color: AppTheme.mutedForeground,
                        ),
                        onPressed: () {
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
        const SizedBox(height: 12), // Reduced space
        // Remove the outer container with fixed height and glass effect
        // Container(
        //   height: 400, // Fixed height for the submissions list
        //   decoration: AppStyles.glassCard(context),
        //   clipBehavior: Clip.antiAlias,
        //   child: Column(
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       // Header Removed from here
        //       const Divider(height: 1),
        //       Expanded(child: _buildNotificationsList(context)),
        //     ],
        //   ),
        // ),
        _buildNotificationsList(context), // Call list builder directly
      ],
    );
  }

  Widget _buildNotificationsList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notificationsStream = ref.watch(refreshableAdminSubmissionsProvider);
    final notificationActions = ref.read(notificationActionsProvider);
    final theme = Theme.of(context);

    return notificationsStream.when(
      data: (notifications) {
        if (notifications.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 48.0,
              ), // Add padding
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.bell_slash, // Changed icon
                    size: 48,
                    color: AppTheme.mutedForeground,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Recent Activity', // Updated text
                    style: AppTextStyles.body1.copyWith(
                      color: AppTheme.mutedForeground,
                      fontWeight: FontWeight.w500, // Adjusted weight
                    ),
                  ),
                  // Removed extra text and button
                ],
              ),
            ),
          );
        }

        // Build the list directly, no RefreshIndicator needed here if pull-to-refresh is on main scroll
        return ListView.builder(
          shrinkWrap: true, // Important for nested list
          physics:
              const NeverScrollableScrollPhysics(), // Disable nested scrolling
          padding: const EdgeInsets.symmetric(horizontal: 16.0), // Add padding
          itemCount: notifications.length,
          // Remove separatorBuilder for cleaner look
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _buildCleanNotificationItem(
              // Use new item builder
              context,
              notification,
              onTap: () async {
                await notificationActions.markAsRead(notification.id);
                if (notification.metadata.containsKey('submissionId')) {
                  if (context.mounted) {
                    context.push('/admin/opportunities');
                  }
                }
              },
            );
          },
        );
      },
      loading:
          () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CupertinoActivityIndicator(), // Use Cupertino style loader
            ),
          ),
      error:
          (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    size: 48,
                    color: Colors.orange, // Use warning color
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load activity', // Updated text
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
                  CupertinoButton(
                    child: Text('Try Again'),
                    onPressed: () {
                      refreshAdminNotifications(ref);
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // New Clean Notification Item Builder
  Widget _buildCleanNotificationItem(
    BuildContext context,
    UserNotification notification, {
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final dateFormatter = DateFormat.yMd().add_jm(); // Simpler date format
    final formattedDate = dateFormatter.format(notification.createdAt);

    // Extract metadata
    final resellerName = notification.metadata['resellerName'] ?? 'Unknown';
    final clientName = notification.metadata['clientName'] ?? '?';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0), // Adjust padding
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Unread indicator dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color:
                    notification.isRead ? Colors.transparent : AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title, // e.g., "New Submission"
                    style: AppTextStyles.body1.copyWith(
                      color: AppTheme.foreground,
                      fontWeight: FontWeight.w500, // Slightly bolder
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${resellerName} / ${clientName}', // Combine reseller/client
                    style: AppTextStyles.body2.copyWith(
                      color: AppTheme.mutedForeground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Date
            Text(
              formattedDate,
              style: AppTextStyles.caption.copyWith(
                color: AppTheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
