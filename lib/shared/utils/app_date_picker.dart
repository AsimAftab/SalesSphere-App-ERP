import 'package:flutter/material.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Branded wrapper around Material's [showDatePicker]. Forces a light
/// colour scheme + explicit [DatePickerThemeData] so every day cell,
/// weekday label, year cell, and action button is rendered in the app's
/// brand palette — independent of the device's system theme.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    builder: (ctx, child) => Theme(
      data: ThemeData.light().copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onSurface: AppColors.textPrimary,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.secondary,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: AppColors.surface,
          headerBackgroundColor: AppColors.primary,
          headerForegroundColor: AppColors.textWhite,

          // Day numbers — explicit dark text so they stay legible.
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.textHint;
            }
            if (states.contains(WidgetState.selected)) {
              return AppColors.textWhite;
            }
            return AppColors.textPrimary;
          }),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return Colors.transparent;
          }),

          // Today's date — outlined in primary, filled when also selected.
          todayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.textWhite;
            }
            return AppColors.primary;
          }),
          todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return Colors.transparent;
          }),
          todayBorder: const BorderSide(color: AppColors.primary),

          // Year-picker mode.
          yearForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.textWhite;
            }
            return AppColors.textPrimary;
          }),
          yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return Colors.transparent;
          }),

          weekdayStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          dayStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          yearStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
      ),
      child: child!,
    ),
  );
}
