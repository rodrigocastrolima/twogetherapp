import 'package:flutter/material.dart';
import 'theme.dart';

class AppTextStyles {
  static const _baseTextStyle = TextStyle(
    fontFamily: 'Inter',
    letterSpacing: -0.5,
  );

  // Display styles
  static final display1 = _baseTextStyle.copyWith(
    fontSize: 56,
    fontWeight: FontWeight.bold,
  );

  // Heading styles
  static final h1 = _baseTextStyle.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

  static final h2 = _baseTextStyle.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static final h3 = _baseTextStyle.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppTheme.foreground,
  );

  // Body styles
  static final body1 = _baseTextStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static final body2 = _baseTextStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  // Button text style
  static final button = _baseTextStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  // Caption text style
  static final caption = _baseTextStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );
}
