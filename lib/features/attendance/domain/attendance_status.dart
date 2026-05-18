import 'package:flutter/material.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Single attendance state a calendar day can be in. The wire DTO
/// stores this as a lowercase string (`'present'`, `'absent'`, etc.);
/// the repository maps to/from this enum at the domain boundary.
enum AttendanceStatus { present, absent, leave, halfDay, weeklyOff }

/// Per-status icon + accent. Single source so the legend, calendar
/// dots, list pills, and detail hero all stay in lockstep.
extension AttendanceStatusPalette on AttendanceStatus {
  ({IconData icon, Color accent, String label}) get palette {
    switch (this) {
      case AttendanceStatus.present:
        return (
          icon: Icons.check_circle_rounded,
          accent: AppColors.green500,
          label: 'Present',
        );
      case AttendanceStatus.absent:
        return (
          icon: Icons.cancel_rounded,
          accent: AppColors.red500,
          label: 'Absent',
        );
      case AttendanceStatus.leave:
        return (
          icon: Icons.event_busy_rounded,
          accent: AppColors.yellow500,
          label: 'Leave',
        );
      case AttendanceStatus.halfDay:
        return (
          icon: Icons.schedule_rounded,
          accent: AppColors.purple500,
          label: 'Half-Day',
        );
      case AttendanceStatus.weeklyOff:
        return (
          icon: Icons.home_rounded,
          accent: AppColors.blue500,
          label: 'Weekly Off',
        );
    }
  }
}
