import 'package:flutter/material.dart';

import 'package:sales_sphere_erp/features/expenses/domain/expense_category.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_option_picker.dart';

/// Category selection field built on the shared [CustomOptionPicker] —
/// the same bottom-sheet component the party-type field uses, so the
/// two pickers read as the same family. The fixed [ExpenseCategory]
/// set is offered as string labels; the picked label is mapped back to
/// the enum via [expenseCategoryFromLabel].
///
/// `CustomOptionPicker` carries no `validator`, so required-ness is
/// enforced by the form on submit (the add/edit pages guard on a null
/// category).
class ExpenseCategoryField extends StatelessWidget {
  const ExpenseCategoryField({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final ExpenseCategory? value;
  final ValueChanged<ExpenseCategory?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return CustomOptionPicker(
      value: value?.label,
      options: <String>[for (final c in ExpenseCategory.values) c.label],
      onChanged: (label) => onChanged(expenseCategoryFromLabel(label)),
      enabled: enabled,
      label: 'Expense Category',
      hintText: 'Select expense category',
      prefixIcon: Icons.category_outlined,
      sheetTitle: 'Select Expense Category',
      sheetIcon: Icons.category_outlined,
    );
  }
}
