import 'package:flutter/material.dart';

/// A widget that displays the app logo with support for dark mode
class LogoWidget extends StatelessWidget {
  final double height;
  final double? width;
  final bool darkMode;

  const LogoWidget({
    Key? key,
    this.height = 60,
    this.width,
    this.darkMode = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String logoAsset =
        darkMode
            ? 'assets/images/twogether_logo_dark.png'
            : 'assets/images/twogether_logo_light_br.png';

    return Image.asset(
      logoAsset,
      height: height,
      width: width,
      fit: BoxFit.contain,
    );
  }
}
