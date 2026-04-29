import 'package:flutter/material.dart';

/// Application color constants
class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF163355);
  static const Color primaryDark = Color(0xFF163355);
  static const Color primaryLight = Color(0xFFBB86FC);

  // Secondary Colors
  static const Color secondary = Color(0xFF197ADC);
  static const Color secondaryDark = Color(0xFF018786);
  static const Color secondaryLight = Color(0xFF66FFF9);

  // Background Colors
  static const Color background = Color(0xFFF1F4FC);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textDisabled = Color(0xFFBDBDBD);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textOrange = Color(0xFFFF7029);
  static const Color textdark = Color(0xDD000000);

  // Icons Colors
  static const Color iconsColorSecondary = Color(0xFF999999);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFB00020);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF2196F3);

  // Attendance Status Colors (Tailwind-style)
  static const Color green500 = Color(0xFF22C55E); // Present (P)
  static const Color red500 = Color(0xFFEF4444); // Absent (A)
  static const Color blue500 = Color(0xFF3B82F6); // Weekly Off (W)
  static const Color yellow500 = Color(0xFFEAB308); // Leave (L)
  static const Color purple500 = Color(0xFFA855F7); // Half Day (H)

  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF424242);
  static const Color divider = Color(0xFFBDBDBD);

  // Grey Shades
  static const Color greyLight = Color(0xFFE0E0E0);
  static const Color greyMedium = Color(0xFF9E9E9E);

  // Semantic Colors
  static const Color positive = Color(0xFF4CAF50);
  static const Color negative = Color(0xFFF44336);
  static const Color neutral = Color(0xFF9E9E9E);

  // Transparent
  static const Color transparent = Colors.transparent;

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadow Colors
  static Color shadow = Colors.black.withValues(alpha: 0.1);
  static Color shadowDark = Colors.black.withValues(alpha: 0.3);

  // Overlay Colors
  static Color overlay = Colors.black.withValues(alpha: 0.5);
  static Color overlayLight = Colors.black.withValues(alpha: 0.3);

  // Chart Colors
  static const List<Color> chartColors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFFC107),
    Color(0xFFFF5722),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
  ];
}
