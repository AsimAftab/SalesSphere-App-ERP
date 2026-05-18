import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Read-only date field that opens [showDatePicker] on tap. Visual style
/// mirrors `PrimaryTextField` so the field blends into surrounding form
/// inputs. Picked dates are written to [controller] formatted as
/// `dd MMM yyyy` and surfaced as a raw [DateTime] via [onDateSelected].
class CustomDatePicker extends StatefulWidget {
  const CustomDatePicker({
    required this.controller,
    required this.hintText,
    super.key,
    this.label,
    this.prefixIcon,
    this.enabled = true,
    this.validator,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.selectableDayPredicate,
    this.onDateSelected,
  });

  final TextEditingController controller;
  final String hintText;
  final String? label;
  final IconData? prefixIcon;
  final bool enabled;
  final String? Function(String?)? validator;
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool Function(DateTime)? selectableDayPredicate;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  State<CustomDatePicker> createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<CustomDatePicker> {
  String? _validatorError;

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final firstDate = widget.firstDate ?? DateTime(1900);
    final lastDate = widget.lastDate ?? DateTime(2100);

    var initialDate = widget.initialDate ?? now;
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: _ensureSelectableInitialDate(
        initialDate,
        firstDate,
        lastDate,
      ),
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: widget.selectableDayPredicate,
      builder: (context, child) {
        // Force a light base — the app declares a dark theme too, and
        // inheriting via Theme.of(context) lets dark-mode tokens
        // (datePickerTheme, dialog surfaces) bleed into the calendar.
        return Theme(
          data: ThemeData.light().copyWith(
            // Surfaces and onPrimary are stated explicitly even though
            // they match ColorScheme.light()'s defaults — being loud
            // about them protects against default-resolution surprises
            // when this Theme is composed under different parents.
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              // ignore: avoid_redundant_argument_values, see comment above
              onPrimary: Colors.white,
              // ignore: avoid_redundant_argument_values, see comment above
              surface: Colors.white,
              onSurface: AppColors.textdark,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      widget.onDateSelected?.call(picked);
      widget.controller.text = DateFormat('dd MMM yyyy').format(picked);
    }
  }

  DateTime _ensureSelectableInitialDate(
    DateTime initial,
    DateTime first,
    DateTime last,
  ) {
    final predicate = widget.selectableDayPredicate;
    if (predicate == null || predicate(initial)) return initial;

    var current = initial.isBefore(first) ? first : initial;
    if (current.isAfter(last)) current = last;

    while (!current.isAfter(last)) {
      if (predicate(current)) return current;
      current = current.add(const Duration(days: 1));
    }
    return first;
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled;
    final shouldShowGreyStyle = !isEnabled;
    final displayError = _validatorError;
    final hasError = displayError != null && displayError.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          readOnly: true,
          enabled: isEnabled,
          onTap: isEnabled ? () => _selectDate(context) : null,
          style: TextStyle(
            color: shouldShowGreyStyle
                ? AppColors.textSecondary.withValues(alpha: 0.6)
                : AppColors.textPrimary,
            fontSize: 15.sp,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
            hintText: widget.hintText,
            labelText: widget.label,
            floatingLabelBehavior: widget.label != null
                ? FloatingLabelBehavior.auto
                : FloatingLabelBehavior.never,
            labelStyle: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
              fontFamily: 'Poppins',
            ),
            floatingLabelStyle: TextStyle(
              color: hasError
                  ? AppColors.error
                  : (shouldShowGreyStyle
                        ? AppColors.textSecondary
                        : AppColors.secondary),
              fontSize: 13.sp,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
            hintStyle: TextStyle(
              color: shouldShowGreyStyle
                  ? AppColors.textHint.withValues(alpha: 0.5)
                  : AppColors.textHint,
              fontSize: 14.sp,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    color: hasError
                        ? AppColors.error
                        : (shouldShowGreyStyle
                              ? AppColors.textSecondary.withValues(alpha: 0.4)
                              : AppColors.textSecondary),
                    size: 20.sp,
                  )
                : null,
            suffixIcon: isEnabled
                ? Icon(
                    Icons.calendar_today,
                    color: AppColors.primary,
                    size: 18.sp,
                  )
                : null,
            filled: true,
            fillColor: hasError
                ? AppColors.error.withValues(alpha: 0.05)
                : (shouldShowGreyStyle
                      ? Colors.grey.shade100
                      : AppColors.surface),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.border,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.border,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.secondary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: AppColors.border.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            errorStyle: const TextStyle(height: 0, fontSize: 0),
            errorMaxLines: 1,
          ),
          validator: (value) {
            final v = widget.validator;
            if (v == null) return null;
            final error = v(value);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _validatorError != error) {
                setState(() => _validatorError = error);
              }
            });
            return error;
          },
        ),
        if (hasError)
          Padding(
            padding: EdgeInsets.only(top: 6.h, left: 16.w, right: 16.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 14.sp, color: AppColors.error),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    displayError,
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12.sp,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
