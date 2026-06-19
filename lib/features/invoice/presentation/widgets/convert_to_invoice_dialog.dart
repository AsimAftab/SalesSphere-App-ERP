import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';

/// Asks for the expected delivery date when converting an estimate into a
/// committed invoice (invoices require one). Resolves to the picked
/// [DateTime] on confirm, or `null` on cancel / dismiss.
class ConvertToInvoiceDialog extends StatefulWidget {
  const ConvertToInvoiceDialog({super.key});

  static Future<DateTime?> show(BuildContext context) {
    return showDialog<DateTime>(
      context: context,
      builder: (_) => const ConvertToInvoiceDialog(),
    );
  }

  @override
  State<ConvertToInvoiceDialog> createState() => _ConvertToInvoiceDialogState();
}

class _ConvertToInvoiceDialogState extends State<ConvertToInvoiceDialog> {
  final _dateController = TextEditingController();
  DateTime? _deliveryDate;

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: AppColors.surface,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ── Header ─────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              color: AppColors.secondary.withValues(alpha: 0.10),
              padding: EdgeInsets.symmetric(vertical: 22.h, horizontal: 24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 56.r,
                    height: 56.r,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      color: AppColors.secondary,
                      size: 30.sp,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Convert to Invoice',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            // ── Body ───────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 18.h, 24.w, 20.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Set the expected delivery date to commit this estimate '
                    'as an invoice.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.sp,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 18.h),
                  CustomDatePicker(
                    controller: _dateController,
                    label: 'Expected delivery date',
                    hintText: 'Select a date',
                    prefixIcon: Icons.local_shipping_outlined,
                    initialDate: _deliveryDate,
                    // Delivery can't be in the past — today is the earliest
                    // selectable day.
                    firstDate: DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    ),
                    onDateSelected: (date) =>
                        setState(() => _deliveryDate = date),
                  ),
                  SizedBox(height: 22.h),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedCustomButton(
                          label: 'Cancel',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Confirm',
                          isDisabled: _deliveryDate == null,
                          onPressed: _deliveryDate == null
                              ? null
                              : () => Navigator.of(context).pop(_deliveryDate),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
