import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/constants.dart';
import '../screens/home/reseller_home_page.dart';
import '../screens/clients/clients_page.dart';
import '../screens/messages/messages_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';

class MainLayout extends StatefulWidget {
  final Widget? child;
  final VoidCallback? onBackPressed;
  final bool showBackButton;
  final bool showNavigation;

  const MainLayout({
    super.key,
    this.child,
    this.onBackPressed,
    this.showBackButton = true,
    this.showNavigation = false,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 1;

  final List<Widget> _pages = [
    const ResellerHomePage(),
    const ClientsPage(),
    const MessagesPage(),
    const ProfilePage(),
  ];

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
              appBar:
                  !widget.showNavigation
                      ? null
                      : (isSmallScreen
                          ? AppBar(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
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
                                  right: 8,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.notifications_outlined,
                                    color: AppTheme.foreground,
                                  ),
                                  onPressed: () {
                                    // TODO: Implement notifications
                                  },
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
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: AppTheme.foreground,
                              ),
                              onPressed:
                                  widget.onBackPressed ??
                                  () => Navigator.of(context).pop(),
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
                              color: Colors.white.withValues(alpha: 20),
                              border: Border(
                                right: BorderSide(
                                  color: Colors.white.withValues(alpha: 38),
                                  width: 0.5,
                                ),
                              ),
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
                                padding: const EdgeInsets.all(16),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: 40,
                                ),
                              ),
                              destinations: [
                                NavigationRailDestination(
                                  icon: Icon(
                                    Icons.home_outlined,
                                    color:
                                        _selectedIndex == 0
                                            ? AppTheme.primary
                                            : AppTheme.foreground.withValues(
                                              alpha: 179,
                                            ),
                                  ),
                                  selectedIcon: const Icon(
                                    Icons.home,
                                    color: AppTheme.primary,
                                  ),
                                  label: Text(
                                    'Início',
                                    style: TextStyle(
                                      color:
                                          _selectedIndex == 0
                                              ? AppTheme.primary
                                              : AppTheme.foreground.withValues(
                                                alpha: 179,
                                              ),
                                    ),
                                  ),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(
                                    Icons.people_outline,
                                    color:
                                        _selectedIndex == 1
                                            ? AppTheme.primary
                                            : AppTheme.foreground.withValues(
                                              alpha: 179,
                                            ),
                                  ),
                                  selectedIcon: const Icon(
                                    Icons.people,
                                    color: AppTheme.primary,
                                  ),
                                  label: Text(
                                    'Clientes',
                                    style: TextStyle(
                                      color:
                                          _selectedIndex == 1
                                              ? AppTheme.primary
                                              : AppTheme.foreground.withValues(
                                                alpha: 179,
                                              ),
                                    ),
                                  ),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(
                                    Icons.message_outlined,
                                    color:
                                        _selectedIndex == 2
                                            ? AppTheme.primary
                                            : AppTheme.foreground.withValues(
                                              alpha: 179,
                                            ),
                                  ),
                                  selectedIcon: const Icon(
                                    Icons.message,
                                    color: AppTheme.primary,
                                  ),
                                  label: Text(
                                    'Mensagens',
                                    style: TextStyle(
                                      color:
                                          _selectedIndex == 2
                                              ? AppTheme.primary
                                              : AppTheme.foreground.withValues(
                                                alpha: 179,
                                              ),
                                    ),
                                  ),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(
                                    Icons.person_outline,
                                    color:
                                        _selectedIndex == 3
                                            ? AppTheme.primary
                                            : AppTheme.foreground.withValues(
                                              alpha: 179,
                                            ),
                                  ),
                                  selectedIcon: const Icon(
                                    Icons.person,
                                    color: AppTheme.primary,
                                  ),
                                  label: Text(
                                    'Perfil',
                                    style: TextStyle(
                                      color:
                                          _selectedIndex == 3
                                              ? AppTheme.primary
                                              : AppTheme.foreground.withValues(
                                                alpha: 179,
                                              ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: widget.child ?? _pages[_selectedIndex],
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
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
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 20),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 38),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: NavigationBar(
                        backgroundColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: (index) {
                          setState(() => _selectedIndex = index);
                          _handleNavigation(index);
                        },
                        destinations: [
                          NavigationDestination(
                            icon: Icon(
                              Icons.home_outlined,
                              color:
                                  _selectedIndex == 0
                                      ? AppTheme.primary
                                      : AppTheme.foreground.withValues(
                                        alpha: 179,
                                      ),
                            ),
                            selectedIcon: const Icon(
                              Icons.home,
                              color: AppTheme.primary,
                            ),
                            label: 'Início',
                          ),
                          NavigationDestination(
                            icon: Icon(
                              Icons.people_outline,
                              color:
                                  _selectedIndex == 1
                                      ? AppTheme.primary
                                      : AppTheme.foreground.withValues(
                                        alpha: 179,
                                      ),
                            ),
                            selectedIcon: const Icon(
                              Icons.people,
                              color: AppTheme.primary,
                            ),
                            label: 'Clientes',
                          ),
                          NavigationDestination(
                            icon: Icon(
                              Icons.message_outlined,
                              color:
                                  _selectedIndex == 2
                                      ? AppTheme.primary
                                      : AppTheme.foreground.withValues(
                                        alpha: 179,
                                      ),
                            ),
                            selectedIcon: const Icon(
                              Icons.message,
                              color: AppTheme.primary,
                            ),
                            label: 'Mensagens',
                          ),
                          NavigationDestination(
                            icon: Icon(
                              Icons.person_outline,
                              color:
                                  _selectedIndex == 3
                                      ? AppTheme.primary
                                      : AppTheme.foreground.withValues(
                                        alpha: 179,
                                      ),
                            ),
                            selectedIcon: const Icon(
                              Icons.person,
                              color: AppTheme.primary,
                            ),
                            label: 'Perfil',
                          ),
                        ],
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

  void _handleNavigation(int index) {
    // Implement the logic for handling navigation
  }
}
