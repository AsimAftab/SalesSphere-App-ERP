import 'package:flutter/material.dart';

import 'package:sales_sphere_erp/features/collection_plus/domain/payment_mode.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_option_picker.dart';

/// Payment-mode selection field built on the shared [CustomOptionPicker]
/// — the same bottom-sheet component the category / party-type fields
/// use, so the pickers read as the same family. The fixed [PaymentMode]
/// set is offered as string labels; the picked label is mapped back to
/// the enum via [paymentModeFromLabel].
///
/// `CustomOptionPicker` carries no `validator`, so required-ness is
/// enforced by the form on submit (the add/edit pages guard on a null
/// payment mode).
class PaymentModeField extends StatelessWidget {
  const PaymentModeField({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final PaymentMode? value;
  final ValueChanged<PaymentMode?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return CustomOptionPicker(
      value: value?.label,
      options: <String>[for (final m in PaymentMode.values) m.label],
      onChanged: (label) => onChanged(paymentModeFromLabel(label)),
      enabled: enabled,
      label: 'Payment Mode',
      hintText: 'Select payment mode',
      prefixIcon: Icons.payments_outlined,
      sheetTitle: 'Select Payment Mode',
      sheetIcon: Icons.payments_outlined,
    );
  }
}
