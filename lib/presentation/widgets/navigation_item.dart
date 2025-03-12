import 'package:flutter/material.dart';

class NavigationItem {
  final Icon icon;
  final Icon activeIcon;
  final String label;

  const NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
