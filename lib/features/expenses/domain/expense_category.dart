import 'package:flutter/material.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// The fixed set of expense-claim categories the field user can pick
/// from. UI-facing — decoupled from any wire shape so a future backend
/// rename doesn't ripple into widgets. Each category carries its own
/// display label, icon and accent colour so the picker, the field's
/// chip, and the list rows all read consistently.
enum ExpenseCategory {
  travel,
  meals,
  accommodation,
  fuel,
  supplies,
  communication,
  other,
}

/// Presentation metadata for an [ExpenseCategory]. Kept beside the enum
/// so the label/icon/accent live in one place.
extension ExpenseCategoryX on ExpenseCategory {
  String get label => switch (this) {
    ExpenseCategory.travel => 'Travel',
    ExpenseCategory.meals => 'Meals',
    ExpenseCategory.accommodation => 'Accommodation',
    ExpenseCategory.fuel => 'Fuel',
    ExpenseCategory.supplies => 'Supplies',
    ExpenseCategory.communication => 'Communication',
    ExpenseCategory.other => 'Other',
  };

  IconData get icon => switch (this) {
    ExpenseCategory.travel => Icons.flight_takeoff_outlined,
    ExpenseCategory.meals => Icons.restaurant_outlined,
    ExpenseCategory.accommodation => Icons.hotel_outlined,
    ExpenseCategory.fuel => Icons.local_gas_station_outlined,
    ExpenseCategory.supplies => Icons.inventory_2_outlined,
    ExpenseCategory.communication => Icons.phone_iphone_outlined,
    ExpenseCategory.other => Icons.category_outlined,
  };

  Color get accent => switch (this) {
    ExpenseCategory.travel => AppColors.secondary,
    ExpenseCategory.meals => AppColors.warning,
    ExpenseCategory.accommodation => AppColors.purple500,
    ExpenseCategory.fuel => AppColors.info,
    ExpenseCategory.supplies => AppColors.green500,
    ExpenseCategory.communication => AppColors.tertiary,
    ExpenseCategory.other => AppColors.textSecondary,
  };
}

/// Resolves an [ExpenseCategory] from its display [label]. Returns
/// `null` when nothing matches — used by the string-based option picker
/// to map the picked label back to the enum.
ExpenseCategory? expenseCategoryFromLabel(String? label) {
  if (label == null) return null;
  for (final c in ExpenseCategory.values) {
    if (c.label == label) return c;
  }
  return null;
}
