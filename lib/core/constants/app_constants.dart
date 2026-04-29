import 'package:flutter/material.dart';

/// Application-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'SalesSphere ERP';
  static const String defaultLocale = 'en';
  static const String fallbackLocale = 'en';

  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration defaultTimeout = Duration(seconds: 30);

  static const Curve defaultAnimationCurve = Curves.easeInOut;
}
