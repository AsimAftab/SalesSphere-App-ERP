import 'package:flutter/material.dart';

import 'package:sales_sphere_erp/shared/widgets/custom_option_picker.dart';

/// Bank-name selection field built on the shared [CustomOptionPicker] —
/// surfaced on the form when the payment mode is cheque or bank
/// transfer. Offers the known [banks] catalogue plus an "Add a
/// different bank" entry so a field user can record a bank that isn't on
/// the list (mirrors the party-type "add new" behaviour). Both a picked
/// option and a typed-in name flow back through [onChanged].
///
/// `CustomOptionPicker` carries no `validator`, so required-ness is
/// enforced by the form on submit (the add/edit pages guard on a null /
/// empty bank when the mode requires one).
class BankNameField extends StatelessWidget {
  const BankNameField({
    required this.value,
    required this.onChanged,
    required this.banks,
    this.enabled = true,
    super.key,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final List<String> banks;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return CustomOptionPicker(
      value: value,
      options: banks,
      // A picked option and a typed-in name are both just the bank
      // value, so route both callbacks to the same setter.
      onChanged: onChanged,
      onAddNew: onChanged,
      enabled: enabled,
      label: 'Bank Name',
      hintText: 'Select or add a bank',
      prefixIcon: Icons.account_balance_outlined,
      sheetTitle: 'Select Bank',
      sheetIcon: Icons.account_balance_outlined,
      addNewLabel: 'Add a different bank',
      newItemLabel: 'Bank name',
    );
  }
}
