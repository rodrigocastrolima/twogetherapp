import 'package:flutter/material.dart';

/// A clean, cardless list item for notifications, clients, opportunities, etc.
/// - Shows a leading icon/avatar, title, optional subtitle, optional trailing widget, and optional unread dot.
/// - Uses a subtle hover/focus background and a simple bottom divider.
/// - No elevation, no card, just a flat row.
class SimpleListItem extends StatefulWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isUnread;
  final EdgeInsetsGeometry? padding;

  const SimpleListItem({
    Key? key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isUnread = false,
    this.padding,
  }) : super(key: key);

  @override
  State<SimpleListItem> createState() => _SimpleListItemState();
}

class _SimpleListItemState extends State<SimpleListItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = _isHovering
        ? (isDark
            ? theme.colorScheme.surfaceVariant.withOpacity(0.32)
            : theme.colorScheme.surfaceVariant.withOpacity(0.22))
        : Colors.transparent;
    final textColor = theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;
    final subtitleColor = theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ?? theme.colorScheme.onSurfaceVariant;
    final unreadDotColor = const Color(0xFF3B82F6);

    // Use only vertical padding for the outer container, horizontal goes inside
    final rowPadding = widget.padding ?? const EdgeInsets.symmetric(vertical: 0);
    // Subtitle style: smaller and lighter
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: subtitleColor,
      fontSize: 13,
      fontWeight: FontWeight.normal,
      fontFamily: theme.textTheme.bodySmall?.fontFamily,
    );
    const double verticalContentSpacing = 18;
    const double horizontalContentPadding = 24;

    // Use a more visible highlight color for hover
    final Color highlightColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);
    final Color effectiveBgColor = _isHovering ? highlightColor : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: InkWell(
        onTap: widget.onTap,
        splashColor: theme.colorScheme.primary.withOpacity(0.08),
        highlightColor: Colors.transparent,
        child: Container(
          color: effectiveBgColor,
          padding: rowPadding,
          child: Column(
            children: [
              const SizedBox(height: verticalContentSpacing),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: horizontalContentPadding),
                child: Row(
                  crossAxisAlignment: widget.subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    if (widget.leading != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: widget.leading!,
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                    fontFamily: theme.textTheme.bodyLarge?.fontFamily,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.isUnread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: unreadDotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          if (widget.subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                widget.subtitle!,
                                style: subtitleStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.trailing != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: widget.trailing!,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: verticalContentSpacing),
              Divider(
                height: 1,
                thickness: 0.5,
                color: theme.dividerColor.withOpacity(0.10),
                indent: 0,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 