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
import '../../../core/models/service_submission.dart';
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

  // --- Hover States for Icons ---
  bool _isProfileHovering = false;
  // For Notification and Help icons, hover state will be managed within _buildCircleIconButton
  // or we might need to pass hover callbacks if preferred.
  // For now, let's aim to make _buildCircleIconButton stateful if it's simple enough,
  // or pass hover state down.
  // Let's make _buildCircleIconButton a StatefulWidget to manage its own hover.
  // --------------------------

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
    // Refresh providers instead of just toggling visibility
    ref.refresh(resellerTotalCommissionProvider);
    ref.refresh(userNotificationsProvider);

    // The UI will update automatically when the providers rebuild.
    // No need for setState or explicit waiting here unless desired for indicator duration.

    // Optional: Simulate a minimum duration for the refresh indicator if needed
    // await Future.delayed(const Duration(milliseconds: 500));
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

  @override
  Widget build(BuildContext context) {
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
                                      // SEARCH ICON REMOVED
                                      // _buildCircleIconButton(
                                      //   icon: CupertinoIcons.search,
                                      //   onTap: () {
                                      //     /* TODO */
                                      //   },
                                      //   isHighlighted: false,
                                      // ),
                                      // const SizedBox(width: 10), // REMOVED
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
                                              shouldAnimate, // For hint pulse border/bg
                                          onTap:
                                              () => _handleHelpIconTap(
                                                context,
                                                shouldAnimate,
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
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
                  // Use theme background color here
                  color: theme.colorScheme.background,
                  padding: const EdgeInsets.only(
                    top: 20,
                    bottom: 60,
                  ), // Adjust padding as needed
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildQuickActionsSection(),
                      ),
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildNotificationsSection(),
                      ),
                      const SizedBox(
                        height: 40,
                      ), // Ensure enough space at bottom
                    ],
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
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.2),
              shape: BoxShape.circle,
              boxShadow:
                  _isProfileHovering
                      ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                      : null,
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
    bool shouldAnimate,
  ) async {
    if (shouldAnimate) {
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
    // Use LayoutBuilder for responsiveness if buttons might wrap
    return LayoutBuilder(
      builder: (context, constraints) {
        bool useColumn = constraints.maxWidth < 380; // Example breakpoint

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ações Rápidas',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 16),
            useColumn
                ? Column(
                  // Vertical layout for smaller screens
                  children: [
                    _buildQuickActionButton(
                      theme: theme,
                      text: 'Criar Novo Serviço',
                      icon: CupertinoIcons.add_circled,
                      gradientColors: [
                        AppTheme.primary,
                        Color.lerp(AppTheme.primary, Colors.blue, 0.4) ??
                            AppTheme.primary,
                      ],
                      onPressed: () => context.push('/services'),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActionButton(
                      theme: theme,
                      text: "Recursos Fornecedor", // TODO: l10n
                      icon: CupertinoIcons.folder_fill,
                      gradientColors: [
                        Colors.deepPurple.shade400,
                        Colors.deepPurple.shade600,
                      ],
                      onPressed:
                          () => context.push('/providers'), // Use reseller path
                    ),
                  ],
                )
                : Row(
                  // Horizontal layout for larger screens
                  children: [
                    Expanded(
                      child: _buildQuickActionButton(
                        theme: theme,
                        text: 'Criar Novo Serviço',
                        icon: CupertinoIcons.add_circled,
                        gradientColors: [
                          AppTheme.primary,
                          Color.lerp(AppTheme.primary, Colors.blue, 0.4) ??
                              AppTheme.primary,
                        ],
                        onPressed: () => context.push('/services'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionButton(
                        theme: theme,
                        text: "Recursos Fornecedor", // TODO: l10n
                        icon: CupertinoIcons.folder_fill,
                        gradientColors: [
                          Colors.deepPurple.shade400,
                          Colors.deepPurple.shade600,
                        ],
                        onPressed:
                            () =>
                                context.push('/providers'), // Use reseller path
                      ),
                    ),
                  ],
                ),
          ],
        );
      },
    );
  }

  // --- NEW Helper for Quick Action Button --- //
  Widget _buildQuickActionButton({
    required ThemeData theme,
    required String text,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      child: ElevatedButton(
        onPressed: onPressed,
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
              colors: gradientColors,
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
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  text,
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
    );
  }

  Widget _buildNotificationsSection() {
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
              'Notificações',
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
        const SizedBox(height: 8),

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
                      'Falha ao carregar notificações',
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
                            'Sem notificações',
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

                // Build list using ListView.builder
                return ListView.builder(
                  shrinkWrap:
                      true, // Prevent infinite height error in Column/ScrollView
                  physics:
                      const NeverScrollableScrollPhysics(), // Prevent nested scrolling
                  itemCount: combinedNotifications.length,
                  itemBuilder: (context, index) {
                    final notification = combinedNotifications[index];
                    return _buildNotificationItem(
                      notification: notification,
                      onTap: () {
                        _handleNotificationTap(
                          notification,
                          notificationActions,
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (_, __) => Center(
                    child: Text(
                      'Falha ao carregar notificações',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
            );
          },
        ),
      ],
    );
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
        icon = Icons.swap_horiz_rounded;
        final status = notification.metadata['newStatus'] as String? ?? '';
        if (status == 'approved') {
          iconColor = theme.colorScheme.tertiary;
        } else if (status == 'rejected') {
          iconColor = theme.colorScheme.error;
        } else {
          iconColor = theme.colorScheme.secondary;
        }
        break;
      case NotificationType.rejection:
        icon = Icons.warning_amber_rounded;
        iconColor = theme.colorScheme.error;
        break;
      case NotificationType.payment:
        icon = Icons.payments_rounded;
        iconColor = theme.colorScheme.tertiary;
        break;
      case NotificationType.system:
      default:
        icon = Icons.notifications;
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
                        notification.metadata['clientName']?.toString() ??
                            notification.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommissionBox() {
    final theme = Theme.of(context);
    // Watch the commission provider
    final commissionAsync = ref.watch(resellerTotalCommissionProvider);

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          // Keep only border, shadow, and radius
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
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
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
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
                      'Ganhos de Comissão',
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
                        // Amount section - Use commissionAsync.when
                        commissionAsync.when(
                          data: (commissionValue) {
                            // Format the commission value
                            final currencyFormat = NumberFormat.currency(
                              locale: 'pt_PT',
                              symbol: '€',
                              decimalDigits: 2,
                            );
                            final formattedCommission = currencyFormat.format(
                              commissionValue,
                            );

                            return _isEarningsVisible
                                ? Row(
                                  children: [
                                    Text(
                                      formattedCommission, // Display formatted value
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
                                    // Removed currency symbol text as it's in the format
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
                                : _buildHiddenAmountRow(theme);
                          },
                          loading:
                              () =>
                                  // Show placeholder while loading
                                  _isEarningsVisible
                                      ? Row(
                                        children: [
                                          Text(
                                            '--,-- €', // Loading placeholder
                                            style: theme.textTheme.headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white
                                                      .withOpacity(0.7),
                                                ),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.1,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              CupertinoIcons.eye_fill,
                                              size: 18,
                                              color: Colors.white.withOpacity(
                                                0.9,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                      : _buildHiddenAmountRow(theme),
                          error:
                              (error, stack) =>
                                  // Show N/A on error
                                  _isEarningsVisible
                                      ? Row(
                                        children: [
                                          Text(
                                            'N/A', // Error placeholder
                                            style: theme.textTheme.headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white
                                                      .withOpacity(0.7),
                                                ),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.1,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              CupertinoIcons.eye_fill,
                                              size: 18,
                                              color: Colors.white.withOpacity(
                                                0.9,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                      : _buildHiddenAmountRow(theme),
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
                            'Ver Detalhes',
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
    // Determine actual highlight based on prop or hover (prop takes precedence for color)
    final bool actuallyHighlighted = widget.isHighlighted;

    final bgColor =
        actuallyHighlighted
            ? theme.colorScheme.primary.withOpacity(0.85)
            : _isHovering
            ? theme.colorScheme.surface.withOpacity(
              0.3,
            ) // Slightly more opaque on hover
            : theme.colorScheme.surface.withOpacity(0.15);

    final iconColor =
        actuallyHighlighted ? theme.colorScheme.onPrimary : Colors.white;

    final borderColor =
        actuallyHighlighted
            ? theme.colorScheme.primary
            : _isHovering
            ? Colors.white.withOpacity(0.3) // Brighter border on hover
            : Colors.white.withOpacity(0.1);

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
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      actuallyHighlighted
                          ? theme.colorScheme.primary.withOpacity(0.3)
                          : _isHovering
                          ? Colors.black.withOpacity(
                            0.2,
                          ) // Stronger shadow on hover
                          : Colors.black.withOpacity(0.1),
                  blurRadius:
                      _isHovering ? 6 : 4, // Slightly larger blur on hover
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: Icon(widget.icon, color: iconColor, size: 22.0),
          ),
        ),
      ),
    );
  }
}
