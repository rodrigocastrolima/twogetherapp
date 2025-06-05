import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carousel_slider/carousel_slider.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';

import '../../../core/theme/ui_styles.dart';
import '../../../features/notifications/presentation/providers/notification_provider.dart';
import '../../../core/models/notification.dart';

import 'package:intl/intl.dart';
import 'dart:async';

import '../../../core/constants/constants.dart';
import '../../../app/router/app_router.dart'; // Import AppRouter to access notifier
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/onboarding/app_tutorial_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- Need SharedPreferences again
import '../../../features/notifications/presentation/widgets/rejection_detail_dialog.dart'; // NEW
import '../../../features/proposal/presentation/providers/proposal_providers.dart';

import '../../../features/notifications/presentation/widgets/unified_notification_item.dart';
import '../../../features/opportunity/presentation/providers/opportunity_providers.dart'; // Add opportunity providers
import '../../widgets/app_loading_indicator.dart'; // Add loading indicator
import '../../../features/salesforce/presentation/providers/salesforce_providers.dart';

import 'five_card_carousel.dart';

// Constants for the highlight area (adjust as needed)
const double _highlightPadding = 8.0;
const double _iconSize = 22.0; // From _buildCircleIconButton
const double _iconPadding = 10.0; // From _buildCircleIconButton
const double _totalIconSpace = (_iconPadding * 2) + _iconSize;
const double _topRightPadding = 20.0; // Horizontal padding from header

// Place this at the top-level, outside of _ResellerHomePageState
class _QuickActionCard extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final String? imageAsset;

  const _QuickActionCard({
    this.icon,
    required this.label,
    required this.onTap,
    this.imageAsset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 160, // Fixed width for carousel consistency
          height: 120, // Fixed height for carousel consistency
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (imageAsset != null)
                Image.asset(
                  imageAsset!,
                  height: 32,
                  fit: BoxFit.contain,
                )
              else if (icon != null)
              Icon(
                icon, 
                size: 32, 
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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

  // Add loading overlay entry for notification navigation
  OverlayEntry? _loadingOverlay;

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

  int _quickActionCarouselIndex = 0;

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
    // Clean up loading overlay if it exists
    _loadingOverlay?.remove();
    _loadingOverlay = null;
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

  // Helper methods for responsive values (excluding padding which stays at 24.0)
  double _getResponsiveSpacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < 600 ? 12.0 : 16.0;
  }

  double _getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final width = MediaQuery.of(context).size.width;
    return width < 600 ? baseFontSize - 2 : baseFontSize;
  }

  bool _isMobileScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  // Helper method to build quick action cards
  List<Widget> _buildQuickActionCards() {
    return [
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
      _QuickActionCard(
        imageAsset: 'assets/images/edp_logo_br.png',
        label: 'Energia Solar',
        onTap: () => context.push('/services?quickAction=edp-solar'),
      ),
      _QuickActionCard(
        imageAsset: 'assets/images/edp_logo_br.png',
        label: 'Energia Comercial',
        onTap: () => context.push('/services?quickAction=edp-comercial'),
      ),
      _QuickActionCard(
        imageAsset: 'assets/images/repsol_logo_br.png',
        label: 'Energia Residencial',
        onTap: () => context.push('/services?quickAction=repsol-residencial'),
      ),
    ];
  }

  // Helper method to build responsive quick actions (carousel on mobile, wrap on desktop)
  Widget _buildQuickActionsResponsive() {
    final isMobile = _isMobileScreen(context);
    final quickActionCards = _buildQuickActionCards();
    if (isMobile) {
      // Use custom FiveCardCarousel for 5-card peeking effect
      return FiveCardCarousel(
        items: quickActionCards.map((card) => Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: card,
        )).toList(),
        height: 140,
        centerScale: 1.0,
        sideScale: 0.8,
        sideOpacity: 0.6,
      );
    } else {
      // Desktop: Keep existing Wrap layout (more space available)
      return Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 0),
        child: Wrap(
          spacing: 24,
          runSpacing: 16,
          children: quickActionCards.map((card) => Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: card,
          )).toList(),
        ),
      );
    }
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
    final theme = Theme.of(context);
    final dashboardStatsAsync = ref.watch(dashboardStatsProvider);
    final opportunitiesAsync = ref.watch(resellerOpportunitiesProvider);
    // Status calculation logic (copied from dashboard_page.dart)
    Map<String, int> _calculateStatusCounts(List opportunities) {
      int active = 0;
      int actionNeeded = 0;
      int pending = 0;
      int rejected = 0;
      for (final opportunity in opportunities) {
        String proposalStatus = '';
        if (opportunity.propostasR?.records != null && opportunity.propostasR!.records.isNotEmpty) {
          proposalStatus = opportunity.propostasR!.records.first.statusC ?? '';
        }
        if (proposalStatus == 'Aceite') {
          active++;
        } else if (["Enviada", "Em Aprovação"].contains(proposalStatus)) {
          actionNeeded++;
        } else if (["Aprovada", "Expirada", "Criação", "Em Análise"].contains(proposalStatus)) {
          pending++;
        } else if (["Não Aprovada", "Cancelada"].contains(proposalStatus)) {
          rejected++;
        }
      }
      return {
        'active': active,
        'actionNeeded': actionNeeded,
        'pending': pending,
        'rejected': rejected,
      };
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        top: false,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Header Row (Profile Icon, Action Icons)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ref.watch(authStateChangesProvider).when(
                      data: (user) => _buildProfileIcon(
                        context,
                        theme,
                        user?.displayName,
                        user?.email,
                      ),
                      loading: () => _buildProfileIconPlaceholder(context, theme),
                      error: (_, __) => _buildProfileIcon(context, theme, null, null),
                    ),
                    Row(
                      children: [
                        Consumer(
                          builder: (context, ref, _) {
                            final notificationsEnabled = ref.watch(pushNotificationSettingsProvider);
                            final notificationSettings = ref.read(pushNotificationSettingsProvider.notifier);
                            return _CircleIconButton(
                              icon: notificationsEnabled ? CupertinoIcons.bell_fill : CupertinoIcons.bell_slash_fill,
                              onTap: () async {
                                await notificationSettings.toggle();
                              },
                              isHighlighted: false,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        ScaleTransition(
                          scale: _helpIconAnimation,
                          child: _CircleIconButton(
                            icon: CupertinoIcons.question_circle,
                            isHighlighted: _isAppActive && ref.watch(authNotifierProvider).isFirstLogin && !_hasSeenHintLocally,
                            onTap: () => _handleHelpIconTap(
                              context,
                              _isAppActive && ref.watch(authNotifierProvider).isFirstLogin && !_hasSeenHintLocally,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Início',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
                            const SizedBox(height: 12),
              // Unified Dashboard Card (Commission + Status)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Consumer(
                  builder: (context, ref, _) {
                    final dashboardStatsAsync = ref.watch(dashboardStatsProvider);
                    final opportunitiesAsync = ref.watch(resellerOpportunitiesProvider);
                    
                    return dashboardStatsAsync.when(
                      data: (stats) {
                        return opportunitiesAsync.when(
                          data: (opps) {
                            final statusCounts = _calculateStatusCounts(opps);
                            return _buildDashboardCard(stats.totalCommission, statusCounts);
                          },
                          loading: () => _buildDashboardCard(
                            stats.totalCommission, 
                            {'active': 0, 'actionNeeded': 0, 'pending': 0, 'rejected': 0},
                            isLoading: true,
                          ),
                          error: (e, _) => _buildDashboardCard(
                            stats.totalCommission, 
                            {'active': 0, 'actionNeeded': 0, 'pending': 0, 'rejected': 0},
                            isError: true,
                          ),
                        );
                      },
                      loading: () => _buildDashboardCard(
                        null, 
                        {'active': 0, 'actionNeeded': 0, 'pending': 0, 'rejected': 0},
                        isLoading: true,
                      ),
                      error: (e, _) => _buildDashboardCard(
                        null, 
                        {'active': 0, 'actionNeeded': 0, 'pending': 0, 'rejected': 0},
                        isError: true,
                      ),
                    );
                  },
                ),
              ),
                            SizedBox(height: _isMobileScreen(context) ? 24 : 40),
              // Quick Actions
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 0),
                        child: Text(
                          'Ações Rápidas',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                            fontSize: _getResponsiveFontSize(context, 24),
                          ),
                        ),
                      ),
                                            SizedBox(height: _getResponsiveSpacing(context) + 4),
                      _buildQuickActionsResponsive(),
                                    SizedBox(height: _isMobileScreen(context) ? 24 : 40),
              // Notifications
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 0),
                        child: Text(
                          'Notificações',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                            fontSize: _getResponsiveFontSize(context, 24),
                          ),
                        ),
                      ),
                      SizedBox(height: _getResponsiveSpacing(context) + 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildNotificationsSection(),
              ),
            ],
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

  Widget _buildNotificationsSection() {
    final theme = Theme.of(context);
    final authNotifier = ref.watch(authNotifierProvider);
    final bool passwordHasBeenChanged = authNotifier.initialPasswordChanged;

    return Consumer(
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
                  padding: const EdgeInsets.symmetric(vertical: 48.0),
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
                
                // Handle password reminder with special case
                if (notification.id == '__password_reminder__') {
                  return UnifiedNotificationItem(
                    notification: notification,
                    onTap: () => _handleNotificationTap(notification, notificationActions),
                    onDelete: () => notificationActions.deleteNotification(notification.id),
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  );
                }
                
                // Use unified component for regular notifications
                return UnifiedNotificationItem(
                  notification: notification,
                  onTap: () => _handleNotificationTap(notification, notificationActions),
                  onDelete: () => notificationActions.deleteNotification(notification.id),
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(child: Text('Falha ao carregar notificações', style: TextStyle(color: theme.colorScheme.error))),
        );
      },
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
        // Check if this is a contract insertion, proposal expired, or document review notification
        final processType = notification.metadata['processType'] as String?;
        if (processType == 'contract_insertion' || processType == 'proposal_expired' || processType == 'document_review') {
          final opportunityId = notification.metadata['opportunityId'] as String?;
          if (opportunityId != null) {
            // Show loading overlay over entire app
            _loadingOverlay = OverlayEntry(
              builder: (context) => const AppLoadingIndicator(),
            );
            Overlay.of(context, rootOverlay: true).insert(_loadingOverlay!);
            
            // Get the opportunity data to navigate to details page
            try {
              final opportunitiesAsync = ref.read(resellerOpportunitiesProvider);
              final opportunities = opportunitiesAsync.value;
              
              if (opportunities != null) {
                final opportunity = opportunities.firstWhere(
                  (opp) => opp.id == opportunityId,
                  orElse: () => throw Exception('Opportunity not found'),
                );
                // Remove loading overlay and navigate
                if (mounted) {
                  _loadingOverlay?.remove();
                  _loadingOverlay = null;
                  context.push('/opportunity-details', extra: opportunity);
                }
              } else {
                // If opportunities haven't loaded yet, refresh and wait
                ref.refresh(resellerOpportunitiesProvider);
                final refreshedOpportunities = await ref.read(resellerOpportunitiesProvider.future);
                final opportunity = refreshedOpportunities.firstWhere(
                  (opp) => opp.id == opportunityId,
                  orElse: () => throw Exception('Opportunity not found'),
                );
                // Remove loading overlay and navigate
                if (mounted) {
                  _loadingOverlay?.remove();
                  _loadingOverlay = null;
                  context.push('/opportunity-details', extra: opportunity);
                }
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error navigating to opportunity details: $e');
              }
              // Remove loading overlay and show error
              if (mounted) {
                _loadingOverlay?.remove();
                _loadingOverlay = null;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao abrir detalhes da oportunidade: $e')),
                );
              }
            }
          }
        } else if (notification.metadata.containsKey('submissionId')) {
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

    // --- Unified Dashboard Card combining Commission + Status ---
  Widget _buildDashboardCard(double? commissionValue, Map<String, int> statusCounts, {bool isLoading = false, bool isError = false}) {
    final theme = Theme.of(context);
    final isMobile = _isMobileScreen(context);
    final spacing = _getResponsiveSpacing(context);
    
    String displayValue;
    if (isLoading) {
      displayValue = '...';
    } else if (isError) {
      displayValue = 'Erro';
    } else if (!_isEarningsVisible) {
      displayValue = '••••••';
    } else {
      displayValue = commissionValue != null ? '€ ${commissionValue.toStringAsFixed(2)}' : '€ 0.00';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: AppStyles.standardBlur,
        child: Container(
          width: double.infinity,
          decoration: AppStyles.glassCard(context),
          padding: EdgeInsets.symmetric(vertical: isMobile ? 20 : 28, horizontal: 24),
          child: Column(
            children: [
              // Commission Section (Top)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comissão Total',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            fontSize: _getResponsiveFontSize(context, 16),
                          ),
                        ),
                        SizedBox(height: spacing / 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayValue,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                  fontSize: _getResponsiveFontSize(context, 28),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: Icon(
                                _isEarningsVisible ? Icons.visibility : Icons.visibility_off, 
                                color: theme.colorScheme.onSurfaceVariant,
                                size: isMobile ? 20 : 24,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isEarningsVisible = !_isEarningsVisible;
                                });
                              },
                              tooltip: _isEarningsVisible ? 'Ocultar comissão' : 'Mostrar comissão',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right, 
                      color: theme.colorScheme.primary, 
                      size: isMobile ? 28 : 36,
                    ),
                    onPressed: () {
                      // TODO: Navigate to details page
                    },
                    tooltip: 'Ver detalhes',
                  ),
                ],
              ),
              SizedBox(height: spacing + 8),
              // Status Section (Bottom)
              _buildStatusGrid(statusCounts, isMobile, spacing),
            ],
          ),
        ),
      ),
    );
  }

  // --- Status Grid for Dashboard Card ---
  Widget _buildStatusGrid(Map<String, int> statusCounts, bool isMobile, double spacing) {
    final theme = Theme.of(context);
    
    final List<Widget> statusItems = [
      _buildCompactStatusItem(
        label: 'Ativos',
        count: statusCounts['active'] ?? 0,
        color: Colors.green,
        icon: CupertinoIcons.checkmark_seal_fill,
        isMobile: isMobile,
      ),
      _buildCompactStatusItem(
        label: 'Ação Necessária',
        count: statusCounts['actionNeeded'] ?? 0,
        color: Colors.blue,
        icon: CupertinoIcons.exclamationmark_circle_fill,
        isMobile: isMobile,
      ),
      _buildCompactStatusItem(
        label: 'Pendentes',
        count: statusCounts['pending'] ?? 0,
        color: Colors.orange,
        icon: CupertinoIcons.clock_fill,
        isMobile: isMobile,
      ),
      _buildCompactStatusItem(
        label: 'Rejeitados',
        count: statusCounts['rejected'] ?? 0,
        color: Colors.red,
        icon: CupertinoIcons.xmark_seal_fill,
        isMobile: isMobile,
      ),
    ];

    if (isMobile) {
      // 2x2 grid on mobile
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: statusItems[0]),
              SizedBox(width: spacing),
              Expanded(child: statusItems[1]),
            ],
          ),
          SizedBox(height: spacing),
          Row(
            children: [
              Expanded(child: statusItems[2]),
              SizedBox(width: spacing),
              Expanded(child: statusItems[3]),
            ],
          ),
        ],
      );
    } else {
      // 1x4 row on desktop
      return Row(
        children: [
          for (int i = 0; i < statusItems.length; i++) ...[
            Expanded(child: statusItems[i]),
            if (i < statusItems.length - 1) SizedBox(width: spacing),
          ],
        ],
      );
    }
  }

  // --- Compact Status Item for Dashboard Card ---
  Widget _buildCompactStatusItem({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required bool isMobile,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 8 : 12,
        horizontal: isMobile ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.08).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withAlpha((255 * 0.2).round()),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: isMobile ? 16 : 18,
          ),
          SizedBox(width: isMobile ? 4 : 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: isMobile ? 10 : 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredStat(BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          icon,
          size: 48,
          color: color,
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
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
