import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import '../../widgets/logo.dart';
import 'dart:math';
import '../../../core/theme/ui_styles.dart';
import '../../../features/notifications/presentation/providers/notification_provider.dart';
import '../../../core/models/notification.dart';
import '../../../features/notifications/presentation/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../features/services/presentation/providers/service_submission_provider.dart';
import '../../widgets/onboarding/app_tutorial_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/constants.dart';

class ResellerHomePage extends ConsumerStatefulWidget {
  const ResellerHomePage({super.key});

  @override
  ConsumerState<ResellerHomePage> createState() => _ResellerHomePageState();
}

class _ResellerHomePageState extends ConsumerState<ResellerHomePage> {
  bool _isEarningsVisible = true;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    // Set up listener to detect manual pull-to-refresh
    _scrollController.addListener(() {
      // If we're overscrolling at the top (pulling down)
      if (_scrollController.position.pixels < -50) {
        // Trigger the refresh
        _refreshIndicatorKey.currentState?.show();
      }
    });

    // Check and show tutorial after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Ensure widget is still mounted
        _checkAndShowTutorial(context);
      }
    });
  }

  @override
  void dispose() {
    // Make sure to cancel any animations or ongoing operations
    _scrollController.dispose();
    // Clean up any resources to prevent leaks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure all resources are properly released
      if (mounted) {
        setState(() {});
      }
    });
    super.dispose();
  }

  // Perform the refresh operation
  Future<void> _onRefresh() async {
    // Simulate a network request
    await Future.delayed(const Duration(seconds: 2));

    // Update UI with the refreshed data
    if (mounted) {
      setState(() {
        // For demo, we'll toggle the earnings visibility 70% of the time
        if (Random().nextInt(10) < 7) {
          _isEarningsVisible = !_isEarningsVisible;
        }
      });
    }
  }

  // Helper method to get user initials
  String _getUserInitials(AppLocalizations l10n, String? name, String? email) {
    if (name != null && name.isNotEmpty) {
      final nameParts = name.trim().split(' ');
      if (nameParts.length > 1) {
        // If there are multiple parts, use first letter of first and last name
        return '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase();
      } else if (nameParts.isNotEmpty) {
        // If there's only one part, use the first letter
        return nameParts.first[0].toUpperCase();
      }
    }

    // Fallback to email
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }

    // Default
    return l10n.userInitialsDefault;
  }

  // Helper method to show the auto-dismissing dialog
  Future<void> _showAutoDismissDialog(BuildContext context) async {
    // Use the current context (from ResellerHomePage) to show the dialog
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        // Use the custom stateful widget for the dialog content
        return const _AutoDismissDialogContent();
      },
    );
  }

  // --- Function to check and show onboarding tutorial ---
  Future<void> _checkAndShowTutorial(BuildContext context) async {
    // Check mounted status again inside async function
    if (!context.mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool hasCompletedTutorial =
          prefs.getBool(AppConstants.kHasCompletedOnboardingTutorial) ?? false;

      bool isFirstLogin = !hasCompletedTutorial;

      if (isFirstLogin && context.mounted) {
        // Show Tutorial as a full-screen dialog overlay
        showGeneralDialog(
          context: context,
          barrierDismissible: false, // Prevent dismissing by tapping outside
          barrierLabel: 'Tutorial',
          barrierColor: Colors.black.withOpacity(0.5), // Dimmed background
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (ctx, anim1, anim2) => const AppTutorialScreen(),
          transitionBuilder: (ctx, anim1, anim2, child) {
            // Simple fade transition
            return FadeTransition(opacity: anim1, child: child);
          },
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error checking/showing tutorial: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate the height of the top section (1/3 of screen)
    final topSectionHeight = screenSize.height * 0.33;

    // Listener for the success dialog
    ref.listen<bool>(showSubmissionSuccessDialogProvider, (
      previousState,
      shouldShow,
    ) {
      // Use WidgetsBinding to defer showing dialog and resetting state until after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Check if mounted is crucial if this logic moves to initState or dispose
        // In build, it's generally safe but good practice
        if (shouldShow && mounted) {
          _showAutoDismissDialog(context);
          // Reset the flag immediately after triggering the dialog
          ref.read(showSubmissionSuccessDialogProvider.notifier).state = false;
        }
      });
    });

    return Scaffold(
      backgroundColor: Colors.transparent, // Make scaffold transparent
      body: RefreshIndicator(
        displacement: 40,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Top transparent section - background image will show through from MainLayout
              Container(
                height: topSectionHeight,
                width: double.infinity,
                // No background color to keep it transparent
                child: SafeArea(
                  bottom: false,
                  child: Stack(
                    children: [
                      // Content
                      Column(
                        children: [
                          SizedBox(height: 20),

                          // Top row with profile and action icons
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Profile icon with user's initials
                                ref
                                    .watch(authStateChangesProvider)
                                    .when(
                                      data:
                                          (user) => GestureDetector(
                                            onTap:
                                                () => context.push(
                                                  '/profile-details',
                                                ),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.surface
                                                    .withOpacity(0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: Center(
                                                  child: Text(
                                                    _getUserInitials(
                                                      l10n,
                                                      user?.displayName,
                                                      user?.email,
                                                    ),
                                                    style: theme
                                                        .textTheme
                                                        .labelLarge
                                                        ?.copyWith(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      loading:
                                          () => Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surface
                                                  .withOpacity(0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: Center(
                                                child: SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      error:
                                          (_, __) => GestureDetector(
                                            onTap:
                                                () => context.push(
                                                  '/profile-details',
                                                ),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.surface
                                                    .withOpacity(0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: Center(
                                                  child: Text(
                                                    l10n.userInitialsDefault,
                                                    style: theme
                                                        .textTheme
                                                        .labelLarge
                                                        ?.copyWith(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                    ),

                                // Action icons row
                                Row(
                                  children: [
                                    // Search icon
                                    _buildCircleIconButton(
                                      icon: CupertinoIcons.search,
                                      onTap: () {},
                                    ),
                                    const SizedBox(width: 10),
                                    // Notification bell icon
                                    _buildCircleIconButton(
                                      icon: CupertinoIcons.bell_fill,
                                      onTap: () {},
                                    ),
                                    const SizedBox(width: 8),
                                    // Help/Tutorial Icon (NEW)
                                    _buildCircleIconButton(
                                      icon: CupertinoIcons.question_circle,
                                      onTap: () {
                                        // Manually trigger the tutorial screen as a dialog
                                        showGeneralDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          barrierLabel: 'Tutorial',
                                          barrierColor: Colors.black
                                              .withOpacity(0.5),
                                          transitionDuration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          pageBuilder:
                                              (ctx, anim1, anim2) =>
                                                  const AppTutorialScreen(),
                                          transitionBuilder: (
                                            ctx,
                                            anim1,
                                            anim2,
                                            child,
                                          ) {
                                            return FadeTransition(
                                              opacity: anim1,
                                              child: child,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Expanded space to vertically center the commission box
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: _buildCommissionBox(l10n),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // White content area below the top section
              Container(
                width: double.infinity,
                color: theme.colorScheme.background,
                padding: const EdgeInsets.only(top: 20, bottom: 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildQuickActionsSection(l10n),
                    ),
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildNotificationsSection(l10n),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.15),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildQuickActionsSection(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.homeQuickActionsTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 24),

        // Create Service button with smooth gradient and shadow
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: ElevatedButton(
            onPressed: () => context.push('/services'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary,
                    Color.lerp(AppTheme.primary, Colors.blue, 0.4) ??
                        AppTheme.primary,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.add_circled,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.homeCreateNewServiceButton,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsSection(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with badge
        Row(
          children: [
            Text(
              l10n.homeNotifications,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onBackground,
              ),
            ),
            const SizedBox(width: 8),

            // Use the unread count provider for the badge
            Consumer(
              builder: (context, ref, child) {
                final unreadCountStream = ref.watch(
                  unreadNotificationsCountProvider,
                );

                return unreadCountStream.when(
                  data: (count) {
                    if (count <= 0) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox(width: 24, height: 24),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Pendentes section with total pending amount
        Consumer(
          builder: (context, ref, child) {
            final notificationsStream = ref.watch(userNotificationsProvider);

            return notificationsStream.when(
              data: (notifications) {
                // Calculate total monetary values from rejection notifications
                double pendingAmount = 0.0;
                for (final notification in notifications) {
                  if (notification.type == NotificationType.rejection) {
                    final amount = notification.metadata['amount'];
                    if (amount != null) {
                      pendingAmount += (amount is double) ? amount : 0.0;
                    }
                  }
                }

                // Show Pendentes card if there are pending amounts
                if (pendingAmount > 0) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:
                              theme.brightness == Brightness.dark
                                  ? theme.colorScheme.shadow.withOpacity(0.3)
                                  : theme.colorScheme.shadow.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                          spreadRadius: 0,
                        ),
                      ],
                      border: Border.all(
                        color:
                            theme.brightness == Brightness.dark
                                ? theme.colorScheme.onSurface.withOpacity(0.05)
                                : Colors.transparent,
                        width: theme.brightness == Brightness.dark ? 1 : 0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pendentes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '-${pendingAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
              loading:
                  () => const Center(
                    child: SizedBox(
                      height: 50,
                      child: CircularProgressIndicator(),
                    ),
                  ),
              error:
                  (_, __) => Center(
                    child: Text(
                      'Failed to load notifications',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
            );
          },
        ),

        const SizedBox(height: 16),

        // List of notifications
        Consumer(
          builder: (context, ref, child) {
            final notificationsStream = ref.watch(userNotificationsProvider);
            final notificationActions = ref.read(notificationActionsProvider);

            return notificationsStream.when(
              data: (notifications) {
                if (notifications.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.bell_slash,
                            size: 48,
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children:
                      notifications.map((notification) {
                        return _buildNotificationItem(
                          notification: notification,
                          onTap: () {
                            _handleNotificationTap(
                              notification,
                              notificationActions,
                            );
                          },
                        );
                      }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (_, __) => Center(
                    child: Text(
                      'Failed to load notifications',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
            );
          },
        ),
      ],
    );
  }

  // Helper method to handle notification tap
  void _handleNotificationTap(
    UserNotification notification,
    NotificationActions actions,
  ) async {
    // Mark notification as read
    await actions.markAsRead(notification.id);

    // Navigate based on notification type and metadata
    switch (notification.type) {
      case NotificationType.statusChange:
        if (notification.metadata.containsKey('submissionId')) {
          final submissionId = notification.metadata['submissionId'];
          context.push('/submissions/$submissionId');
        }
        break;
      case NotificationType.rejection:
        if (notification.metadata.containsKey('submissionId')) {
          final submissionId = notification.metadata['submissionId'];
          context.push('/notifications/$submissionId');
        }
        break;
      case NotificationType.payment:
        // Navigate to payment details or dashboard
        context.push('/dashboard');
        break;
      case NotificationType.system:
      default:
        // For system notifications, just mark as read but don't navigate
        break;
    }
  }

  // New method to build a notification item
  Widget _buildNotificationItem({
    required UserNotification notification,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    IconData icon;
    Color iconColor;

    // Set icon and color based on notification type
    switch (notification.type) {
      case NotificationType.statusChange:
        icon = CupertinoIcons.arrow_right_arrow_left_circle;
        final status = notification.metadata['newStatus'] as String? ?? '';
        if (status == 'approved') {
          iconColor = Colors.green;
        } else if (status == 'rejected') {
          iconColor = Colors.red;
        } else {
          iconColor = Colors.amber;
        }
        break;
      case NotificationType.rejection:
        icon = CupertinoIcons.exclamationmark_triangle_fill;
        iconColor = Colors.red;
        break;
      case NotificationType.payment:
        icon = CupertinoIcons.money_dollar_circle;
        iconColor = Colors.orange;
        break;
      case NotificationType.system:
      default:
        icon = CupertinoIcons.bell_fill;
        iconColor = theme.colorScheme.primary;
    }

    // Format date
    final formatter = DateFormat('dd MMM');
    final timeFormatter = DateFormat('HH:mm');
    final formattedDate = formatter.format(notification.createdAt);
    final formattedTime = timeFormatter.format(notification.createdAt);
    final dateString =
        notification.createdAt.day == DateTime.now().day
            ? 'Today, ${formattedTime}'
            : formattedDate;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:
                theme.brightness == Brightness.dark
                    ? theme.colorScheme.shadow.withOpacity(0.2)
                    : theme.colorScheme.shadow.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color:
              theme.brightness == Brightness.dark
                  ? theme.colorScheme.onSurface.withOpacity(0.05)
                  : Colors.transparent,
          width: theme.brightness == Brightness.dark ? 1 : 0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Notification icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
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
                          Text(
                            dateString,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow icon
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommissionBox(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/dashboard'),
        splashColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            // Enhanced glass effect with gradient
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.4)
                    : Colors.white.withOpacity(0.3),
                theme.brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Account title section with shimmer effect
                    ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.9),
                            Colors.white,
                            Colors.white.withOpacity(0.9),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ).createShader(bounds);
                      },
                      child: Text(
                        l10n.homeCommissionBoxTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Balance amount with visibility toggle
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isEarningsVisible = !_isEarningsVisible;
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Amount section
                          _isEarningsVisible
                              ? Row(
                                children: [
                                  Text(
                                    '5500,10',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withOpacity(
                                                0.2,
                                              ),
                                              blurRadius: 3,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.currencyCodeEUR,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Eye icon toggle
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.eye_fill,
                                      size: 18,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              )
                              : Row(
                                children: [
                                  Container(
                                    width: 140,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.currencyCodeEUR,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Eye icon toggle
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.eye_slash_fill,
                                      size: 18,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // VIEW DETAILS button with enhanced styling
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () => context.push('/dashboard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.4),
                            width: 1,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.homeCommissionBoxDetailsButton,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              CupertinoIcons.chevron_right,
                              size: 12,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Auto-Dismiss Dialog Content Widget
class _AutoDismissDialogContent extends StatefulWidget {
  const _AutoDismissDialogContent({Key? key}) : super(key: key);

  @override
  State<_AutoDismissDialogContent> createState() =>
      _AutoDismissDialogContentState();
}

class _AutoDismissDialogContentState extends State<_AutoDismissDialogContent> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Start a 5-second timer to automatically dismiss the dialog
    _timer = Timer(const Duration(seconds: 3), () {
      // Ensure the dialog context is still valid before popping
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer if the widget is disposed early
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Potentially adapt theme/styling based on ResellerHomePage if needed
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
          SizedBox(width: 10),
          Text('Submission Successful'), // Consider using l10n here
        ],
      ),
      content: const SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text(
              'Your service request has been submitted and will be reviewed shortly.', // Consider using l10n here
            ),
          ],
        ),
      ),
      actions: const [], // No buttons needed for auto-dismiss
    );
  }
}
