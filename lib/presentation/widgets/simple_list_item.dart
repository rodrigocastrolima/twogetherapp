import 'package:flutter/material.dart';

/// A clean, cardless list item for notifications, clients, opportunities, etc.
/// - Shows a leading icon/avatar, title, optional subtitle, optional trailing widget, and optional unread badge.
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
  final TextStyle? titleStyle;
  final bool dynamicTitleSize;

  const SimpleListItem({
    Key? key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isUnread = false,
    this.padding,
    this.titleStyle,
    this.dynamicTitleSize = false,
  }) : super(key: key);

  @override
  State<SimpleListItem> createState() => _SimpleListItemState();
}

class _SimpleListItemState extends State<SimpleListItem> {
  bool _isHovering = false;

  Widget _buildDynamicTitle(ThemeData theme, Color textColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double fontSize = 16.0; // Start with base font size
        double minFontSize = 12.0; // Minimum readable size
        
        TextStyle style = widget.titleStyle ?? theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: textColor,
          fontFamily: theme.textTheme.bodyLarge?.fontFamily,
          fontSize: fontSize,
        ) ?? TextStyle(fontSize: fontSize, color: textColor);
        
        // Create text painter to measure text
        TextPainter textPainter = TextPainter(
          text: TextSpan(text: widget.title, style: style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        
        // Reduce font size until text fits or minimum size is reached
        while (fontSize >= minFontSize) {
          style = style.copyWith(fontSize: fontSize);
          textPainter.text = TextSpan(text: widget.title, style: style);
          textPainter.layout(maxWidth: constraints.maxWidth);
          
          if (textPainter.didExceedMaxLines || textPainter.width > constraints.maxWidth) {
            fontSize -= 0.5;
          } else {
            break;
          }
        }
        
        return Text(
          widget.title,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

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
          child: Stack(
            children: [
              // Different layout based on whether subtitle exists and is not empty
              if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                // Layout with subtitle - title at top
                Column(
                  children: [
                    const SizedBox(height: verticalContentSpacing),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: horizontalContentPadding),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                if (widget.dynamicTitleSize)
                                  SizedBox(
                                    height: 20, // Fixed height to maintain consistent card sizes
                                    child: _buildDynamicTitle(theme, textColor),
                                  )
                                else
                                  Text(
                                    widget.title,
                                    style: widget.titleStyle ?? theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: textColor,
                                      fontFamily: theme.textTheme.bodyLarge?.fontFamily,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
                )
              else
                // Layout without subtitle - centered content
                SizedBox(
                  height: 56, // Fixed height for consistency
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: horizontalContentPadding),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (widget.leading != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: widget.leading!,
                                ),
                              Expanded(
                                child: widget.dynamicTitleSize
                                  ? Align(
                                      alignment: Alignment.centerLeft,
                                      child: SizedBox(
                                        height: 20,
                                        child: _buildDynamicTitle(theme, textColor),
                                      ),
                                    )
                                  : Text(
                                      widget.title,
                                      style: widget.titleStyle ?? theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: textColor,
                                        fontFamily: theme.textTheme.bodyLarge?.fontFamily,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: theme.dividerColor.withOpacity(0.10),
                        indent: 0,
                      ),
                    ],
                  ),
                ),
              // NOVO Badge positioned aligned with subtitle text
              if (widget.isUnread && widget.subtitle != null && widget.subtitle!.isNotEmpty)
                Positioned(
                  top: verticalContentSpacing + 6.0 + 16, // verticalContentSpacing + subtitle top padding + line height
                  right: horizontalContentPadding,
                  child: Text(
                    'NOVO',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 