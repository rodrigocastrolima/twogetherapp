import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/theme/theme.dart';

enum AppButtonType { primary, secondary, tertiary, destructive }

enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final bool isFullWidth;
  final bool isLoading;
  final IconData? icon;
  final bool iconAfterText;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.isFullWidth = false,
    this.isLoading = false,
    this.icon,
    this.iconAfterText = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: _getButtonStyle(),
      child: Container(
        width: isFullWidth ? double.infinity : null,
        height: _getButtonHeight(),
        child:
            isLoading
                ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getForegroundColor().withAlpha(200),
                      ),
                    ),
                  ),
                )
                : Row(
                  mainAxisSize:
                      isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _buildButtonContent(),
                ),
      ),
    );
  }

  List<Widget> _buildButtonContent() {
    if (icon == null) {
      return [Text(text, style: _getTextStyle())];
    }

    final iconWidget = Icon(icon, size: _getIconSize());
    return iconAfterText
        ? [
          Text(text, style: _getTextStyle()),
          SizedBox(width: size == AppButtonSize.small ? 4 : 8),
          iconWidget,
        ]
        : [
          iconWidget,
          SizedBox(width: size == AppButtonSize.small ? 4 : 8),
          Text(text, style: _getTextStyle()),
        ];
  }

  ButtonStyle _getButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _getBackgroundColor(),
      foregroundColor: _getForegroundColor(),
      padding: _getPadding(),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_getBorderRadius()),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (type) {
      case AppButtonType.primary:
        return AppColors.amber;
      case AppButtonType.secondary:
        return AppTheme.primary;
      case AppButtonType.tertiary:
        return Colors.transparent;
      case AppButtonType.destructive:
        return AppTheme.destructive;
    }
  }

  Color _getForegroundColor() {
    switch (type) {
      case AppButtonType.primary:
        return Colors.black;
      case AppButtonType.secondary:
        return Colors.white;
      case AppButtonType.tertiary:
        return Colors.white;
      case AppButtonType.destructive:
        return Colors.white;
    }
  }

  TextStyle _getTextStyle() {
    final baseStyle = AppTextStyles.button.copyWith(
      color: _getForegroundColor(),
      fontWeight: FontWeight.w600,
    );

    switch (size) {
      case AppButtonSize.small:
        return baseStyle.copyWith(fontSize: 14);
      case AppButtonSize.medium:
        return baseStyle;
      case AppButtonSize.large:
        return baseStyle.copyWith(fontSize: 18);
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }

  double _getButtonHeight() {
    switch (size) {
      case AppButtonSize.small:
        return 36;
      case AppButtonSize.medium:
        return 48;
      case AppButtonSize.large:
        return 56;
    }
  }

  double _getIconSize() {
    switch (size) {
      case AppButtonSize.small:
        return 16;
      case AppButtonSize.medium:
        return 20;
      case AppButtonSize.large:
        return 24;
    }
  }

  double _getBorderRadius() {
    switch (size) {
      case AppButtonSize.small:
        return 8;
      case AppButtonSize.medium:
        return 12;
      case AppButtonSize.large:
        return 16;
    }
  }
}
