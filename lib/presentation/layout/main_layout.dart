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
import '../../features/profile/presentation/pages/profile_page.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(MainLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _selectedIndex = widget.currentIndex;
    }
  }

  void _handleNavigation(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar:
          isSmallScreen &&
                  _selectedIndex !=
                      0 // Don't show app bar on home page
              ? PreferredSize(
                preferredSize: const Size.fromHeight(80),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      surfaceTintColor: Colors.transparent,
                      toolbarHeight: 80,
                      leading: null,
                      title: Container(
                        height: 80,
                        alignment: Alignment.center,
                        child: LogoWidget(height: 80, darkMode: isDark),
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
          color: const Color(0xFFFAFAFA), // Daisy white color
        ),
        child: Stack(
          children: [
            // Main content
            _buildMainContent(isSmallScreen),

            // Bottom Navigation for Mobile
            if (isSmallScreen) _buildMobileNavBar(context),

            // Side Navigation for Desktop
            if (!isSmallScreen) _buildSidebar(context, textColor, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isSmallScreen) {
    return Positioned(
      top: isSmallScreen ? (_selectedIndex == 0 ? 0 : 80) : 0,
      left: isSmallScreen ? 0 : AppStyles.sidebarWidth,
      right: 0,
      bottom: isSmallScreen ? AppStyles.navBarHeight : 0,
      child: ScrollConfiguration(
        behavior: const NoScrollbarBehavior(),
        child: widget.child,
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
            decoration: AppStyles.sidebarDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // Logo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: LogoWidget(height: 50, darkMode: isDark),
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
          icon: CupertinoIcons.person,
          label: l10n.navProfile,
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
                Icon(
                  icon,
                  color:
                      isSelected
                          ? Theme.of(context).primaryColor
                          : textColor.withOpacity(0.7),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color:
                          isSelected
                              ? Theme.of(context).primaryColor
                              : textColor.withOpacity(0.7),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
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
                      ? Colors.black.withOpacity(0.2)
                      : Colors.white.withOpacity(0.2),
              border: Border(
                top: BorderSide(
                  color:
                      isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabItem(
                  icon: CupertinoIcons.house,
                  selectedIcon: CupertinoIcons.house_fill,
                  label: l10n.navHome,
                  isSelected: _selectedIndex == 0,
                  onTap: () => _handleNavigation(0),
                ),
                _buildTabItem(
                  icon: CupertinoIcons.person_2,
                  selectedIcon: CupertinoIcons.person_2_fill,
                  label: l10n.navClients,
                  isSelected: _selectedIndex == 1,
                  onTap: () => _handleNavigation(1),
                ),
                _buildTabItem(
                  icon: CupertinoIcons.bubble_left,
                  selectedIcon: CupertinoIcons.bubble_left_fill,
                  label: l10n.navMessages,
                  isSelected: _selectedIndex == 2,
                  onTap: () => _handleNavigation(2),
                  badgeCount: unreadCount,
                ),
                _buildTabItem(
                  icon: CupertinoIcons.person,
                  selectedIcon: CupertinoIcons.person_fill,
                  label: l10n.navProfile,
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
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color:
                      isSelected
                          ? Theme.of(context).primaryColor
                          : textColor.withOpacity(0.7),
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
              style: TextStyle(
                color:
                    isSelected
                        ? Theme.of(context).primaryColor
                        : textColor.withOpacity(0.7),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
