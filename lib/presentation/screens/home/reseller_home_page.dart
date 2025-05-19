import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/onboarding/app_tutorial_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- Need SharedPreferences again
import '../../../features/notifications/presentation/widgets/rejection_detail_dialog.dart'; // NEW
import '../../../features/proposal/presentation/providers/proposal_providers.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart'; // Import package
import '../../widgets/simple_list_item.dart';

// Constants for the highlight area (adjust as needed)
const double _highlightPadding = 8.0;
const double _iconSize = 22.0; // From _buildCircleIconButton
const double _iconPadding = 10.0; // From _buildCircleIconButton
const double _totalIconSpace = (_iconPadding * 2) + _iconSize;
const double _topRightPadding = 20.0; // Horizontal padding from header

// Place this at the top-level, outside of _ResellerHomePageState
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 170,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResellerHomePage extends ConsumerStatefulWidget {
  const ResellerHomePage({super.key});

  @override
  ConsumerState<ResellerHomePage> createState() => _ResellerHomePageState();
}

// Add SingleTickerProviderStateMixin for AnimationController
class _ResellerHomePageState extends ConsumerState<ResellerHomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isEarningsVisible = true;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  // --- Animation State ---
  late AnimationController _helpIconAnimationController;
  late Animation<double> _helpIconAnimation;
  bool _hasSeenHintLocally = false;
  bool _initCheckDone = false;
  bool _isAppActive = true; // Add this flag
  // ---------------------

  // --- Hover States for Icons ---
  bool _isProfileHovering = false;
  // For Notification and Help icons, hover state will be managed within _buildCircleIconButton
  // or we might need to pass hover callbacks if preferred.
  // For now, let's aim to make _buildCircleIconButton stateful if it's simple enough,
  // or pass hover state down.
  // Let's make _buildCircleIconButton a StatefulWidget to manage its own hover.
  // --------------------------

  // +++ NEW: Animation State for Commission Box Glow +++
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  // +++ END NEW +++

  // --- Animation State for Firefly Effect ---
  // _fireflyPositionAnimation will represent progress around the perimeter (0.0 to 1.0)
  // No explicit Animation<double> needed if we directly use _fireflyController.value

  // +++ NEW: Animation Controller for Firefly Flash +++
  late AnimationController _fireflyFlashController;
  late Animation<double> _fireflyFlashAnimation;
  // +++ END NEW +++

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Set up listener to detect manual pull-to-refresh
    _scrollController.addListener(() {
      if (_scrollController.position.pixels < -50) {
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

    // +++ NEW: Initialize Glow Animation Controller +++
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Duration of one pulse cycle
    )..repeat(reverse: true); // Repeat and reverse for pulsing

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    ); // Animates opacity of the glow
    // +++ END NEW +++

    // Initialize Firefly Animation Controller
    // _fireflyController = AnimationController(
    //   vsync: this,
    //   duration: const Duration(seconds: 8), // Time to travel around the perimeter once
    // )..repeat(); // Continuous loop

    // +++ NEW: Initialize Firefly Flash Animation Controller +++
    _fireflyFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Short flash duration
    );
    _fireflyFlashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fireflyFlashController, curve: Curves.easeInOut),
    );

    // Trigger flash periodically or based on _fireflyController
    // _fireflyController.addListener(() {
    //   // Example: Flash when the firefly is roughly at the start (or any other condition)
    //   if (_fireflyController.value < 0.05 && !_fireflyFlashController.isAnimating) {
    //     _fireflyFlashController.forward().then((_) => _fireflyFlashController.reverse());
    //   }
    //   // More sophisticated flashing logic can be added here, e.g., random intervals
    // });

    // --- Check local preference ONCE after first frame ---
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && !_initCheckDone) {
        final prefs = await SharedPreferences.getInstance();
        final seenHint = prefs.getBool(AppConstants.kHasSeenHelpIconHint) ?? false;
        if (mounted) {
        setState(() {
          _hasSeenHintLocally = seenHint;
          _initCheckDone = true;
        });
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final authNotifier = ref.read(authNotifierProvider); // Read it here
    if (state == AppLifecycleState.paused) {
      // App is in background
      setState(() {
        _isAppActive = false;
      });
      _helpIconAnimationController.stop();
    } else if (state == AppLifecycleState.resumed) {
      // App is back in foreground
      setState(() {
        _isAppActive = true;
      });
      // Use authNotifier here
      if (_isAppActive && authNotifier.isFirstLogin && !_hasSeenHintLocally) {
        _helpIconAnimationController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _helpIconAnimationController.stop();
    _helpIconAnimationController.dispose();
    _scrollController.dispose();
    _glowController.dispose(); // +++ NEW: Dispose glow controller +++
    // _fireflyController.dispose(); // Dispose firefly controller
    _fireflyFlashController.dispose(); // +++ NEW: Dispose flash controller +++
    super.dispose();
  }

  // Helper method to get user initials
  String _getUserInitials(String? name, String? email) {
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
    return 'TW';
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

  // Perform the refresh operation
  Future<void> _onRefresh() async {
    // Refresh providers instead of just toggling visibility
    ref.refresh(resellerTotalCommissionProvider);
    ref.refresh(userNotificationsProvider);

    // The UI will update automatically when the providers rebuild.
    // No need for setState or explicit waiting here unless desired for indicator duration.

    // Optional: Simulate a minimum duration for the refresh indicator if needed
    // await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final authNotifier = ref.watch(authNotifierProvider);
    final bool isFirstLogin = authNotifier.isFirstLogin;
    final bool passwordHasBeenChanged =
        authNotifier
            .initialPasswordChanged; // Still needed for password reminder
    final bool currentShouldAnimateHelpIcon = _isAppActive && isFirstLogin && !_hasSeenHintLocally;

    if (currentShouldAnimateHelpIcon && !_helpIconAnimationController.isAnimating) {
      _helpIconAnimationController.repeat(reverse: true);
    } else if (!currentShouldAnimateHelpIcon && _helpIconAnimationController.isAnimating) {
      _helpIconAnimationController.stop();
      _helpIconAnimationController.value = 0.0;
    }

    final statusBarHeight = MediaQuery.of(context).padding.top;

    final screenWidth = MediaQuery.of(context).size.width;
    // final bool isWideScreen = screenWidth > 900;

    // --- Build method uses Stack structure similar to old code ---
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Make Scaffold background transparent
      // Explicitly wrap body in a transparent Material widget
      body: Material(
        type: MaterialType.transparency,
        child: RefreshIndicator(
          key: _refreshIndicatorKey, // Assign key
          displacement: 40,
          onRefresh: _onRefresh,
          backgroundColor: Colors.transparent, // Explicitly set background
          color: theme.colorScheme.primary, // Color of the spinner
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Top Section Container (Transparent again, relies on MainLayout) ---
                Container(
                  height:
                      screenSize.height * 0.33, // Match background image height
                  width: double.infinity,
                  // REMOVED explicit BoxDecoration with image
                  color: Colors.transparent,
                  child: SafeArea(
                    bottom: false,
                    child: Stack(
                      // Stack for icons and commission box
                      children: [
                        Column(
                          children: [
                            const SizedBox(height: 20),
                            // --- Header Row (Profile Icon, Action Icons) ---
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Profile Icon
                                  ref
                                      .watch(authStateChangesProvider)
                                      .when(
                                        data:
                                            (user) => _buildProfileIcon(
                                              context,
                                              theme,
                                              user?.displayName,
                                              user?.email,
                                            ),
                                        loading:
                                            () => _buildProfileIconPlaceholder(
                                              context,
                                              theme,
                                            ),
                                        error:
                                            (_, __) => _buildProfileIcon(
                                              context,
                                              theme,
                                              null,
                                              null,
                                            ), // Fallback
                                      ),
                                  // Action Icons
                                  Row(
                                    children: [
                                      _CircleIconButton(
                                        // Changed to stateful version
                                        icon: CupertinoIcons.bell_fill,
                                        onTap: () {
                                          /* TODO */
                                        },
                                        isHighlighted:
                                            false, // This might be separate from hover scale
                                      ),
                                      const SizedBox(
                                        width: 8,
                                      ), // Adjusted from 10 to 8 if search is removed
                                      ScaleTransition(
                                        scale:
                                            _helpIconAnimation, // This is for the hint pulse
                                        child: _CircleIconButton(
                                          // Changed to stateful version
                                          icon: CupertinoIcons.question_circle,
                                          isHighlighted:
                                              currentShouldAnimateHelpIcon, // For hint pulse border/bg
                                          onTap:
                                              () => _handleHelpIconTap(
                                                context,
                                                currentShouldAnimateHelpIcon, // Pass currentShouldAnimate
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Commission Box (Centered within Expanded)
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  // Ensure _buildCommissionBox is the direct child here
                                  child: _buildCommissionBox(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // --- Bottom Content Area (Opaque Background) ---
                Container(
                  width: double.infinity,
                  color: theme.colorScheme.background,
                  padding: const EdgeInsets.only(top: 20, bottom: 60),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width < 600
                              ? 16
                              : MediaQuery.of(context).size.width < 900
                                  ? 16
                                  : 16,
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                            _buildQuickActionsSection(),
                      const SizedBox(height: 30),
                            _buildNotificationsSection(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper for Profile Icon ---
  Widget _buildProfileIcon(
    BuildContext context,
    ThemeData theme,
    String? displayName,
    String? email,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isProfileHovering = true),
      onExit: (_) => setState(() => _isProfileHovering = false),
      child: Transform.scale(
        scale: _isProfileHovering ? 1.15 : 1.0,
        child: GestureDetector(
          onTap: () => context.push('/profile-details'),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: AppStyles.circularIconButtonStyle(
              context,
              isHovering: _isProfileHovering,
              isHighlighted: false,
            ),
            child: SizedBox(
              width: 22,
              height: 22,
              child: Center(
                child: Text(
                  _getUserInitials(displayName, email),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper for Profile Icon Placeholder ---
  Widget _buildProfileIconPlaceholder(BuildContext context, ThemeData theme) {
    // Placeholder doesn't need hover effects as it's temporary
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: const SizedBox(
        width: 22,
        height: 22,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper for Help Icon Tap Logic ---
  Future<void> _handleHelpIconTap(
    BuildContext context,
    bool wasAnimating, // Renamed from shouldAnimate to reflect its state when tapped
  ) async {
    if (wasAnimating) { // Use the passed parameter
      print('Help icon tapped while animating. Stopping animation.');
      _helpIconAnimationController.stop();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.kHasSeenHelpIconHint, true);
      if (mounted) {
        setState(() {
          _hasSeenHintLocally = true;
        });
      }
      print('Saved kHasSeenHelpIconHint=true.');
    }

    if (context.mounted) {
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Tutorial',
        barrierColor: Colors.black.withOpacity(0.5),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (ctx, anim1, anim2) => const AppTutorialScreen(),
        transitionBuilder: (ctx, anim1, anim2, child) {
          return FadeTransition(opacity: anim1, child: child);
        },
      );
    }
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

  // --- MODIFIED Quick Actions Section ---
  Widget _buildQuickActionsSection() {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ações Rápidas',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 16,
                  children: [
              _QuickActionCard(
                icon: CupertinoIcons.add_circled_solid,
                label: 'Novo Serviço',
                onTap: () => context.push('/services'),
              ),
              _QuickActionCard(
                      icon: CupertinoIcons.cloud_download,
                label: 'Dropbox',
                onTap: () => context.push('/providers'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection() {
    final theme = Theme.of(context);
    final authNotifier = ref.watch(authNotifierProvider);
    final bool passwordHasBeenChanged = authNotifier.initialPasswordChanged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notificações',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 16),
        Consumer(
          builder: (context, ref, child) {
            final notificationsStream = ref.watch(userNotificationsProvider);
            final notificationActions = ref.read(notificationActionsProvider);

            return notificationsStream.when(
              data: (notificationsFromProvider) {
                List<UserNotification> combinedNotifications = [...notificationsFromProvider];
                final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
                if (!passwordHasBeenChanged) {
                  final passwordReminder = UserNotification(
                    id: '__password_reminder__', userId: currentUserId,
                    title: 'Security Recommendation', message: 'Change your initial password.',
                    type: NotificationType.system, createdAt: DateTime.now(), isRead: true,
                    metadata: { 'isPasswordReminder': true },
                  );
                  combinedNotifications.insert(0, passwordReminder);
                }

                if (combinedNotifications.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Icon(CupertinoIcons.bell_slash, size: 48, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text('Sem notificações', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)))
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: combinedNotifications.length,
                  itemBuilder: (context, index) {
                    final notification = combinedNotifications[index];
                    return SimpleListItem(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getNotificationIconColor(notification, theme).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_getNotificationIconData(notification), color: _getNotificationIconColor(notification, theme), size: 18),
                      ),
                      title: notification.title,
                      subtitle: notification.metadata['clientName']?.toString() ?? notification.message,
                      trailing: Text(
                        _getNotificationDateString(notification),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      isUnread: !notification.isRead,
                      onTap: () => _handleNotificationTap(notification, notificationActions),
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(child: Text('Falha ao carregar notificações', style: TextStyle(color: theme.colorScheme.error))),
            );
          },
        ),
      ],
    );
  }

  // Helper methods for notification icon and color
  IconData _getNotificationIconData(UserNotification notification) {
    switch (notification.type) {
      case NotificationType.statusChange:
        final status = notification.metadata['newStatus'] as String? ?? '';
        if (status == 'approved') {
          return Icons.swap_horiz_rounded;
        } else if (status == 'rejected') {
          return Icons.warning_amber_rounded;
        } else {
          return Icons.swap_horiz_rounded;
        }
      case NotificationType.rejection:
        return Icons.warning_amber_rounded;
      case NotificationType.payment:
        return Icons.payments_rounded;
      case NotificationType.system:
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationIconColor(UserNotification notification, ThemeData theme) {
    switch (notification.type) {
      case NotificationType.statusChange:
        final status = notification.metadata['newStatus'] as String? ?? '';
        if (status == 'approved') {
          return theme.colorScheme.tertiary;
        } else if (status == 'rejected') {
          return theme.colorScheme.error;
        } else {
          return theme.colorScheme.secondary;
        }
      case NotificationType.rejection:
        return theme.colorScheme.error;
      case NotificationType.payment:
        return theme.colorScheme.tertiary;
      case NotificationType.system:
      default:
        return theme.colorScheme.primary;
    }
  }

  String _getNotificationDateString(UserNotification notification) {
    final formatter = DateFormat('dd MMM');
    final timeFormatter = DateFormat('HH:mm');
    final formattedDate = formatter.format(notification.createdAt);
    final formattedTime = timeFormatter.format(notification.createdAt);
    if (notification.createdAt.day == DateTime.now().day) {
      return 'Today, $formattedTime';
    } else {
      return formattedDate;
    }
  }

  // --- Helper method to handle notification tap
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
        // Show the dialog instead of navigation
        showDialog(
          context: context,
          // barrierColor: Colors.black.withOpacity(0.3), // Optional: dim background
          builder: (dialogContext) {
            return RejectionDetailDialog(notification: notification);
          },
        );
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

  Widget _buildCommissionBox() {
    final theme = Theme.of(context);
    final commissionAsync = ref.watch(resellerTotalCommissionProvider);

    return Material(
      color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            decoration: AppStyles.glassCard(context),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                      'Ganhos de Comissão',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isEarningsVisible = !_isEarningsVisible;
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        commissionAsync.when(
                          data: (commissionValue) {
                          final currencyFormat = NumberFormat.currency(locale: 'pt_PT', symbol: '€', decimalDigits: 2);
                          final formattedCommission = currencyFormat.format(commissionValue);
                            return _isEarningsVisible
                              ? Row(children: [Text(formattedCommission, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black.withOpacity(0.2), blurRadius: 3, offset: const Offset(0, 1))])), const SizedBox(width: 10), Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), child: Icon(CupertinoIcons.eye_fill, size: 18, color: Colors.white.withOpacity(0.9)))] )
                                : _buildHiddenAmountRow(theme);
                          },
                        loading: () => _isEarningsVisible ? Row(children: [Text('--,-- €', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.7))), const SizedBox(width: 10), Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), child: Icon(CupertinoIcons.eye_fill, size: 18, color: Colors.white.withOpacity(0.9)))]) : _buildHiddenAmountRow(theme),
                        error: (error, stack) => _isEarningsVisible ? Row(children: [Text('N/A', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.7))), const SizedBox(width: 10), Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), child: Icon(CupertinoIcons.eye_fill, size: 18, color: Colors.white.withOpacity(0.9)))]) : _buildHiddenAmountRow(theme),
                      ),
                    ],
                  ),
                ),
                  const SizedBox(height: 20),
                  SizedBox(
                  height: 40,
                  child: OutlinedButton(
                      onPressed: () => context.push('/dashboard'),
                    style: AppStyles.glassButtonStyle(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        Text('Ver Detalhes'),
                          const SizedBox(width: 4),
                        Icon(CupertinoIcons.chevron_right, size: 12, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper to build the hidden amount row consistently
  Widget _buildHiddenAmountRow(ThemeData theme) {
    return Row(
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
          '€',
          style: theme.textTheme.titleMedium?.copyWith(
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
    );
  }
}

// Auto-Dismiss Dialog Content Widget
class _AutoDismissDialogContent extends StatefulWidget {
  const _AutoDismissDialogContent();

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

// Create a StatefulWidget for _CircleIconButton to manage its own hover state
class _CircleIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isHighlighted; // For existing highlight (e.g. tutorial hint)

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  _CircleIconButtonState createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<_CircleIconButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool actuallyHighlighted = widget.isHighlighted;
    final double scale = _isHovering ? 1.15 : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Transform.scale(
        scale: scale,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(10.0),
            decoration: AppStyles.circularIconButtonStyle(
              context,
              isHovering: _isHovering,
              isHighlighted: actuallyHighlighted,
            ),
            child: Icon(widget.icon,
                color: actuallyHighlighted
                    ? theme.colorScheme.onPrimary
                    : Colors.white,
                size: 22.0),
          ),
        ),
      ),
    );
  }
}
