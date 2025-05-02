import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/constants.dart';
import '../screens/home/reseller_home_page.dart';
import '../screens/clients/reseller_opportunity_page.dart';
import '../screens/messages/messages_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/chat/presentation/providers/chat_provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ui_styles.dart';
import '../widgets/logo.dart';
import '../../features/auth/domain/models/app_user.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

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

class _MainLayoutState extends ConsumerState<MainLayout> {
  int _selectedIndex = 0;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex;
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
        setState(() {
          _selectedIndex = index;
          _isTransitioning = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 600;

    final isOnline = _isBusinessHours();

    final Color backgroundColor = theme.colorScheme.surface;

    final bool showBottomNavBar = widget.location != '/change-password';

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar:
          isSmallScreen && _selectedIndex != 0
              ? PreferredSize(
                preferredSize: const Size.fromHeight(100),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      surfaceTintColor: Colors.transparent,
                      toolbarHeight: 100,
                      leading: _selectedIndex == 2 ? null : null,
                      title:
                          _selectedIndex == 2
                              ? Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(
                                              (255 * 0.05).round(),
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(10),
                                      child: Image.asset(
                                        'assets/images/twogether_logo_dark_br.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Column(
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Suporte Twogether',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color:
                                                    isOnline
                                                        ? Colors.green
                                                        : Colors.grey,
                                                shape: BoxShape.circle,
                                                boxShadow:
                                                    isOnline
                                                        ? [
                                                          BoxShadow(
                                                            color: Colors.green
                                                                .withAlpha(
                                                                  (255 * 0.4)
                                                                      .round(),
                                                                ),
                                                            blurRadius: 4,
                                                            spreadRadius: 1,
                                                          ),
                                                        ]
                                                        : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                              : Container(
                                height: 100,
                                alignment: Alignment.center,
                                child: LogoWidget(height: 80, darkMode: false),
                              ),
                      centerTitle: true,
                      actions: const [],
                    ),
                  ),
                ),
              )
              : null,
      body: Container(
        decoration: BoxDecoration(color: theme.colorScheme.surface),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              _buildMainContent(isSmallScreen, showBottomNavBar),
              if (isSmallScreen && showBottomNavBar)
                _buildMobileNavBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isSmallScreen, bool showNavBar) {
    final bool isHomePage = widget.currentIndex == 0;

    // The main content area, potentially wrapped in a Stack for the homepage background
    Widget content = SafeArea(
      // Apply SafeArea universally, adjust top padding later if needed
      top: true,
      bottom: !showNavBar, // No bottom padding if navbar isn't shown
      child: Padding(
        padding: EdgeInsets.only(
          // Only add bottom padding if navbar is shown on small screens
          bottom: showNavBar && isSmallScreen ? AppStyles.navBarHeight : 0,
        ),
        child:
            _isTransitioning
                ? Container(color: Theme.of(context).colorScheme.surface)
                : KeyedSubtree(
                  key: ValueKey('page-${widget.location}'),
                  child: widget.child,
                ),
      ),
    );

    if (isHomePage) {
      // If it's the home page, wrap the content in a Stack with the background
      return Stack(
        children: [
          // Background Image Layer
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4, // 1/3 height
            child: Image.asset(
              'assets/images/backgrounds/homepage.png',
              fit: BoxFit.cover,
              // Optional: Add errorBuilder if image fails to load
              errorBuilder: (context, error, stackTrace) {
                // Return a placeholder color or widget on error
                return Container(color: Colors.grey);
              },
            ),
          ),
          // Content Layer (already includes SafeArea)
          content,
        ],
      );
    } else {
      // For other pages, just return the content directly
      return content;
    }
  }

  Widget _buildMobileNavBar(BuildContext context) {
    final theme = Theme.of(context);
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
                  color: Theme.of(
                    context,
                  ).dividerColor.withAlpha((255 * 0.1).round()),
                  width: 0.5,
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
                ),
                _buildTabItem(
                  icon: CupertinoIcons.person_2,
                  label: 'Clientes',
                  isSelected: _selectedIndex == 1,
                  onTap: () => _handleNavigation(1),
                ),
                _buildTabItem(
                  icon: CupertinoIcons.bubble_left,
                  label: 'Mensagens',
                  isSelected: _selectedIndex == 2,
                  onTap: () => _handleNavigation(2),
                  badgeCount: unreadCount,
                ),
                _buildTabItem(
                  icon: CupertinoIcons.settings,
                  label: 'Definições',
                  isSelected: _selectedIndex == 3,
                  onTap: () => _handleNavigation(3),
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
    final Color tulipTreeColor = Color(0xFFffbe45);
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
                            color: tulipTreeColor.withAlpha(
                              (255 * 0.3).round(),
                            ),
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

  bool _isBusinessHours() {
    final now = DateTime.now();
    final hour = now.hour;
    return hour >= 9 && hour < 18;
  }
}
