import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/expenses/presentation/providers/expenses_providers.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_option_picker.dart';

/// Category selection field built on the shared [CustomOptionPicker] —
/// the same bottom-sheet component the party-type field uses, so the two
/// pickers read as the same family. Connected to [expenseCategoriesProvider]
/// (the org-managed catalogue); the picked value is the category **name**
/// string stored on the claim.
///
/// Unlike the party-type picker there's no "Add new" affordance — reps
/// only read the catalogue (admins manage it from the web). `onBeforeOpen`
/// awaits the catalogue so the sheet never opens empty.
///
/// `CustomOptionPicker` carries no `validator`, so required-ness is
/// enforced by the form on submit (the add/edit pages guard on a null
/// category).
class ExpenseCategoryField extends ConsumerWidget {
  const ExpenseCategoryField({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCategories = ref.watch(expenseCategoriesProvider);
    return CustomOptionPicker(
      value: value,
      options: asyncCategories.value ?? const <String>[],
      onChanged: onChanged,
      // Pre-load the catalogue so the sheet always shows the existing
      // categories — without this an immediate tap (before the provider
      // resolves) opens an empty sheet.
      onBeforeOpen: () => ref.read(expenseCategoriesProvider.future),
      enabled: enabled,
      label: 'Expense Category',
      hintText: 'Select expense category',
      prefixIcon: Icons.category_outlined,
      sheetTitle: 'Select Expense Category',
      sheetIcon: Icons.category_outlined,
    );
  }
}
