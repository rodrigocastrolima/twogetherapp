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
import '../../../core/constants/constants.dart';
import '../../../app/router/app_router.dart'; // Import AppRouter to access notifier
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/onboarding/app_tutorial_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- Need SharedPreferences again

// Constants for the highlight area (adjust as needed)
const double _highlightPadding = 8.0;
const double _iconSize = 22.0; // From _buildCircleIconButton
const double _iconPadding = 10.0; // From _buildCircleIconButton
const double _totalIconSpace = (_iconPadding * 2) + _iconSize;
const double _topRightPadding = 20.0; // Horizontal padding from header

class ResellerHomePage extends ConsumerStatefulWidget {
  const ResellerHomePage({super.key});

  @override
  ConsumerState<ResellerHomePage> createState() => _ResellerHomePageState();
}

// Add SingleTickerProviderStateMixin for AnimationController
class _ResellerHomePageState extends ConsumerState<ResellerHomePage>
    with SingleTickerProviderStateMixin {
  bool _isEarningsVisible = true;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  // --- Animation State ---
  late AnimationController _helpIconAnimationController;
  late Animation<double> _helpIconAnimation;
  bool _hasSeenHintLocally = false; // Keep track of local dismissal
  bool _initCheckDone = false; // Prevent re-checking prefs on every build
  // ---------------------

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

    // --- Initialize Animation Controller ---
    _helpIconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _helpIconAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _helpIconAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    // -------------------------------------

    // --- Check local preference ONCE after first frame ---
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && !_initCheckDone) {
        final prefs = await SharedPreferences.getInstance();
        final seenHint =
            prefs.getBool(AppConstants.kHasSeenHelpIconHint) ?? false;
        setState(() {
          _hasSeenHintLocally = seenHint;
          _initCheckDone = true;
        });
        print('initState - _hasSeenHintLocally: $_hasSeenHintLocally'); // Debug
      }
    });
    // -----------------------------------------------------
  }

  @override
  void dispose() {
    // Make sure to cancel any animations or ongoing operations
    _scrollController.dispose();
    _helpIconAnimationController.dispose(); // Dispose animation controller
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    // --- WATCH AuthNotifier state ---
    final authNotifier = ref.watch(authNotifierProvider);
    final bool isFirstLogin = authNotifier.isFirstLogin;
    final bool passwordHasBeenChanged =
        authNotifier
            .initialPasswordChanged; // Still needed for password reminder
    // -------------------------------

    // --- Determine if animation should run ---
    final bool shouldAnimate = isFirstLogin && !_hasSeenHintLocally;
    // Start/stop animation controller based on state
    if (shouldAnimate && !_helpIconAnimationController.isAnimating) {
      print(
        "Build: Starting animation (isFirstLogin: $isFirstLogin, !_hasSeenHintLocally: ${!_hasSeenHintLocally})",
      );
      _helpIconAnimationController.repeat(reverse: true);
    } else if (!shouldAnimate && _helpIconAnimationController.isAnimating) {
      print(
        "Build: Stopping animation (isFirstLogin: $isFirstLogin, !_hasSeenHintLocally: ${!_hasSeenHintLocally})",
      );
      _helpIconAnimationController.stop();
      // Reset scale immediately when stopping
      _helpIconAnimationController.value = 0.0;
    }
    // ----------------------------------------

    final statusBarHeight = MediaQuery.of(context).padding.top;

    // --- Build method no longer needs top-level Stack ---
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        displacement: 40,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // --- Top Section ---
              Container(
                height: screenSize.height * 0.33,
                width: double.infinity,
                child: SafeArea(
                  bottom: false,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                            ), // Use constant if defined
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Profile Icon...
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
                                    // Search...
                                    _buildCircleIconButton(
                                      icon: CupertinoIcons.search,
                                      onTap: () {},
                                      isHighlighted: false,
                                    ),
                                    const SizedBox(width: 10),
                                    // Bell...
                                    _buildCircleIconButton(
                                      icon: CupertinoIcons.bell_fill,
                                      onTap: () {},
                                      isHighlighted: false,
                                    ),
                                    const SizedBox(width: 8),
                                    // --- Help Icon with Animation ---
                                    ScaleTransition(
                                      scale: _helpIconAnimation,
                                      child: _buildCircleIconButton(
                                        icon: CupertinoIcons.question_circle,
                                        isHighlighted: shouldAnimate,
                                        onTap: () async {
                                          if (shouldAnimate) {
                                            print(
                                              'Help icon tapped while animating. Stopping animation.',
                                            );
                                            _helpIconAnimationController.stop();
                                            final prefs =
                                                await SharedPreferences.getInstance();
                                            await prefs.setBool(
                                              AppConstants.kHasSeenHelpIconHint,
                                              true,
                                            );
                                            if (mounted) {
                                              setState(() {
                                                _hasSeenHintLocally = true;
                                              });
                                            }
                                            print(
                                              'Saved kHasSeenHelpIconHint=true.',
                                            );
                                          }

                                          if (context.mounted) {
                                            showGeneralDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              barrierLabel: 'Tutorial',
                                              barrierColor: Colors.black
                                                  .withOpacity(0.5),
                                              transitionDuration:
                                                  const Duration(
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
                                          }
                                        },
                                      ),
                                    ),
                                    // --------------------------------
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Commission Box...
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
              // --- White content area ---
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

  // --- Circle Icon Button remains the same ---
  Widget _buildCircleIconButton({
    Key? key,
    required IconData icon,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    final theme = Theme.of(context);
    // Define colors based on state
    final bgColor =
        isHighlighted
            ? theme.colorScheme.primary.withOpacity(0.85)
            : theme.colorScheme.surface.withOpacity(0.15);
    final iconColor =
        isHighlighted ? theme.colorScheme.onPrimary : Colors.white;
    final borderColor =
        isHighlighted
            ? theme.colorScheme.primary
            : Colors.white.withOpacity(0.1);

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10.0), // Use constant if defined
        decoration: BoxDecoration(
          color: bgColor, // Use dynamic background color
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color:
                  isHighlighted
                      ? theme.colorScheme.primary.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: borderColor,
            width: 0.5,
          ), // Use dynamic border color
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 22.0,
        ), // Use dynamic icon color & constant size
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
    // *** Read password change status here as well ***
    final authNotifier = ref.watch(authNotifierProvider);
    final bool passwordHasBeenChanged = authNotifier.initialPasswordChanged;
    // ************************************************

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
              data: (notificationsFromProvider) {
                // --- Create and Inject Password Reminder ---
                List<UserNotification> combinedNotifications = [
                  ...notificationsFromProvider,
                ];

                // Get current user ID for the fake notification
                final currentUserId =
                    FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';

                if (!passwordHasBeenChanged) {
                  final passwordReminder = UserNotification(
                    id: '__password_reminder__', // Special ID
                    userId: currentUserId, // <-- ADD userId
                    title: 'Security Recommendation', // TODO: l10n
                    message: 'Change your initial password.', // TODO: l10n
                    type: NotificationType.system, // Use system type for now
                    createdAt: DateTime.now(), // Timestamp doesn't matter much
                    isRead: true, // Mark as read so it doesn't affect badge
                    metadata: {
                      'isPasswordReminder': true,
                    }, // Extra flag if needed
                  );
                  // Add reminder to the beginning of the list
                  combinedNotifications.insert(0, passwordReminder);
                }
                // -----------------------------------------

                if (combinedNotifications.isEmpty) {
                  // Use the original empty state logic
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
                            'No notifications', // TODO: l10n
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

                // Build list using the combined list
                return Column(
                  children:
                      combinedNotifications.map((notification) {
                        // Use combinedNotifications
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
                      'Failed to load notifications', // TODO: l10n
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
    // --- Check for special password reminder ID ---
    if (notification.id == '__password_reminder__') {
      context.push('/profile-details');
      return; // Don't proceed with marking as read etc.
    }
    // --------------------------------------------

    // Mark notification as read (only for real notifications)
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
          context.push(
            '/notifications/$submissionId',
          ); // Should this be submission detail?
        }
        break;
      case NotificationType.payment:
        // Navigate to payment details or dashboard
        context.push('/dashboard');
        break;
      case NotificationType.system:
      default:
        // For system notifications (like our reminder, though handled above),
        // just mark as read but don't navigate
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
