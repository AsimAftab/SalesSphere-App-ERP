import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Renders [child] underneath a transparent status bar with **light** icons.
/// Use on screens with a dark background (e.g. the auth gradient).
class LightStatusBar extends StatelessWidget {
  const LightStatusBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: child,
    );
  }
}

/// Renders [child] underneath a transparent status bar with **dark** icons.
/// Use on screens with a light background (e.g. the authenticated app shell).
class DarkStatusBar extends StatelessWidget {
  const DarkStatusBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: child,
    );
  }
}
