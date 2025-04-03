import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/ui_styles.dart';
import '../../core/theme/responsive.dart';
import '../screens/admin/admin_home_page.dart';
import '../screens/admin/admin_reports_page.dart';
import '../screens/admin/admin_settings_page.dart';
import '../screens/messages/messages_page.dart';
import '../../features/chat/presentation/providers/chat_provider.dart';
import 'package:go_router/go_router.dart';

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

  final List<Widget> _pages = [
    const AdminHomePage(),
    const MessagesPage(),
    const AdminReportsPage(),
    const AdminSettingsPage(),
  ];

  final List<String> _titles = ['Dashboard', 'Messages', 'Reports', 'Settings'];

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
      setState(() => _selectedIndex = 2);
    } else if (location == '/admin/settings') {
      setState(() => _selectedIndex = 3);
    } else if (location == '/admin/opportunities') {
      setState(() => _selectedIndex = 4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 600;
    final isDesktop = width >= 1024;
    final unreadCount = ref
        .watch(unreadMessagesCountProvider)
        .maybeWhen(data: (count) => count, orElse: () => 0);

    return Container(
      decoration: BoxDecoration(gradient: AppStyles.mainGradient(context)),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: Colors.transparent,
              extendBody: true,
              extendBodyBehindAppBar: true,
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
                          child: Image.asset(
                            'assets/images/twogether_logo_light_br.png',
                            height: 70,
                          ),
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
                                  child: Image.asset(
                                    'assets/images/twogether_logo_light_br.png',
                                    height: 70,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                centerTitle: true,
                                actions: [],
                              )
                              : null)),
              body: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (isDesktop && widget.showNavigation)
                          _buildCollapsibleSidebar(),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 24,
                              right: 24,
                              top: 24,
                              bottom:
                                  isSmallScreen && widget.showNavigation
                                      ? 84
                                      : 24,
                            ),
                            child: widget.child ?? _pages[_selectedIndex],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.showNavigation && isSmallScreen)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withAlpha(26),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildTabItem(
                              icon: CupertinoIcons.home,
                              selectedIcon: CupertinoIcons.house_fill,
                              label: 'Dashboard',
                              index: 0,
                            ),
                            _buildTabItem(
                              icon: CupertinoIcons.graph_square,
                              selectedIcon: CupertinoIcons.graph_square,
                              label: 'Opportunities',
                              index: 4,
                              onTap: () => context.go('/admin/opportunities'),
                            ),
                            _buildTabItem(
                              icon: CupertinoIcons.chat_bubble,
                              selectedIcon: CupertinoIcons.chat_bubble_fill,
                              label: 'Messages',
                              index: 1,
                              badge: unreadCount,
                            ),
                            _buildTabItem(
                              icon: CupertinoIcons.settings,
                              selectedIcon: CupertinoIcons.settings_solid,
                              label: 'Settings',
                              index: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleSidebar() {
    // Get the current location to highlight the correct item
    final location = GoRouterState.of(context).matchedLocation;
    int currentIndex = _selectedIndex;

    // Update current index based on route
    if (location == '/admin') {
      currentIndex = 0;
    } else if (location == '/admin/messages') {
      currentIndex = 1;
    } else if (location == '/admin/reports') {
      currentIndex = 2;
    } else if (location == '/admin/settings') {
      currentIndex = 3;
    } else if (location == '/admin/opportunities') {
      currentIndex = 4;
    }

    // Fixed width sidebar
    const sidebarWidth = 200.0;

    return Container(
      width: sidebarWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        border: Border(
          right: BorderSide(color: Colors.black.withOpacity(0.1), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              // Logo section
              SizedBox(
                height: 130,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Image.asset(
                      'assets/images/twogether_logo_light_br.png',
                      height: 130,
                      width: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // Navigation items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                  children: [
                    _buildNavItem(
                      icon: CupertinoIcons.home,
                      title: 'Dashboard',
                      isSelected: currentIndex == 0,
                      onTap: () => _handleNavigation(0),
                    ),
                    const SizedBox(height: 12),
                    _buildNavItem(
                      icon: CupertinoIcons.graph_square,
                      title: 'Opportunities',
                      isSelected: currentIndex == 4,
                      onTap: () => _handleNavigation(4),
                    ),
                    const SizedBox(height: 12),
                    _buildNavItem(
                      icon: CupertinoIcons.chat_bubble,
                      title: 'Messages',
                      isSelected: currentIndex == 1,
                      onTap: () => _handleNavigation(1),
                      badge: ref
                          .watch(unreadMessagesCountProvider)
                          .maybeWhen(data: (count) => count, orElse: () => 0),
                    ),
                    const SizedBox(height: 12),
                    _buildNavItem(
                      icon: CupertinoIcons.chart_bar,
                      title: 'Reports',
                      isSelected: currentIndex == 2,
                      onTap: () => _handleNavigation(2),
                    ),
                    const SizedBox(height: 12),
                    _buildNavItem(
                      icon: CupertinoIcons.settings,
                      title: 'Settings',
                      isSelected: currentIndex == 3,
                      onTap: () => _handleNavigation(3),
                    ),
                  ],
                ),
              ),
            ],
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
    int badge = 0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.black.withOpacity(0.05),
        splashColor: Colors.black.withOpacity(0.1),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? Colors.black.withOpacity(0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color:
                        isSelected
                            ? AppTheme.primary
                            : Colors.black.withOpacity(0.7),
                  ),
                  if (badge > 0)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          badge.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color:
                        isSelected
                            ? AppTheme.primary
                            : Colors.black.withOpacity(0.7),
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    int badge = 0,
    VoidCallback? onTap,
  }) {
    final bool isSelected =
        _selectedIndex == index ||
        (index == 4 &&
            GoRouterState.of(context).matchedLocation ==
                '/admin/opportunities');

    return GestureDetector(
      onTap:
          onTap ??
          () {
            // Update the selected index immediately for visual feedback
            if (!isSelected) {
              setState(() => _selectedIndex = index);
              // Then handle actual navigation
              _handleNavigation(index);
            }
          },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color:
                      isSelected
                          ? AppTheme.primary
                          : AppTheme.foreground.withAlpha(153),
                  size: 26,
                ),
                if (badge > 0)
                  Positioned(
                    right: -10,
                    top: -10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badge.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: '.SF Pro Text',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color:
                    isSelected
                        ? AppTheme.primary
                        : AppTheme.foreground.withAlpha(153),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNavigation(int index) {
    switch (index) {
      case 0:
        context.go('/admin');
        break;
      case 1:
        context.go('/admin/messages');
        break;
      case 2:
        context.go('/admin/reports');
        break;
      case 3:
        context.go('/admin/settings');
        break;
      case 4:
        context.go('/admin/opportunities');
        break;
    }
  }
}
