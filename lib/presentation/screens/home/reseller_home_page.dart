import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';

import '../../../core/theme/ui_styles.dart';
import '../../../features/notifications/presentation/providers/notification_provider.dart';

import 'package:intl/intl.dart';
import 'dart:async';

import '../../../core/constants/constants.dart';
import '../../../app/router/app_router.dart'; // Import AppRouter to access notifier
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/onboarding/app_tutorial_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- Need SharedPreferences again

import '../../../features/proposal/presentation/providers/proposal_providers.dart';

import '../../../features/opportunity/presentation/providers/opportunity_providers.dart'; // Add opportunity providers
import '../../../features/salesforce/presentation/providers/salesforce_providers.dart';

import 'five_card_carousel.dart';
import '../../widgets/notification_dropdown.dart';

// Constants for the highlight area (adjust as needed)
const double _highlightPadding = 8.0;
const double _iconSize = 22.0; // From _buildCircleIconButton
const double _iconPadding = 10.0; // From _buildCircleIconButton
const double _totalIconSpace = (_iconPadding * 2) + _iconSize;
const double _topRightPadding = 20.0; // Horizontal padding from header

// Data class for status items
class _StatusData {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatusData({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });
}

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
  bool _isEarningsVisible = false;
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

  // --- Removed hover states since we're using Material cards now ---

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

  // Helper method to build responsive quick actions (grid layout showing all buttons)
  Widget _buildQuickActionsResponsive() {
    final isMobile = _isMobileScreen(context);
    
    if (isMobile) {
      // Mobile: Show all 5 buttons in a 3-2 grid layout
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // First row - 3 buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCompactQuickActionButton(
              icon: CupertinoIcons.add_circled_solid,
              label: 'Novo Serviço',
              onTap: () => context.push('/services'),
            ),
            _buildCompactQuickActionButton(
              icon: CupertinoIcons.cloud_download,
              label: 'Dropbox',
              onTap: () => context.push('/providers'),
            ),
            _buildCompactQuickActionButton(
              imageAsset: 'assets/images/edp_logo_br.png',
              label: 'Energia Solar',
              onTap: () => context.push('/services?quickAction=edp-solar'),
            ),
              ],
            ),
            const SizedBox(height: 20),
            // Second row - 2 buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
            _buildCompactQuickActionButton(
              imageAsset: 'assets/images/edp_logo_br.png',
              label: 'Energia Comercial',
              onTap: () => context.push('/services?quickAction=edp-comercial'),
            ),
            _buildCompactQuickActionButton(
              imageAsset: 'assets/images/repsol_logo_br.png',
              label: 'Energia Residencial',
              onTap: () => context.push('/services?quickAction=repsol-residencial'),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // Desktop: Keep existing layout with cards
      final quickActionCards = _buildQuickActionCards();
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

  // Helper method to build compact quick action buttons (bigger and better looking)
  Widget _buildCompactQuickActionButton({
    IconData? icon,
    String? imageAsset,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return SizedBox(
      width: 80, // Bigger width
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Enhanced container with better styling
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20), // More rounded
              border: Border.all(
                color: theme.colorScheme.outline.withAlpha((255 * 0.1).round()),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((255 * 0.05).round()),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                child: Center(
                  child: imageAsset != null
                      ? Image.asset(
                          imageAsset,
                          height: 32,
                          width: 32,
                          fit: BoxFit.contain,
                        )
                      : Icon(
                          icon,
                          size: 32,
                          color: theme.colorScheme.onSurface,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Better label text
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
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
    final isMobile = _isMobileScreen(context);
    final dashboardStatsAsync = ref.watch(dashboardStatsProvider);
    final opportunitiesAsync = ref.watch(resellerOpportunitiesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: SafeArea(
        bottom: false,
        top: false,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isMobile) ...[
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
                              final unreadCount = ref.watch(unreadNotificationsCountProvider);
                              
                              return _buildNotificationBell(
                                context,
                                unreadCount: unreadCount.value ?? 0,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          ScaleTransition(
                            scale: _helpIconAnimation,
                            child: _buildMaterialIconButton(
                              icon: CupertinoIcons.question_circle,
                              onTap: () => _handleHelpIconTap(
                                context,
                                _isAppActive && ref.watch(authNotifierProvider).isFirstLogin && !_hasSeenHintLocally,
                              ),
                              isHighlighted: _isAppActive && ref.watch(authNotifierProvider).isFirstLogin && !_hasSeenHintLocally,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
              // Title (for desktop)
              if (!isMobile)
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
              if (!isMobile) const SizedBox(height: 12),
              // Add small top padding for mobile to prevent touching app bar
              if (isMobile) const SizedBox(height: 8),
              // Welcome Section
              ref.watch(authStateChangesProvider).when(
                  data: (user) => _buildWelcomeSection(context, user?.displayName),
                  loading: () => _buildWelcomeSectionPlaceholder(context),
                  error: (_, __) => _buildWelcomeSection(context, null),
              ),
              SizedBox(height: _isMobileScreen(context) ? 24 : 32),
              // Status Cards Section
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 0),
                child: Text(
                  'Estado dos Clientes',
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
                child: Consumer(
                  builder: (context, ref, _) {
                    final opportunitiesAsync = ref.watch(resellerOpportunitiesProvider);
                    return opportunitiesAsync.when(
                      data: (opps) {
                        final statusCounts = _calculateStatusCounts(opps);
                        return _buildStatusGrid(statusCounts, _isMobileScreen(context), _getResponsiveSpacing(context));
                      },
                      loading: () => _buildStatusGrid(
                        {'active': 0, 'actionNeeded': 0, 'pending': 0, 'rejected': 0},
                        _isMobileScreen(context),
                        _getResponsiveSpacing(context),
                      ),
                      error: (e, _) => _buildStatusGrid(
                        {'active': 0, 'actionNeeded': 0, 'pending': 0, 'rejected': 0},
                        _isMobileScreen(context),
                        _getResponsiveSpacing(context),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: _isMobileScreen(context) ? 16 : 40),
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
              SizedBox(height: _isMobileScreen(context) ? 32 : 40),
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
    return _buildMaterialIconButton(
      onTap: () => context.push('/profile-details'),
      child: Text(
        _getUserInitials(displayName, email),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  // --- Helper for Material Icon Button ---
  Widget _buildMaterialIconButton({
    IconData? icon,
    Widget? child,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: isHighlighted ? BoxDecoration(
          color: theme.colorScheme.primary.withAlpha((255 * 0.1).round()),
          shape: BoxShape.circle,
        ) : null,
        child: Center(
          child: child ?? Icon(
            icon,
            size: 24,
            color: isHighlighted 
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  // --- Helper for Profile Icon Placeholder ---
  Widget _buildProfileIconPlaceholder(BuildContext context, ThemeData theme) {
    return _buildMaterialIconButton(
      onTap: () {}, // No action while loading
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          color: theme.colorScheme.primary,
          strokeWidth: 2,
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

  // --- Helper for Welcome + Commission Section ---
  Widget _buildWelcomeSection(BuildContext context, String? displayName) {
    final theme = Theme.of(context);
    final isMobile = _isMobileScreen(context);
    
    // Extract name from display name
    String userName = 'Utilizador';
    if (displayName != null && displayName.isNotEmpty) {
      userName = displayName;
    }
    
    return Consumer(
      builder: (context, ref, _) {
        final dashboardStatsAsync = ref.watch(dashboardStatsProvider);
        return dashboardStatsAsync.when(
          data: (stats) => _buildWelcomeWithCommission(context, userName, stats.totalCommission),
          loading: () => _buildWelcomeWithCommission(context, userName, null, isLoading: true),
          error: (e, _) => _buildWelcomeWithCommission(context, userName, null, isError: true),
        );
      },
    );
  }

  Widget _buildWelcomeWithCommission(BuildContext context, String userName, double? commissionValue, {bool isLoading = false, bool isError = false}) {
    final theme = Theme.of(context);
    final isMobile = _isMobileScreen(context);
    
    String displayValue;
    if (isLoading) {
      displayValue = '...';
    } else if (isError) {
      displayValue = 'Erro';
    } else {
      displayValue = commissionValue != null ? '€ ${commissionValue.toStringAsFixed(2)}' : '€ 0.00';
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha((255 * 0.1).round()),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).round()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile section - centered
          Column(
            children: [
              // Profile avatar
          Container(
            width: isMobile ? 80 : 90,
            height: isMobile ? 80 : 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withAlpha((255 * 0.1).round()),
              border: Border.all(
                color: theme.colorScheme.primary.withAlpha((255 * 0.2).round()),
                width: 2,
              ),
            ),
            child: Icon(
              CupertinoIcons.person_fill,
              size: isMobile ? 40 : 45,
              color: theme.colorScheme.primary,
            ),
          ),
              const SizedBox(height: 16),
              // User name
          Text(
            userName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
                  fontSize: isMobile ? 20 : 24,
            ),
            textAlign: TextAlign.center,
          ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Commission section - simplified
          Material(
            color: Colors.transparent,
            child: InkWell(
            onTap: () {
              setState(() {
                _isEarningsVisible = !_isEarningsVisible;
              });
            },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comissão Total',
                      style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                        SizedBox(
                          width: 80, // Fixed width to prevent shifting
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                          _isEarningsVisible ? displayValue : '••••••',
                              key: ValueKey(_isEarningsVisible),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                            color: _isEarningsVisible ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                            letterSpacing: _isEarningsVisible ? 0 : 2,
                          ),
                              textAlign: TextAlign.right,
                        ),
                    ),
                        ),
                        const SizedBox(width: 8),
                    Icon(
                          _isEarningsVisible ? CupertinoIcons.eye_fill : CupertinoIcons.eye_slash_fill,
                          size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper for Welcome Section Placeholder ---
  Widget _buildWelcomeSectionPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = _isMobileScreen(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha((255 * 0.1).round()),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).round()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile section placeholder
          Row(
            children: [
              // Profile avatar placeholder
          Container(
                width: isMobile ? 64 : 72,
                height: isMobile ? 64 : 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainerHighest,
            ),
                child: const SizedBox(
              width: 20,
              height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              const SizedBox(width: 16),
              // User info placeholder
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
          Container(
                      width: 140,
                      height: 16,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
            ),
          ),
                    const SizedBox(height: 8),
          Container(
                      width: 100,
                      height: 20,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  theme.colorScheme.outline.withAlpha((255 * 0.2).round()),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Commission section placeholder
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha((255 * 0.3).round()),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withAlpha((255 * 0.1).round()),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Commission icon placeholder
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Commission info placeholder
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 14,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 80,
                        height: 16,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Toggle button placeholder
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }









  // --- Status Grid for Dashboard Card (2x2 Layout) ---
  Widget _buildStatus2x2Grid(Map<String, int> statusCounts, bool isMobile, double spacing) {
    final statusItems = [
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

    return Column(
      children: [
        // First row (Ativos, Ação Necessária)
        Row(
          children: [
            Expanded(child: statusItems[0]),
            SizedBox(width: spacing / 2),
            Expanded(child: statusItems[1]),
          ],
        ),
        SizedBox(height: spacing / 2),
        // Second row (Pendentes, Rejeitados)
        Row(
          children: [
            Expanded(child: statusItems[2]),
            SizedBox(width: spacing / 2),
            Expanded(child: statusItems[3]),
          ],
        ),
      ],
    );
  }

  // --- Status Grid for Dashboard Card (2x2 Layout with animations) ---
  Widget _buildStatusGrid(Map<String, int> statusCounts, bool isMobile, double spacing) {
    final statusItems = [
      _StatusData(
        label: 'Ativos',
        count: statusCounts['active'] ?? 0,
        color: Colors.green[700]!,
        icon: Icons.check_circle,
      ),
      _StatusData(
        label: 'Ação Necessária',
        count: statusCounts['actionNeeded'] ?? 0,
        color: Colors.blue[700]!,
        icon: Icons.pending_actions,
      ),
      _StatusData(
        label: 'Pendentes',
        count: statusCounts['pending'] ?? 0,
        color: Colors.orange[700]!,
        icon: Icons.schedule,
      ),
      _StatusData(
        label: 'Rejeitados',
        count: statusCounts['rejected'] ?? 0,
        color: Colors.red[700]!,
        icon: Icons.cancel,
      ),
    ];

    return AnimationLimiter(
      child: Column(
        children: [
          // First row
          Row(
            children: [
            Expanded(
              child: AnimationConfiguration.staggeredList(
                  position: 0,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 30.0,
                  child: FadeInAnimation(
                    child: _buildCompactStatusItem(
                        label: statusItems[0].label,
                        count: statusItems[0].count,
                        color: statusItems[0].color,
                        icon: statusItems[0].icon,
                      isMobile: isMobile,
                      statusKey: 'active',
                    ),
                  ),
                ),
              ),
            ),
              SizedBox(width: spacing),
              Expanded(
                child: AnimationConfiguration.staggeredList(
                  position: 1,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 30.0,
                    child: FadeInAnimation(
                      child: _buildCompactStatusItem(
                        label: statusItems[1].label,
                        count: statusItems[1].count,
                        color: statusItems[1].color,
                        icon: statusItems[1].icon,
                        isMobile: isMobile,
                        statusKey: 'actionNeeded',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing),
          // Second row
          Row(
            children: [
              Expanded(
                child: AnimationConfiguration.staggeredList(
                  position: 2,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 30.0,
                    child: FadeInAnimation(
                      child: _buildCompactStatusItem(
                        label: statusItems[2].label,
                        count: statusItems[2].count,
                        color: statusItems[2].color,
                        icon: statusItems[2].icon,
                        isMobile: isMobile,
                        statusKey: 'pending',
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: AnimationConfiguration.staggeredList(
                  position: 3,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 30.0,
                    child: FadeInAnimation(
                      child: _buildCompactStatusItem(
                        label: statusItems[3].label,
                        count: statusItems[3].count,
                        color: statusItems[3].color,
                        icon: statusItems[3].icon,
                        isMobile: isMobile,
                        statusKey: 'rejected',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Compact Status Item for Dashboard Card ---
  Widget _buildCompactStatusItem({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required bool isMobile,
    String? statusKey,
  }) {
    final theme = Theme.of(context);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToOpportunityPageWithFilter(statusKey),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withAlpha((255 * 0.1).round()),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((255 * 0.05).round()),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: isMobile ? 20 : 24,
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Text(
                count.toString(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontSize: isMobile ? 16 : 18,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
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

  // Navigation helper method
  void _navigateToOpportunityPageWithFilter(String? statusKey) {
    if (statusKey == null) return;
    
    // Map status keys to the filter values expected by the opportunity page
    String filterValue;
    switch (statusKey) {
      case 'active':
        filterValue = 'ativos';
        break;
      case 'actionNeeded':
        filterValue = 'acaoNecessaria';
        break;
      case 'pending':
        filterValue = 'pendentes';
        break;
      case 'rejected':
        filterValue = 'rejeitados';
        break;
      default:
        filterValue = 'todos';
    }
    
    context.go('/clients?filter=$filterValue');
  }

  // --- Helper for Notification Bell with Dropdown ---
  Widget _buildNotificationBell(BuildContext context, {required int unreadCount}) {
    return _buildMaterialIconButton(
      icon: CupertinoIcons.bell_fill,
      onTap: () => _showNotificationDropdown(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            CupertinoIcons.bell_fill,
            size: 24,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          if (unreadCount > 0)
            Positioned(
              top: -5,
              right: -8,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFBE45),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Show Notification Dropdown ---
  void _showNotificationDropdown(BuildContext context) {
    // Calculate dropdown position relative to screen, not the render box
    final screenSize = MediaQuery.of(context).size;
    
    // Calculate dropdown position
    final dropdownWidth = 350.0;
    final dropdownMaxHeight = 400.0;
    
    // Position dropdown at top right, closer to bell icon
    final right = 24.0; // Same padding as AppBar actions
    final top = 50.0; // AppBar height (56) + 4px spacing - closer to bell
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Stack(
          children: [
            // Transparent barrier that closes dropdown when tapped
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),
            // Dropdown positioned
            Positioned(
              top: top,
              right: right,
              child: Material(
                color: Colors.transparent,
                child: NotificationDropdown(
                  onClose: () => Navigator.of(dialogContext).pop(),
                  width: dropdownWidth,
                  maxHeight: dropdownMaxHeight,
                ),
              ),
            ),
          ],
        );
      },
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


