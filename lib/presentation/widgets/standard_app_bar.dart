import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'logo.dart';

/// Standardized AppBar widget for consistent behavior across all pages
class StandardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final String? title;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;
  final bool centerTitle;
  final double? elevation;
  final Color? backgroundColor;
  final bool showLogo;

  const StandardAppBar({
    super.key,
    this.showBackButton = false,
    this.title,
    this.actions,
    this.onBackPressed,
    this.centerTitle = true,
    this.elevation = 0,
    this.backgroundColor = Colors.transparent,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      backgroundColor: backgroundColor,
      elevation: elevation,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 56.0, // Consistent height
      leading: showBackButton
          ? IconButton(
              icon: Icon(
                CupertinoIcons.chevron_left,
                color: theme.colorScheme.onSurface,
              ),
              onPressed: onBackPressed ??
                  () {
                    if (context.canPop()) {
                      context.pop();
                    }
                  },
            )
          : null,
      title: showLogo
          ? LogoWidget(
              height: 60, // Consistent logo size
              darkMode: isDark,
            )
          : (title != null ? Text(title!) : null),
      centerTitle: centerTitle,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56.0);
} 