import 'package:flutter/material.dart';

/// Unified notification badge component used across the app
/// Supports both boolean (simple dot) and count (numbered) modes
class UnifiedNotificationBadge extends StatelessWidget {
  final Widget child;
  final int count;
  final bool show;
  final Color? badgeColor;
  final Color? textColor;
  final double? size;
  final EdgeInsets? offset;
  final bool showZero;

  const UnifiedNotificationBadge({
    Key? key,
    required this.child,
    this.count = 0,
    this.show = false,
    this.badgeColor,
    this.textColor,
    this.size,
    this.offset,
    this.showZero = false,
  }) : super(key: key);

  /// Create a simple dot badge (boolean indicator)
  const UnifiedNotificationBadge.dot({
    Key? key,
    required this.child,
    required this.show,
    this.badgeColor,
    this.size,
    this.offset,
  }) : count = 0,
       textColor = null,
       showZero = false,
       super(key: key);

  /// Create a count badge (numbered indicator)
  const UnifiedNotificationBadge.count({
    Key? key,
    required this.child,
    required this.count,
    this.badgeColor,
    this.textColor,
    this.size,
    this.offset,
    this.showZero = false,
  }) : show = true,
       super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Determine if we should show the badge
    final shouldShow = show && (count > 0 || (count == 0 && showZero));
    
    if (!shouldShow) {
      return child;
    }

    // Get colors with theme-aware defaults
    final effectiveBadgeColor = badgeColor ?? theme.colorScheme.error;
    final effectiveTextColor = textColor ?? 
        (theme.brightness == Brightness.dark ? Colors.black : Colors.white);
    
    // Calculate badge size
    final effectiveSize = size ?? _getDefaultSize(count);
    
    // Calculate offset
    final effectiveOffset = offset ?? EdgeInsets.only(
      right: effectiveSize * 0.2,
      top: effectiveSize * 0.2,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: effectiveOffset.right,
          top: effectiveOffset.top,
          child: _buildBadge(
            context,
            effectiveBadgeColor,
            effectiveTextColor,
            effectiveSize,
          ),
        ),
      ],
    );
  }

  /// Build the actual badge widget
  Widget _buildBadge(
    BuildContext context,
    Color badgeColor,
    Color textColor,
    double size,
  ) {
    // For dot badges (count is 0 and we're just showing a dot)
    if (count == 0 && show) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: badgeColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: badgeColor.withAlpha((255 * 0.3).round()),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
      );
    }

    // For count badges
    final countText = count > 99 ? '99+' : count.toString();
    final fontSize = _getFontSize(size, countText.length);

    return Container(
      constraints: BoxConstraints(
        minWidth: size,
        minHeight: size,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: countText.length > 1 ? size * 0.2 : 0,
      ),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(size / 2),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withAlpha((255 * 0.3).round()),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        countText,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Get default badge size based on count
  double _getDefaultSize(int count) {
    if (count == 0) return 8.0; // Dot badge
    if (count < 10) return 16.0; // Single digit
    if (count < 100) return 20.0; // Double digit
    return 24.0; // 99+ badge
  }

  /// Get appropriate font size based on badge size and text length
  double _getFontSize(double badgeSize, int textLength) {
    if (textLength == 1) {
      return badgeSize * 0.6; // Single digit gets larger font
    } else if (textLength == 2) {
      return badgeSize * 0.5; // Double digit gets medium font
    } else {
      return badgeSize * 0.4; // 99+ gets smaller font
    }
  }
}

/// Icon with notification badge - common pattern in navigation
class IconWithBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool show;
  final Color? iconColor;
  final Color? badgeColor;
  final double? iconSize;
  final VoidCallback? onTap;

  const IconWithBadge({
    Key? key,
    required this.icon,
    this.count = 0,
    this.show = false,
    this.iconColor,
    this.badgeColor,
    this.iconSize,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.onSurface;
    final effectiveIconSize = iconSize ?? 24.0;

    Widget iconWidget = Icon(
      icon,
      color: effectiveIconColor,
      size: effectiveIconSize,
    );

    Widget badgedIcon = UnifiedNotificationBadge.count(
      count: count,
      badgeColor: badgeColor,
      child: iconWidget,
    );

    if (onTap != null) {
      return IconButton(
        icon: badgedIcon,
        onPressed: onTap,
        iconSize: effectiveIconSize,
      );
    }

    return badgedIcon;
  }
}

/// Text with notification badge - useful for navigation labels
class TextWithBadge extends StatelessWidget {
  final String text;
  final int count;
  final bool show;
  final TextStyle? textStyle;
  final Color? badgeColor;

  const TextWithBadge({
    Key? key,
    required this.text,
    this.count = 0,
    this.show = false,
    this.textStyle,
    this.badgeColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return UnifiedNotificationBadge.count(
      count: count,
      badgeColor: badgeColor,
      offset: const EdgeInsets.only(right: -8, top: -4),
      child: Text(
        text,
        style: textStyle,
      ),
    );
  }
}

/// Navigation item with badge - specifically for bottom navigation
class NavigationItemWithBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badgeCount;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? unselectedColor;

  const NavigationItemWithBadge({
    Key? key,
    required this.icon,
    required this.label,
    this.badgeCount = 0,
    this.isSelected = false,
    required this.onTap,
    this.selectedColor,
    this.unselectedColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveSelectedColor = selectedColor ?? theme.colorScheme.primary;
    final effectiveUnselectedColor = unselectedColor ?? 
        theme.colorScheme.onSurface.withAlpha((255 * 0.7).round());
    
    final color = isSelected ? effectiveSelectedColor : effectiveUnselectedColor;
    final fontSize = isSelected ? 12.0 : 11.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UnifiedNotificationBadge.count(
              count: badgeCount,
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 