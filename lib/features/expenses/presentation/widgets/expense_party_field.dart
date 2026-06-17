import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_party.dart';
import 'package:sales_sphere_erp/features/expenses/presentation/widgets/expense_party_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

/// Field-shaped tappable that opens [showExpensePartyPicker] on tap and
/// forwards the user's pick (or clear) back via [onChanged]. Built on
/// `PrimaryTextField` (read-only + onTap) so the height + decoration
/// match every other field on the form — mirrors `NoteLinkField`.
///
/// Optional — leaving it empty is valid, so there's no validator.
class ExpensePartyField extends StatefulWidget {
  const ExpensePartyField({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final ExpenseParty? value;

  /// Fired with the picked party, or `null` when the user clears the
  /// selection from inside the bottom sheet.
  final ValueChanged<ExpenseParty?> onChanged;
  final bool enabled;

  @override
  State<ExpensePartyField> createState() => _ExpensePartyFieldState();
}

class _ExpensePartyFieldState extends State<ExpensePartyField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.value?.name ?? '';
  }

  @override
  void didUpdateWidget(ExpensePartyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    final next = widget.value?.name ?? '';
    if (_controller.text == next) return;
    // Defer the controller mutation out of the parent's build window —
    // setting `.text` synchronously fires TextFormField's listener
    // which trips Flutter's build-phase assertion. (Same reason as
    // `NoteLinkField`.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.text == next) return;
      _controller.text = next;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final result = await showExpensePartyPicker(context, current: widget.value);
    if (!mounted || result == null) return;
    if (result.cleared) {
      widget.onChanged(null);
    } else if (result.value != null) {
      widget.onChanged(result.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryTextField(
      controller: _controller,
      label: 'Party (Optional)',
      hintText: 'Tap to link a party',
      prefixIcon: Icons.storefront_outlined,
      enabled: widget.enabled,
      readOnly: true,
      onTap: _open,
      suffixWidget: widget.enabled
          ? Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.textSecondary,
                size: 20.sp,
              ),
            )
          : null,
    );
  }
}
