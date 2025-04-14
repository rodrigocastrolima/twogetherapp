import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/ui_styles.dart';
import '../../core/theme/responsive.dart';
import '../screens/admin/admin_home_page.dart';
import '../screens/admin/admin_settings_page.dart';
import '../screens/messages/messages_page.dart';
import '../../features/chat/presentation/providers/chat_provider.dart';
import 'package:go_router/go_router.dart';
import '../widgets/logo.dart';

class AdminLayout extends ConsumerStatefulWidget {
  final Widget? child;
  final bool showBackButton;
  final bool showNavigation;
  final String pageTitle;
  final VoidCallback? onBackButtonPressed;

  const AdminLayout({
    super.key,
    this.child,
    this.showBackButton = false,
    this.showNavigation = true,
    this.pageTitle = '',
    this.onBackButtonPressed,
  });

  @override
  ConsumerState<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends ConsumerState<AdminLayout> {
  int _selectedIndex = 0;
  bool _isTransitioning = false;

  final List<Widget> _pages = [
    const AdminHomePage(),
    const MessagesPage(),
    const AdminSettingsPage(),
  ];

  @override
  void initState() {
    super.initState();

    // Set the initial selection based on the current route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSelectedIndexFromRoute();
    });
  }

  void _updateSelectedIndexFromRoute() {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/admin') {
      setState(() => _selectedIndex = 0);
    } else if (location == '/admin/messages') {
      setState(() => _selectedIndex = 1);
    } else if (location == '/admin/reports') {
      setState(() => _selectedIndex = 1);
    } else if (location == '/admin/settings') {
      setState(() => _selectedIndex = 2);
    } else if (location == '/admin/opportunities') {
      setState(() => _selectedIndex = 3);
    } else if (location == '/admin/user-management') {
      setState(() => _selectedIndex = 4);
    }
  }

  void _handleNavigation(int index) {
    if (_selectedIndex != index && !_isTransitioning) {
      setState(() {
        _isTransitioning = true;
      });

      // Clean transition by removing the previous screen first
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Navigate to the appropriate route
        switch (index) {
          case 0:
            context.go('/admin');
            break;
          case 1:
            context.go('/admin/messages');
            break;
          case 2:
            context.go('/admin/settings');
            break;
          case 3:
            context.go('/admin/opportunities');
            break;
          case 4:
            context.go('/admin/user-management');
            break;
        }

        // Update the state after navigation
        setState(() {
          _selectedIndex = index;
          _isTransitioning = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 600;
    final isDesktop = width >= 1024;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final l10n = AppLocalizations.of(context)!;
    final unreadCount = ref
        .watch(unreadMessagesCountProvider)
        .maybeWhen(data: (count) => count, orElse: () => 0);

    return Scaffold(
      backgroundColor:
          isDark ? theme.colorScheme.background : theme.colorScheme.background,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar:
          widget.showBackButton
              ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                toolbarHeight: 80,
                leading: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: IconButton(
                    icon: Icon(
                      CupertinoIcons.chevron_left,
                      color: AppTheme.foreground,
                      size: 20,
                    ),
                    onPressed:
                        widget.onBackButtonPressed ??
                        () {
                          if (Navigator.canPop(context)) {
                            context.pop();
                          } else {
                            // Fallback to going to admin home if can't pop
                            context.go('/admin');
                          }
                        },
                  ),
                ),
                title: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LogoWidget(height: 50, darkMode: false),
                ),
                centerTitle: true,
                actions: [],
              )
              : (!widget.showNavigation
                  ? null
                  : (isSmallScreen
                      ? AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        surfaceTintColor: Colors.transparent,
                        toolbarHeight: 80,
                        leading: null,
                        title: Center(
                          child: Text(
                            widget.pageTitle,
                            style: TextStyle(
                              color: AppTheme.foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        centerTitle: true,
                        actions: [],
                      )
                      : null)),
      body: Container(
        decoration: BoxDecoration(color: theme.colorScheme.background),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Main content area
              _buildMainContent(isSmallScreen),

              // Side Navigation for Desktop/Tablet
              if (!isSmallScreen && widget.showNavigation)
                _buildCollapsibleSidebar(textColor, isDark, l10n),

              // Bottom Navigation for Mobile
              if (widget.showNavigation && isSmallScreen)
                _buildMobileNavBar(context, isDark, l10n),

              // This Overlay layer will be used for full-screen modals
              // It sits above everything else - navigation bars, app bars, etc.
              Positioned.fill(
                child: IgnorePointer(
                  ignoring:
                      true, // This will pass touches through unless made visible
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isSmallScreen) {
    // Using a key based on the selected index ensures the widget tree is completely rebuilt
    // during page transitions, preventing any leakage between pages
    final pageKey = ValueKey('page-${_selectedIndex}');

    return Positioned(
      top: isSmallScreen ? (widget.showBackButton ? 80 : 0) : 0,
      left: isSmallScreen ? 0 : AppStyles.sidebarWidth,
      right: 0,
      bottom:
          isSmallScreen && widget.showNavigation ? AppStyles.navBarHeight : 0,
      child: ClipRect(
        child:
            _isTransitioning
                ? Container(
                  color: Theme.of(context).colorScheme.background,
                ) // Show barrier during transition
                : KeyedSubtree(
                  key: pageKey,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 24,
                      bottom: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main content
                        Expanded(
                          child: Container(
                            child: widget.child ?? _pages[_selectedIndex],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildCollapsibleSidebar(
    Color textColor,
    bool isDark,
    AppLocalizations l10n,
  ) {
    // Get the current location to highlight the correct item
    final location = GoRouterState.of(context).matchedLocation;
    int currentIndex = _selectedIndex;

    // Update current index based on route
    if (location == '/admin') {
      currentIndex = 0;
    } else if (location == '/admin/messages') {
      currentIndex = 1;
    } else if (location == '/admin/reports') {
      currentIndex = 1;
    } else if (location == '/admin/settings') {
      currentIndex = 2;
    } else if (location == '/admin/opportunities') {
      currentIndex = 3;
    } else if (location == '/admin/user-management') {
      currentIndex = 4;
    }

    // Fixed width sidebar
    const sidebarWidth = AppStyles.sidebarWidth;
    final unreadCount = ref
        .watch(unreadMessagesCountProvider)
        .maybeWhen(data: (count) => count, orElse: () => 0);

    return Positioned(
      top: 0,
      left: 0,
      bottom: 0,
      width: sidebarWidth,
      child: ClipRect(
        child: BackdropFilter(
          filter: AppStyles.standardBlur,
          child: Container(
            decoration: BoxDecoration(
              color:
                  isDark
                      ? AppTheme.darkNavBarBackground
                      : Theme.of(context).colorScheme.surface.withOpacity(0.8),
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // Replace text with logo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: LogoWidget(height: 60, darkMode: isDark),
                  ),
                ),
                const SizedBox(height: 32),
                // Navigation items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    children: [
                      _buildNavItem(
                        icon: CupertinoIcons.house,
                        title: l10n.adminDashboard,
                        isSelected: currentIndex == 0,
                        onTap: () => _handleNavigation(0),
                        textColor: textColor,
                      ),
                      const SizedBox(height: 12),
                      _buildNavItem(
                        icon: CupertinoIcons.graph_square,
                        title: l10n.navOpportunities,
                        isSelected: currentIndex == 3,
                        onTap: () => _handleNavigation(3),
                        textColor: textColor,
                      ),
                      const SizedBox(height: 12),
                      _buildNavItem(
                        icon: CupertinoIcons.bubble_left,
                        title: l10n.navMessages,
                        isSelected: currentIndex == 1,
                        onTap: () => _handleNavigation(1),
                        textColor: textColor,
                        badgeCount: unreadCount,
                      ),
                      const SizedBox(height: 12),
                      _buildNavItem(
                        icon: CupertinoIcons.chart_bar,
                        title: l10n.navReports,
                        isSelected: currentIndex == 1,
                        onTap: () => _handleNavigation(1),
                        textColor: textColor,
                      ),
                      const SizedBox(height: 12),
                      _buildNavItem(
                        icon: CupertinoIcons.person_2,
                        title: l10n.navResellers,
                        isSelected: currentIndex == 4,
                        onTap: () => _handleNavigation(4),
                        textColor: textColor,
                      ),
                      const SizedBox(height: 12),
                      _buildNavItem(
                        icon: CupertinoIcons.settings,
                        title: l10n.navSettings,
                        isSelected: currentIndex == 2,
                        onTap: () => _handleNavigation(2),
                        textColor: textColor,
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

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required Color textColor,
    int badgeCount = 0,
  }) {
    // Define the Tulip Tree color with enhanced brightness
    final Color tulipTreeColor = Color(0xFFffbe45);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: isSelected ? AppStyles.activeItemHighlight(context) : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                isSelected
                    ? ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (Rect bounds) {
                        return LinearGradient(
                          colors: [
                            tulipTreeColor,
                            tulipTreeColor.withRed(
                              (tulipTreeColor.red + 15).clamp(0, 255),
                            ),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds);
                      },
                      child: Icon(icon, size: 20),
                    )
                    : Icon(icon, color: textColor.withOpacity(0.7), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color:
                          isSelected
                              ? tulipTreeColor
                              : textColor.withOpacity(0.7),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      shadows:
                          isSelected
                              ? [
                                Shadow(
                                  color: tulipTreeColor.withOpacity(0.3),
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
                    decoration: AppStyles.notificationBadge,
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
    bool isDark,
    AppLocalizations l10n,
  ) {
    final textColor = isDark ? Colors.white : Colors.black;
    final unreadCount = ref
        .watch(unreadMessagesCountProvider)
        .maybeWhen(data: (count) => count, orElse: () => 0);

    // Calculate width for each tab based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final tabWidth = screenWidth / 6; // Now using 6 tabs

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: AppStyles.standardBlur,
          child: Container(
            height: AppStyles.navBarHeight,
            decoration: BoxDecoration(
              color:
                  isDark
                      ? AppTheme.darkNavBarBackground
                      : Colors.white.withOpacity(0.8),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabItem(
                  icon: CupertinoIcons.house,
                  label: l10n.adminDashboard,
                  isSelected: _selectedIndex == 0,
                  onTap: () => _handleNavigation(0),
                  width: tabWidth,
                ),
                _buildTabItem(
                  icon: CupertinoIcons.bubble_left,
                  label: l10n.navMessages,
                  isSelected: _selectedIndex == 1,
                  onTap: () => _handleNavigation(1),
                  badgeCount: unreadCount,
                  width: tabWidth,
                ),
                _buildTabItem(
                  icon: CupertinoIcons.person_2,
                  label: l10n.navResellers,
                  isSelected: _selectedIndex == 4,
                  onTap: () => _handleNavigation(4),
                  width: tabWidth,
                ),
                _buildTabItem(
                  icon: CupertinoIcons.graph_square,
                  label: l10n.navOpportunities,
                  isSelected:
                      _selectedIndex == 3 ||
                      GoRouterState.of(context).matchedLocation ==
                          '/admin/opportunities',
                  onTap: () => _handleNavigation(3),
                  width: tabWidth,
                ),
                _buildTabItem(
                  icon: CupertinoIcons.settings,
                  label: l10n.navSettings,
                  isSelected: _selectedIndex == 2,
                  onTap: () => _handleNavigation(2),
                  width: tabWidth,
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
    double width = 76,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    // Define the Tulip Tree color with enhanced brightness
    final Color tulipTreeColor = Color(0xFFffbe45);

    // Calculate text size based on label length
    final double fontSize = label.length > 8 ? 10.0 : 12.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        width: width,
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
                            tulipTreeColor.withRed(
                              (tulipTreeColor.red + 15).clamp(0, 255),
                            ),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds);
                      },
                      child: Icon(icon, size: 24),
                    )
                    : Icon(icon, color: textColor.withOpacity(0.7), size: 24),
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
                color: isSelected ? tulipTreeColor : textColor.withOpacity(0.7),
                fontSize: fontSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                shadows:
                    isSelected
                        ? [
                          Shadow(
                            color: tulipTreeColor.withOpacity(0.3),
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
}
