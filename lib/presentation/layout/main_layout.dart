import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/constants.dart';
import '../screens/home/reseller_home_page.dart';
import '../screens/clients/clients_page.dart';
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

  const MainLayout({Key? key, required this.child, required this.currentIndex})
    : super(key: key);

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
    if (oldWidget.currentIndex != widget.currentIndex) {
      setState(() {
      _selectedIndex = widget.currentIndex;
        _isTransitioning = false; // Reset transition state
      });
    }
  }

  void _handleNavigation(int index) {
    if (_selectedIndex != index && !_isTransitioning) {
      setState(() {
        _isTransitioning = true; // Mark as transitioning
      });

      // Clean transition by removing the previous screen first
      WidgetsBinding.instance.addPostFrameCallback((_) {
      // Navigate to the appropriate route
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
          context.go('/profile');
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
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    // Get unread message count
    final unreadCount = ref
        .watch(unreadMessagesCountProvider)
        .maybeWhen(data: (count) => count, orElse: () => 0);

    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 600;
    final isDesktop = width >= 1024;

    // Check if support is online (between 9am and 6pm)
    final isOnline = _isBusinessHours();

    // Use theme colors for light mode
    final Color lightBackgroundColor = Theme.of(context).colorScheme.background;

    // Use theme colors for dark mode
    final Color darkBackgroundColor = Theme.of(context).colorScheme.background;
    final Color darkNavBarColor =
        AppTheme.darkNavBarBackground; // Use the specific nav bar color

    return Scaffold(
      backgroundColor: isDark ? darkBackgroundColor : lightBackgroundColor,
      extendBodyBehindAppBar: true,
      extendBody: true, // Allow body to extend behind bottom nav
      appBar:
          isSmallScreen &&
                  _selectedIndex !=
                      0 // Don't show app bar on home page
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
                              // For Messages/Chat page, show iOS style messaging header
                              ? Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Circular avatar with logo
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
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
                                    // Name with online indicator
                                    Column(
                                      children: [
                                        // Support name
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.chatSupportName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Green dot indicator
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
                                                                .withOpacity(
                                                                  0.4,
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
                              // For other pages, show the regular logo
                              : Container(
                                height: 100,
                        alignment: Alignment.center,
                        child: LogoWidget(height: 80, darkMode: false),
                      ),
                      centerTitle: true,
                      actions: [
                        // No actions needed now
                      ],
                    ),
                  ),
                ),
              )
              : null,
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
        ),
        child: Material(
          color: Colors.transparent,
        child: Stack(
          children: [
            // Main content
            _buildMainContent(isSmallScreen),

            // Bottom Navigation for Mobile
            if (isSmallScreen) _buildMobileNavBar(context),

            // Side Navigation for Desktop
            if (!isSmallScreen) _buildSidebar(context, textColor, isDark),

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
      top: isSmallScreen ? (_selectedIndex == 0 ? 0 : 100) : 0,
      left: isSmallScreen ? 0 : AppStyles.sidebarWidth,
      right: 0,
      bottom: isSmallScreen ? AppStyles.navBarHeight : 0,
      child: ClipRect(
        child:
            _isTransitioning
                ? Container(
                  color: Theme.of(context).colorScheme.background,
                ) // Show barrier during transition
                : KeyedSubtree(
                  key: pageKey,
      child: ScrollConfiguration(
        behavior: const NoScrollbarBehavior(),
        child: widget.child,
                  ),
                ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, Color textColor, bool isDark) {
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
              color:
                  isDark
                      ? AppTheme
                          .darkNavBarBackground // Use specific dark nav color
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
                // Logo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: LogoWidget(height: 50, darkMode: false),
                ),
                const SizedBox(height: 24),
                // Navigation Items
                _buildNavigationItems(context, textColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationItems(BuildContext context, Color textColor) {
    final l10n = AppLocalizations.of(context)!;
    final unreadCount = ref
        .watch(unreadMessagesCountProvider)
        .maybeWhen(data: (count) => count, orElse: () => 0);

    return Column(
      children: [
        _buildNavItem(
          context: context,
          icon: CupertinoIcons.house,
          label: l10n.navHome,
          isSelected: _selectedIndex == 0,
          onTap: () => _handleNavigation(0),
          textColor: textColor,
        ),
        _buildNavItem(
          context: context,
          icon: CupertinoIcons.person_2,
          label: l10n.navClients,
          isSelected: _selectedIndex == 1,
          onTap: () => _handleNavigation(1),
          textColor: textColor,
        ),
        _buildNavItem(
          context: context,
          icon: CupertinoIcons.bubble_left,
          label: l10n.navMessages,
          isSelected: _selectedIndex == 2,
          onTap: () => _handleNavigation(2),
          textColor: textColor,
          badgeCount: unreadCount,
        ),
        _buildNavItem(
          context: context,
          icon: CupertinoIcons.settings,
          label: l10n.navSettings,
          isSelected: _selectedIndex == 3,
          onTap: () => _handleNavigation(3),
          textColor: textColor,
        ),
      ],
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
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
                    label,
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

  Widget _buildMobileNavBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final unreadCount = ref
        .watch(unreadMessagesCountProvider)
        .maybeWhen(data: (count) => count, orElse: () => 0);

    // Calculate width for each tab based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final tabWidth = screenWidth / 4; // 4 tabs

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
                      ? AppTheme
                          .darkNavBarBackground // Use specific dark nav color
                      : Colors.white.withOpacity(
                        0.8,
                      ), // Keep light theme semi-transparent
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
                  label: l10n.navHome,
                  isSelected: _selectedIndex == 0,
                  onTap: () => _handleNavigation(0),
                  width: tabWidth,
                ),
                _buildTabItem(
                  icon: CupertinoIcons.person_2,
                  label: l10n.navClients,
                  isSelected: _selectedIndex == 1,
                  onTap: () => _handleNavigation(1),
                  width: tabWidth,
                ),
                _buildTabItem(
                  icon: CupertinoIcons.bubble_left,
                  label: l10n.navMessages,
                  isSelected: _selectedIndex == 2,
                  onTap: () => _handleNavigation(2),
                  badgeCount: unreadCount,
                  width: tabWidth,
                ),
                _buildTabItem(
                  icon: CupertinoIcons.settings,
                  label: l10n.navSettings,
                  isSelected: _selectedIndex == 3,
                  onTap: () => _handleNavigation(3),
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

  // Helper method to check if current time is within business hours (9am-6pm)
  bool _isBusinessHours() {
    final now = DateTime.now();
    final hour = now.hour;
    return hour >= 9 && hour < 18; // 9am to 6pm
  }
}
