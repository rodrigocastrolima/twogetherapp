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
        ? theme.colorScheme.surface // For home page, allows ResellerHomePage to control its specific background layers
        : theme.colorScheme.background; // For other pages, use the darker background

    final bool showNavigation =
        widget.location != '/change-password'; // Renamed for clarity

    return Scaffold(
      backgroundColor: effectiveBackgroundColor, // Use effective background color
      extendBodyBehindAppBar:
          true, // Keep for homepage transparent app bar effect
      extendBody: true, // Keep for homepage transparent app bar effect
      appBar:
          (isSmallScreen && _selectedIndex != 0 && showNavigation)
              ? _buildMobileAppBar(context, theme)
              : null,
      body: Container(
        decoration: BoxDecoration(
          color: effectiveBackgroundColor, // Use effective background color
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
    final isOnline = _isBusinessHours();
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
            leading: _selectedIndex == 2 ? null : null,
            title: _selectedIndex == 2
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Suporte Twogether',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          boxShadow: isOnline
                              ? [
                                  BoxShadow(
                                    color: Colors.green.withAlpha((255 * 0.4).round()),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ],
                  )
                : Container(
                    height: 56.0, 
                    alignment: Alignment.center,
                    child: LogoWidget(
                      height: 40, 
                      darkMode: theme.brightness == Brightness.dark,
                    ),
                  ),
            centerTitle: true,
            actions: const [],
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
      return Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4,
            child: Image.asset(
              'assets/images/backgrounds/homepage.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey,
                ); // Fallback for image load error
              },
            ),
          ),
          content, // The SafeArea wrapped content
        ],
      );
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
    // Match mobile nav bar: Apply 85% opacity
    final Color sidebarBackgroundColorWithOpacity =
        isDark
            ? AppTheme.darkNavBarBackground.withAlpha((255 * 0.85).round())
            : Colors.white.withAlpha((255 * 0.85).round());
    final Color textColor = isDark ? Colors.white : Colors.black;
    final unreadCount = ref
        .watch(unreadMessagesCountProvider)
        .maybeWhen(data: (count) => count, orElse: () => 0);

    return Positioned(
      top: 0,
      left: 0,
      bottom: 0,
      width: AppStyles.sidebarWidth, // Defined in ui_styles.dart
      child: ClipRect(
        child: BackdropFilter(
          filter: AppStyles.standardBlur, // Use the same blur as mobile
          child: Container(
            decoration: BoxDecoration(
              color:
                  sidebarBackgroundColorWithOpacity, // Use color with opacity
              border: Border(
                right: BorderSide(
                  color: theme.dividerColor.withAlpha((255 * 0.1).round()),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: LogoWidget(height: 60, darkMode: isDark), // SVG Logo
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
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
                      const SizedBox(height: 12),
                      _buildSidebarItem(
                        icon: CupertinoIcons.person_2,
                        label: 'Clientes',
                        isSelected: currentIndex == 1,
                        onTap: () => _handleNavigation(1),
                        textColor: textColor,
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      _buildSidebarItem(
                        icon: CupertinoIcons.bubble_left,
                        label: 'Mensagens',
                        isSelected: currentIndex == 2,
                        onTap: () => _handleNavigation(2),
                        badgeCount: unreadCount,
                        textColor: textColor,
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
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
    required ThemeData theme, // Pass theme for AppStyles
  }) {
    final Color tulipTreeColor = Color(
      0xFFffbe45,
    ); // Keep this specific color for selection

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration:
          isSelected
              ? AppStyles.activeItemHighlight(context)
              : null, // Use AppStyles for highlight
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
                    width: AppStyles.badgeSize, // From ui_styles.dart
                    height: AppStyles.badgeSize, // From ui_styles.dart
                    decoration:
                        AppStyles.notificationBadge, // From ui_styles.dart
                    alignment: Alignment.center,
                    child: Text(
                      badgeCount.toString(),
                      style: AppStyles.badgeTextStyle(
                        context,
                      ), // From ui_styles.dart
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
                  color: theme.dividerColor.withAlpha((255 * 0.1).round()),
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
    final Color tulipTreeColor = Color(0xFFffbe45);
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
    // Example: Business hours 9 AM to 6 PM (18:00)
    return hour >= 9 && hour < 18;
  }
}
