import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/theme/theme.dart';
import '../screens/admin/admin_home_page.dart';
import '../screens/admin/admin_users_page.dart';
import '../screens/admin/admin_reports_page.dart';
import '../screens/admin/admin_settings_page.dart';
import '../screens/messages/messages_page.dart';
import 'package:go_router/go_router.dart';

class AdminLayout extends StatefulWidget {
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
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _selectedIndex = 0;
  final int _notificationCount = 3;

  final List<Widget> _pages = [
    const AdminHomePage(),
    const AdminUsersPage(),
    const MessagesPage(),
    const AdminReportsPage(),
    const AdminSettingsPage(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Users',
    'Messages',
    'Reports',
    'Settings',
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
    } else if (location == '/admin/users') {
      setState(() => _selectedIndex = 1);
    } else if (location == '/admin/messages') {
      setState(() => _selectedIndex = 2);
    } else if (location == '/admin/reports') {
      setState(() => _selectedIndex = 3);
    } else if (location == '/admin/settings') {
      setState(() => _selectedIndex = 4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 600;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.background.withBlue((AppTheme.background.b + 10).toInt()),
            AppTheme.background,
            AppTheme.background.withRed((AppTheme.background.r + 10).toInt()),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar:
            widget.showBackButton || !widget.showNavigation
                ? _buildAppBar(context)
                : null,
        body: Row(
          children: [
            if (!isSmallScreen && widget.showNavigation) _buildNavigationRail(),
            Expanded(child: widget.child ?? _pages[_selectedIndex]),
          ],
        ),
        bottomNavigationBar:
            isSmallScreen && widget.showNavigation
                ? _buildBottomNavigationBar()
                : null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading:
          widget.showBackButton
              ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed:
                    widget.onBackButtonPressed ??
                    () => Navigator.of(context).pop(),
              )
              : null,
      title: Text(
        widget.pageTitle.isNotEmpty
            ? widget.pageTitle
            : _titles[_selectedIndex],
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      actions: [
        if (widget.showNavigation)
          Stack(
            children: [
              IconButton(
                icon: const Icon(CupertinoIcons.bell_fill, color: Colors.white),
                onPressed: () {
                  // Handle notifications
                },
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _notificationCount.toString(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildNavigationRail() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 100,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: Colors.white.withAlpha(26), width: 0.5),
          ),
          child: NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
              _handleNavigation(index);
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.transparent,
            selectedLabelTextStyle: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: Colors.white.withAlpha(179),
            ),
            destinations: [
              _buildNavigationRailDestination(CupertinoIcons.home, 'Dashboard'),
              _buildNavigationRailDestination(CupertinoIcons.person_2, 'Users'),
              _buildNavigationRailDestination(
                CupertinoIcons.chat_bubble_2,
                'Messages',
              ),
              _buildNavigationRailDestination(
                CupertinoIcons.chart_bar,
                'Reports',
              ),
              _buildNavigationRailDestination(
                CupertinoIcons.settings,
                'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  NavigationRailDestination _buildNavigationRailDestination(
    IconData iconData,
    String label,
  ) {
    return NavigationRailDestination(
      icon: Icon(iconData, color: Colors.white.withAlpha(179)),
      selectedIcon: Icon(iconData, color: Colors.amber),
      label: Text(label),
    );
  }

  Widget _buildBottomNavigationBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (int index) {
            setState(() {
              _selectedIndex = index;
            });
            _handleNavigation(index);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white.withAlpha(20),
          selectedItemColor: Colors.amber,
          unselectedItemColor: Colors.white.withAlpha(179),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.home),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person_2),
              label: 'Users',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chat_bubble_2),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chart_bar),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.settings),
              label: 'Settings',
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
        context.go('/admin/users');
        break;
      case 2:
        context.go('/admin/messages');
        break;
      case 3:
        context.go('/admin/reports');
        break;
      case 4:
        context.go('/admin/settings');
        break;
    }
  }
}
