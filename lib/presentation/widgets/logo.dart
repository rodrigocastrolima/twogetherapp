import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    const String logoAssetSvg = 'assets/images/twogether-retail_logo-04.svg';

    final Color svgColor = darkMode ? Colors.white : Colors.black;

    return SvgPicture.asset(
      logoAssetSvg,
      height: height,
      width: width,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(svgColor, BlendMode.srcIn),
    );
  }
}
