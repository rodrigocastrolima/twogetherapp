import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/app_colors.dart';

import '../../features/chat/presentation/providers/chat_provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ui_styles.dart';
import '../widgets/logo.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/notifications/presentation/providers/notification_provider.dart';
import '../../core/constants/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/onboarding/app_tutorial_screen.dart';
import '../widgets/notification_dropdown.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  final int currentIndex;
  final String location;

  const MainLayout({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.location,
  });

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isTransitioning = false;
  late AnimationController _helpIconAnimationController;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex;
    
    // Initialize animation controller for help icon
    _helpIconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void didUpdateWidget(MainLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex ||
        oldWidget.location != widget.location) {
      setState(() {
        _selectedIndex = widget.currentIndex;
        _isTransitioning = false;
      });
    }
  }

  @override
  void dispose() {
    _helpIconAnimationController.dispose();
    super.dispose();
  }

  void _handleNavigation(int index) {
    if (_selectedIndex != index && !_isTransitioning) {
      setState(() {
        _isTransitioning = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        switch (index) {
          case 0:
            context.go('/');
            break;
          case 1:
            context.go('/clients');
            break;
          case 2:
            context.go('/messages');
            break;
          case 3:
            context.go('/settings');
            break;
        }
        // Check if mounted before setting state
        if (mounted) {
          setState(() {
            _selectedIndex = index;
            _isTransitioning = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 600; // Threshold for mobile/desktop

    // Determine the effective background color based on the selected index
    final bool isHomePage = _selectedIndex == 0;
    final Color effectiveBackgroundColor = isHomePage 
        ? theme.scaffoldBackgroundColor // For home page, allows ResellerHomePage to control its specific background layers
        : theme.scaffoldBackgroundColor; // For other pages, use the scaffold background

    final bool showNavigation =
        widget.location != '/change-password'; // Renamed for clarity

    return Scaffold(
      backgroundColor: effectiveBackgroundColor, // Use effective background color
      extendBodyBehindAppBar:
          true, // Keep for homepage transparent app bar effect
      extendBody: true, // Keep for homepage transparent app bar effect
      appBar:
          (isSmallScreen && showNavigation)
              ? _buildMobileAppBar(context, theme)
              : null,
      body: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor, // Use scaffold background color for consistency
        ), // Ensure full background coverage
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              _buildMainContent(isSmallScreen, showNavigation, theme, effectiveBackgroundColor),
              if (!isSmallScreen && showNavigation)
                _buildDesktopSidebar(
                  context,
                  isDark,
                  _selectedIndex,
                  ref,
                ), // Added Desktop Sidebar
              if (isSmallScreen && showNavigation)
                _buildMobileNavBar(context, theme, ref), // Mobile Bottom Nav
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(
    BuildContext context,
    ThemeData theme,
  ) {
    final isHomePage = _selectedIndex == 0;
    
    return PreferredSize(
      preferredSize: const Size.fromHeight(56.0),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 56.0,
            leading: isHomePage 
                ? Container(
                    width: 56, // Override AppBar's default leading width
                    padding: const EdgeInsets.only(left: 24), // 24px padding on the left
                    child: Center(
                      child: ref.watch(authStateChangesProvider).when(
                        data: (user) => _buildMaterialProfileIcon(
                          context,
                          theme,
                          user?.displayName,
                          user?.email,
                        ),
                        loading: () => _buildMaterialProfileIconPlaceholder(context, theme),
                        error: (_, __) => _buildMaterialProfileIcon(context, theme, null, null),
                      ),
                    ),
                  )
                : null,
            leadingWidth: isHomePage ? 64 : null, // Override AppBar's default leading width
            title: LogoWidget(
                height: 60, // Match secondary pages
                darkMode: theme.brightness == Brightness.dark,
              ),
            centerTitle: true,
            actions: isHomePage 
                ? [
                    // Tutorial button FIRST (left)
                    _buildSolidIconButton(
                      context,
                      icon: CupertinoIcons.question_circle,
                      onTap: () => _handleHelpIconTap(
                        context,
                        false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Notification bell SECOND (right)
                    Consumer(
                      builder: (context, ref, _) {
                        final unreadCount = ref.watch(unreadNotificationsCountProvider);
                        
                        return _buildNotificationBell(
                          context,
                          unreadCount: unreadCount.value ?? 0,
                        );
                      },
                    ),
                    const SizedBox(width: 24), // 24px padding on the right
                  ]
                : const [],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(
    bool isSmallScreen,
    bool showNavElements,
    ThemeData theme,
    Color effectiveBackgroundColor, // Pass the color here
  ) {
    final bool isHomePage = widget.currentIndex == 0;

    Widget content = SafeArea(
      top: true, // Apply SafeArea to top universally
      bottom:
          !(showNavElements &&
              isSmallScreen), // No bottom SafeArea if mobile navbar isn't shown
      child: Padding(
        padding: EdgeInsets.only(
          left:
              (!isSmallScreen && showNavElements) ? AppStyles.sidebarWidth : 0,
          bottom:
              (showNavElements && isSmallScreen) ? AppStyles.navBarHeight : 0,
        ),
        child:
            _isTransitioning
                ? Container(
                  color: effectiveBackgroundColor, // Use effective background color for transition
                ) // Transition placeholder
                : KeyedSubtree(
                  key: ValueKey(
                    'page-${widget.location}',
                  ), // Ensure page rebuilds on location change
                  child: widget.child,
                ),
      ),
    );

    if (isHomePage) {
      return content; // Just the SafeArea wrapped content, no background image
    } else {
      return content; // Just the SafeArea wrapped content
    }
  }

  Widget _buildDesktopSidebar(
    BuildContext context,
    bool isDark,
    int currentIndex,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final Color sidebarBackgroundColorWithOpacity = isDark
        ? AppTheme.darkNavBarBackground
        : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final unreadCount = ref
        .watch(unreadMessagesCountProvider)
        .maybeWhen(data: (count) => count, orElse: () => 0);

    return Positioned(
      top: 0,
      left: 0,
      bottom: 0,
      width: AppStyles.sidebarWidth,
      child: ClipRect(
        child: BackdropFilter(
          filter: AppStyles.standardBlur,
          child: Container(
            decoration: BoxDecoration(
              color: sidebarBackgroundColorWithOpacity,
              border: Border(
                right: BorderSide(
                  color: AppColors.border(isDark ? Brightness.dark : Brightness.light),
                  width: 1.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((255 * 0.05).round()),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32), // Increased top padding
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0), // Increased horizontal padding
                  child: Center(
                    child: LogoWidget(height: 72, darkMode: isDark), // Increased logo size
                  ),
                ),
                const SizedBox(height: 40), // Increased spacing after logo
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16, // Increased horizontal padding
                    ),
                    children: [
                      _buildSidebarItem(
                        icon: CupertinoIcons.house,
                        label: 'Início',
                        isSelected: currentIndex == 0,
                        onTap: () => _handleNavigation(0),
                        textColor: textColor,
                        theme: theme,
                      ),
                      const SizedBox(height: 16), // Increased spacing between items
                      _buildSidebarItem(
                        icon: CupertinoIcons.person_2,
                        label: 'Clientes',
                        isSelected: currentIndex == 1,
                        onTap: () => _handleNavigation(1),
                        textColor: textColor,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      _buildSidebarItem(
                        icon: CupertinoIcons.bubble_left,
                        label: 'Mensagens',
                        isSelected: currentIndex == 2,
                        onTap: () => _handleNavigation(2),
                        badgeCount: unreadCount,
                        textColor: textColor,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      _buildSidebarItem(
                        icon: CupertinoIcons.settings,
                        label: 'Definições',
                        isSelected: currentIndex == 3,
                        onTap: () => _handleNavigation(3),
                        textColor: textColor,
                        theme: theme,
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

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
    required Color textColor,
    required ThemeData theme,
  }) {
    final Color tulipTreeColor = AppTheme.tulipTree;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: isSelected
          ? BoxDecoration()
          : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14)
                .copyWith(left: isSelected ? 0 : 16, right: 16),
            child: Row(
              children: [
                if (isSelected)
                  Container(
                    width: 5,
                    height: 36,
                    margin: const EdgeInsets.only(right: 14),
                    decoration: BoxDecoration(
                      color: tulipTreeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                if (!isSelected)
                  const SizedBox(width: 19), // 5 (bar) + 14 (gap) for alignment
                isSelected
                    ? ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            colors: [
                              tulipTreeColor,
                              tulipTreeColor.withValues(
                                red: (tulipTreeColor.r + 15 / 255).clamp(0.0, 1.0),
                              ),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds);
                        },
                        child: Icon(icon, size: 22),
                      )
                    : Icon(icon, color: textColor.withAlpha((255 * 0.7).round()), size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? tulipTreeColor : textColor.withAlpha((255 * 0.7).round()),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 15,
                      shadows: isSelected
                          ? [
                              Shadow(
                                color: tulipTreeColor.withAlpha((255 * 0.3).round()),
                                blurRadius: 2.0,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
                if (badgeCount > 0) ...[
                  Container(
                    width: AppStyles.badgeSize,
                    height: AppStyles.badgeSize,
                    decoration: BoxDecoration(
                      color: tulipTreeColor,
                      borderRadius: BorderRadius.circular(AppStyles.badgeSize / 2),
                      boxShadow: [
                        BoxShadow(
                          color: tulipTreeColor.withAlpha((255 * 0.3).round()),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeCount.toString(),
                      style: AppStyles.badgeTextStyle(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNavBar(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final unreadCount = ref
        .watch(unreadMessagesCountProvider)
        .maybeWhen(data: (count) => count, orElse: () => 0);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter:
              AppStyles.standardBlur, // Assuming AppStyles.standardBlur exists
          child: Container(
            height:
                AppStyles
                    .navBarHeight, // Assuming AppStyles.navBarHeight exists
            decoration: BoxDecoration(
              color:
                  isDark
                      ? AppTheme.darkNavBarBackground.withAlpha(
                        (255 * 0.85).round(),
                      ) // Adjusted alpha
                      : Colors.white.withAlpha(
                        (255 * 0.85).round(),
                      ), // Adjusted alpha
              border: Border(
                top: BorderSide(
                  color: AppColors.border(isDark ? Brightness.dark : Brightness.light),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabItem(
                  icon: CupertinoIcons.house,
                  label: 'Início',
                  isSelected: _selectedIndex == 0,
                  onTap: () => _handleNavigation(0),
                  theme: theme, // Pass theme
                ),
                _buildTabItem(
                  icon: CupertinoIcons.person_2,
                  label: 'Clientes',
                  isSelected: _selectedIndex == 1,
                  onTap: () => _handleNavigation(1),
                  theme: theme, // Pass theme
                ),
                _buildTabItem(
                  icon: CupertinoIcons.bubble_left,
                  label: 'Mensagens',
                  isSelected: _selectedIndex == 2,
                  onTap: () => _handleNavigation(2),
                  badgeCount: unreadCount,
                  theme: theme, // Pass theme
                ),
                _buildTabItem(
                  icon: CupertinoIcons.settings,
                  label: 'Definições',
                  isSelected: _selectedIndex == 3,
                  onTap: () => _handleNavigation(3),
                  theme: theme, // Pass theme
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
    double width = 76, // Default width, can be overridden
    required ThemeData theme, // Added theme parameter
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final Color tulipTreeColor = AppTheme.tulipTree;
    final double fontSize = label.length > 8 ? 10.0 : 12.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        width: width, // Ensure width is used
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                isSelected
                    ? ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (Rect bounds) {
                        return LinearGradient(
                          colors: [
                            tulipTreeColor,
                            tulipTreeColor.withValues(
                              red: (tulipTreeColor.r + 15 / 255).clamp(0.0, 1.0),
                            ),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds);
                      },
                      child: Icon(icon, size: 24),
                    )
                    : Icon(
                      icon,
                      color: textColor.withAlpha((255 * 0.7).round()),
                      size: 24,
                    ),
                if (badgeCount > 0)
                  Positioned(
                    top: -5,
                    right: -8,
                    child: Container(
                      width: AppStyles.badgeSize,
                      height: AppStyles.badgeSize,
                      decoration: AppStyles.notificationBadge,
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount.toString(),
                        style: AppStyles.badgeTextStyle(context),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.visible,
              maxLines: 1,
              style: TextStyle(
                color:
                    isSelected
                        ? tulipTreeColor
                        : textColor.withAlpha((255 * 0.7).round()),
                fontSize: fontSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                shadows:
                    isSelected
                        ? [
                          Shadow(
                            color: tulipTreeColor.withAlpha((255 * 0.3).round()),
                            blurRadius: 1.5,
                          ),
                        ]
                        : null,
              ),
            ),
          ],
        ),
      ),
    );
  }





  // --- Helper for Material Profile Icon ---
  Widget _buildMaterialProfileIcon(
    BuildContext context,
    ThemeData theme,
    String? displayName,
    String? email,
  ) {
    return _buildSolidIconButton(
      context,
      icon: CupertinoIcons.person,
      onTap: () => context.push('/profile-details'),
    );
  }

  // --- Helper for Material Profile Icon Placeholder ---
  Widget _buildMaterialProfileIconPlaceholder(BuildContext context, ThemeData theme) {
    return _buildSolidIconButton(
      context,
      icon: CupertinoIcons.person,
      onTap: () {}, // No action while loading
    );
  }

  // --- Helper for Help Icon Tap Logic ---
  Future<void> _handleHelpIconTap(
    BuildContext context,
    bool wasAnimating, // Renamed from shouldAnimate to reflect its state when tapped
  ) async {
    if (wasAnimating) { // Use the passed parameter
      _helpIconAnimationController.stop();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.kHasSeenHelpIconHint, true);
      // Animation stopped, help hint dismissed
    }

    if (context.mounted) {
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Tutorial',
        barrierColor: Colors.black.withAlpha((255 * 0.5).round()),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (ctx, anim1, anim2) => const AppTutorialScreen(),
        transitionBuilder: (ctx, anim1, anim2, child) {
          return FadeTransition(opacity: anim1, child: child);
        },
      );
    }
  }

  // --- Helper for Notification Bell with Dropdown ---
  Widget _buildNotificationBell(BuildContext context, {required int unreadCount}) {
    return _buildSolidIconButton(
      context,
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
                width: AppStyles.badgeSize,
                height: AppStyles.badgeSize,
                decoration: AppStyles.notificationBadge,
                alignment: Alignment.center,
                child: Text(
                  unreadCount.toString(),
                  style: AppStyles.badgeTextStyle(context),
                ),
              ),
            ),
        ],
      ),
      onTap: () => _showNotificationDropdown(context),
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



// Helper method to build clean icon button without material outlines
Widget _buildSolidIconButton(
  BuildContext context, {
  IconData? icon,
  Widget? child,
  required VoidCallback onTap,
  bool isHighlighted = false,
}) {
  final theme = Theme.of(context);
  
  return InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Container(
      width: 40,  // Consistent size for all buttons
      height: 40, // Consistent size for all buttons
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
