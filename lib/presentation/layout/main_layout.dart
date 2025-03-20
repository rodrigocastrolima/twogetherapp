import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/constants.dart';
import '../screens/home/reseller_home_page.dart';
import '../screens/clients/clients_page.dart';
import '../screens/messages/messages_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../screens/notifications/rejection_details_page.dart';

class MainLayout extends StatefulWidget {
  final Widget? child;
  final VoidCallback? onBackPressed;
  final bool showBackButton;
  final bool showNavigation;
  final String pageTitle;

  const MainLayout({
    super.key,
    this.child,
    this.onBackPressed,
    this.showBackButton = true,
    this.showNavigation = false,
    this.pageTitle = '',
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  bool _hasNotifications = false;

  final List<Widget> _pages = [
    const ResellerHomePage(),
    const ClientsPage(),
    const MessagesPage(),
    const ProfilePage(),
  ];

  void _handleNotificationTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => RejectionDetailsPage(
              submissionId: 'SUB12345',
              rejectionReason: 'Missing document information',
              rejectionDate: DateTime.now(),
              isPermanentRejection: false,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 600;
    final isDesktop = width >= 1024;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-1.0, -1.0),
          end: const Alignment(1.0, 1.0),
          colors: [const Color(0xFF93A5CF), const Color(0xFFE4EFE9)],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: Colors.transparent,
              extendBody: true,
              extendBodyBehindAppBar: true,
              appBar:
                  !widget.showNavigation
                      ? null
                      : (isSmallScreen
                          ? AppBar(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            toolbarHeight: 70,
                            title: Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Image.asset(
                                'assets/images/twogether_logo_light_br.png',
                                height: 32,
                              ),
                            ),
                            centerTitle: true,
                            actions: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 16,
                                  right: 16,
                                ),
                                child: Icon(
                                  CupertinoIcons.bell,
                                  color: AppTheme.foreground,
                                  size: 24,
                                ),
                              ),
                            ],
                          )
                          : null),
              body: Column(
                children: [
                  if (!widget.showNavigation)
                    Padding(
                      padding: const EdgeInsets.all(AppConstants.spacing16),
                      child: Row(
                        children: [
                          if (widget.showBackButton)
                            GestureDetector(
                              onTap:
                                  widget.onBackPressed ??
                                  () => Navigator.of(context).pop(),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 0.5,
                                  ),
                                ),
                                child: Icon(
                                  CupertinoIcons.chevron_left,
                                  color: AppTheme.foreground,
                                  size: 20,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Image.asset(
                            'assets/images/twogether_logo_light_br.png',
                            height: 32,
                          ),
                          const SizedBox(width: AppConstants.spacing16),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Row(
                      children: [
                        if (isDesktop) ...[
                          Container(
                            width: 280,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              border: Border(
                                right: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: ClipRRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: NavigationRail(
                                  extended: true,
                                  backgroundColor: Colors.transparent,
                                  selectedIndex: _selectedIndex,
                                  onDestinationSelected: (index) {
                                    setState(() => _selectedIndex = index);
                                    _handleNavigation(index);
                                  },
                                  leading: Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.menu,
                                        color: AppTheme.foreground,
                                      ),
                                      onPressed: () {
                                        // Handle menu
                                      },
                                    ),
                                  ),
                                  destinations: [
                                    NavigationRailDestination(
                                      icon: Icon(
                                        CupertinoIcons.home,
                                        color:
                                            _selectedIndex == 0
                                                ? AppTheme.primary
                                                : AppTheme.foreground
                                                    .withOpacity(0.5),
                                      ),
                                      label: Text(
                                        'Início',
                                        style: TextStyle(
                                          color:
                                              _selectedIndex == 0
                                                  ? AppTheme.primary
                                                  : AppTheme.foreground
                                                      .withOpacity(0.5),
                                          fontWeight:
                                              _selectedIndex == 0
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    NavigationRailDestination(
                                      icon: Icon(
                                        CupertinoIcons.person_2,
                                        color:
                                            _selectedIndex == 1
                                                ? AppTheme.primary
                                                : AppTheme.foreground
                                                    .withOpacity(0.5),
                                      ),
                                      label: Text(
                                        'Clientes',
                                        style: TextStyle(
                                          color:
                                              _selectedIndex == 1
                                                  ? AppTheme.primary
                                                  : AppTheme.foreground
                                                      .withOpacity(0.5),
                                          fontWeight:
                                              _selectedIndex == 1
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    NavigationRailDestination(
                                      icon: Icon(
                                        CupertinoIcons.plus_circle,
                                        color:
                                            _selectedIndex == 2
                                                ? AppTheme.primary
                                                : AppTheme.foreground
                                                    .withOpacity(0.5),
                                      ),
                                      label: Text(
                                        'Novo Cliente',
                                        style: TextStyle(
                                          color:
                                              _selectedIndex == 2
                                                  ? AppTheme.primary
                                                  : AppTheme.foreground
                                                      .withOpacity(0.5),
                                          fontWeight:
                                              _selectedIndex == 2
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    NavigationRailDestination(
                                      icon: Icon(
                                        CupertinoIcons.settings,
                                        color:
                                            _selectedIndex == 3
                                                ? AppTheme.primary
                                                : AppTheme.foreground
                                                    .withOpacity(0.5),
                                      ),
                                      label: Text(
                                        'Configurações',
                                        style: TextStyle(
                                          color:
                                              _selectedIndex == 3
                                                  ? AppTheme.primary
                                                  : AppTheme.foreground
                                                      .withOpacity(0.5),
                                          fontWeight:
                                              _selectedIndex == 3
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: 24,
                                right: 24,
                                top:
                                    widget.showNavigation && isSmallScreen
                                        ? kToolbarHeight + 16
                                        : 24,
                                bottom:
                                    widget.showNavigation && isSmallScreen
                                        ? 84
                                        : 24,
                              ),
                              child: widget.child ?? _pages[_selectedIndex],
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: 24,
                                right: 24,
                                top:
                                    widget.showNavigation && isSmallScreen
                                        ? kToolbarHeight + 16
                                        : 24,
                                bottom:
                                    widget.showNavigation && isSmallScreen
                                        ? 84
                                        : 24,
                              ),
                              child: widget.child ?? _pages[_selectedIndex],
                            ),
                          ),
                        ],
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
                        color: Colors.white.withOpacity(0.08),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.1),
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
                              icon: CupertinoIcons.house,
                              selectedIcon: CupertinoIcons.house_fill,
                              label: 'Início',
                              index: 0,
                            ),
                            _buildTabItem(
                              icon: CupertinoIcons.person_2,
                              selectedIcon: CupertinoIcons.person_2_fill,
                              label: 'Clientes',
                              index: 1,
                            ),
                            _buildTabItem(
                              icon: CupertinoIcons.chat_bubble,
                              selectedIcon: CupertinoIcons.chat_bubble_fill,
                              label: 'Mensagens',
                              index: 2,
                            ),
                            _buildTabItem(
                              icon: CupertinoIcons.person,
                              selectedIcon: CupertinoIcons.person_fill,
                              label: 'Perfil',
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

  Widget _buildTabItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        _handleNavigation(index);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color:
                  isSelected
                      ? AppTheme.primary
                      : AppTheme.foreground.withOpacity(0.6),
              size: 26,
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
                        : AppTheme.foreground.withOpacity(0.6),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNavigation(int index) {
    // Implement the logic for handling navigation
  }
}
