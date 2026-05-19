import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/leaves/domain/leave.dart';
import 'package:sales_sphere_erp/features/leaves/presentation/widgets/leave_category_picker.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

/// Field-shaped tappable that opens [showLeaveCategoryPicker] on tap
/// and forwards the user's pick (or clear) back via [onChanged]. Built
/// on top of `PrimaryTextField` (read-only + onTap) so the height +
/// decoration match every other field on the form pixel-for-pixel —
/// the user can't type into it but it inherits the rest of the
/// field's behaviour for free.
class LeaveCategoryField extends StatefulWidget {
  const LeaveCategoryField({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final LeaveCategory? value;

  /// Fired with the picked category, or `null` when the user clears
  /// from inside the bottom sheet.
  final ValueChanged<LeaveCategory?> onChanged;
  final bool enabled;

  @override
  State<LeaveCategoryField> createState() => _LeaveCategoryFieldState();
}

class _LeaveCategoryFieldState extends State<LeaveCategoryField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncControllerToValue();
  }

  @override
  void didUpdateWidget(LeaveCategoryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _syncControllerToValue();
    }
  }

  void _syncControllerToValue() {
    final v = widget.value;
    _controller.text = v == null ? '' : leaveCategoryLabel(v);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final result = await showLeaveCategoryPicker(
      context,
      current: widget.value,
    );
    if (!mounted || result == null) return;
    if (result.cleared) {
      widget.onChanged(null);
    } else if (result.value != null) {
      widget.onChanged(result.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.value;
    return PrimaryTextField(
      controller: _controller,
      label: 'Category',
      hintText: 'Tap to pick a leave category',
      prefixIcon: selection == null
          ? Icons.category_outlined
          : leaveCategoryIcon(selection),
      enabled: widget.enabled,
      readOnly: true,
      onTap: _open,
      validator: (v) => Validators.requiredFieldCustom(
        v,
        'Please pick a leave category',
      ),
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
