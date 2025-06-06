import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/app_colors.dart';

import '../../core/theme/ui_styles.dart';

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

  @override
  void initState() {
    super.initState();

    // Set the initial selection based on the current route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Add mounted check before accessing context
      if (mounted) {
        _updateSelectedIndexFromRoute();
      }
    });
  }

  void _updateSelectedIndexFromRoute() {
    if (!mounted) return;
    // Use GoRouterState.of(context) to get the current state
    final GoRouterState routerState = GoRouterState.of(context);
    final location = routerState.matchedLocation;

    int newIndex = 0; // Default to home (index 0)

    if (location == '/admin') {
      newIndex = 0;
    } else if (location == '/admin/messages') {
      newIndex = 1;
    } else if (location == '/admin/settings') {
      newIndex = 2;
    } else if (location.startsWith('/admin/opportunities') ||
        location == '/admin/opportunity-detail') {
      newIndex = 3;
    } else if (location == '/admin/user-management') {
      newIndex = 4;
    }

    // Update state only if the index has changed
    if (_selectedIndex != newIndex) {
      setState(() => _selectedIndex = newIndex);
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
        // Check if mounted before setting state across async gap
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
    // --- Ensure selected index is updated on build --- //
    _updateSelectedIndexFromRoute();
    // --- End Update --- //

    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 600;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unreadCount = ref
        .watch(unreadMessagesCountProvider)
        .maybeWhen(data: (count) => count, orElse: () => 0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                            child: LogoWidget(height: 40, darkMode: isDark),
                          ),
                          centerTitle: true,
                          actions: [],
                        )
                      : AppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          scrolledUnderElevation: 0,
                          surfaceTintColor: Colors.transparent,
                          toolbarHeight: 0, // Hide the AppBar but keep it transparent
                          automaticallyImplyLeading: false,
                          title: null,
                          actions: [],
                        ))),
      body: Container(
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Main content area
              _buildMainContent(isSmallScreen),

              // Side Navigation for Desktop/Tablet
              if (!isSmallScreen && widget.showNavigation)
                _buildCollapsibleSidebar(isDark, _selectedIndex, unreadCount),

              // Bottom Navigation for Mobile
              if (widget.showNavigation && isSmallScreen)
                _buildMobileNavBar(
                  context,
                  isDark,
                  _selectedIndex,
                  unreadCount,
                ),

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
    // Using the route path as key might be more robust with ShellRoute
    final routePath = GoRouterState.of(context).matchedLocation;
    final pageKey = ValueKey('page-$routePath');

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
                  color: Theme.of(context).scaffoldBackgroundColor,
                ) // Show barrier during transition
                : KeyedSubtree(
                  key: pageKey,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: !isSmallScreen && widget.showNavigation ? 0 : 0,
                      right: 0,
                      top: 24,
                      bottom: 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main content - Use widget.child directly
                        Expanded(
                          child: Container(
                            // --- MODIFY to use only widget.child --- //
                            child:
                                widget.child ??
                                const Center(
                                  child: Text(
                                    "Error: Child widget not provided by ShellRoute.",
                                  ),
                                ),
                            // --- END MODIFICATION --- //
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
    bool isDark,
    int currentIndex,
    int unreadCount,
  ) {
    final theme = Theme.of(context);
    final Color sidebarBackgroundColorWithOpacity = isDark
        ? AppTheme.darkNavBarBackground
        : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black;

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
                        icon: CupertinoIcons.graph_square,
                        label: 'Oportunidades',
                        isSelected: currentIndex == 3,
                        onTap: () => _handleNavigation(3),
                        textColor: textColor,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      _buildSidebarItem(
                        icon: CupertinoIcons.bubble_left,
                        label: 'Mensagens',
                        isSelected: currentIndex == 1,
                        onTap: () => _handleNavigation(1),
                        badgeCount: unreadCount,
                        textColor: textColor,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      _buildSidebarItem(
                        icon: CupertinoIcons.person_2,
                        label: 'Revendedores',
                        isSelected: currentIndex == 4,
                        onTap: () => _handleNavigation(4),
                        textColor: textColor,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      _buildSidebarItem(
                        icon: CupertinoIcons.settings,
                        label: 'Definições',
                        isSelected: currentIndex == 2,
                        onTap: () => _handleNavigation(2),
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
    bool isDark,
    int currentIndex,
    int unreadCount,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final numTabs = 5; // Changed back to 5 tabs
    final tabWidth = screenWidth / numTabs;

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
                      : Colors.white.withAlpha((255 * 0.8).round()),
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
                  label: 'Dashboard',
                  isSelected: currentIndex == 0,
                  onTap: () => _handleNavigation(0),
                  width: tabWidth,
                ),
                _buildTabItem(
                  icon: CupertinoIcons.graph_square,
                  label: 'Oportunidades',
                  isSelected: currentIndex == 3,
                  onTap: () => _handleNavigation(3),
                  width: tabWidth,
                ),
                _buildTabItem(
                  icon: CupertinoIcons.bubble_left,
                  label: 'Mensagens',
                  isSelected: currentIndex == 1,
                  onTap: () => _handleNavigation(1),
                  badgeCount: unreadCount,
                  width: tabWidth,
                ),
                _buildTabItem(
                  icon: CupertinoIcons.person_2,
                  label: 'Revendedores',
                  isSelected: currentIndex == 4,
                  onTap: () => _handleNavigation(4),
                  width: tabWidth,
                ),
                _buildTabItem(
                  icon: CupertinoIcons.settings,
                  label: 'Configurações',
                  isSelected: currentIndex == 2,
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
                : Icon(icon, color: textColor.withAlpha((255 * 0.7).round()), size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.visible,
              maxLines: 1,
              style: TextStyle(
                color: isSelected ? tulipTreeColor : textColor.withAlpha((255 * 0.7).round()),
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
}
