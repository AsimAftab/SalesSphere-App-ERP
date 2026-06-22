import 'package:flutter/material.dart';

import 'package:sales_sphere_erp/features/collection_plus/domain/cheque_status.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_option_picker.dart';

/// Cheque-status selection field built on the shared [CustomOptionPicker]
/// — only surfaced on the form when the payment mode is `cheque`. The
/// fixed [ChequeStatus] set is offered as string labels; the picked
/// label is mapped back to the enum via [chequeStatusFromLabel].
///
/// `CustomOptionPicker` carries no `validator`, so required-ness is
/// enforced by the form on submit (the add/edit pages guard on a null
/// cheque status when the mode is cheque).
class ChequeStatusField extends StatelessWidget {
  const ChequeStatusField({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final ChequeStatus? value;
  final ValueChanged<ChequeStatus?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return CustomOptionPicker(
      value: value?.label,
      options: <String>[for (final s in ChequeStatus.values) s.label],
      onChanged: (label) => onChanged(chequeStatusFromLabel(label)),
      enabled: enabled,
      label: 'Cheque Status',
      hintText: 'Select cheque status',
      prefixIcon: Icons.fact_check_outlined,
      sheetTitle: 'Select Cheque Status',
      sheetIcon: Icons.fact_check_outlined,
    );
  }
}
