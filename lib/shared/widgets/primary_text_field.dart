import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Primary Text Field Component.
///
/// Pass `label` for the standard Material floating-label behaviour — the
/// label sits inside the field at rest and animates up to the border on
/// focus or when the field has content. Pass `hintText` for the
/// placeholder rendered inside the field when it is focused and empty.
/// Both are optional; you can use either, both, or neither.
class PrimaryTextField extends StatefulWidget {
  final IconData? prefixIcon;
  final Widget? suffixWidget;
  final String? hintText;
  final String? label;
  final TextStyle? labelStyle;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool? obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final List<String>? autofillHints;
  final bool hasFocusBorder;
  final String? errorText;
  final bool? enabled;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final int? minLines;
  final int? maxLines;
  final bool showCounter;

  const PrimaryTextField({
    required this.controller,
    super.key,
    this.hintText,
    this.label,
    this.prefixIcon,
    this.suffixWidget,
    this.labelStyle,
    this.validator,
    this.obscureText,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.autofillHints,
    this.hasFocusBorder = false,
    this.errorText,
    this.enabled,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.minLines,
    this.maxLines,
    this.showCounter = false,
  });

  @override
  State<PrimaryTextField> createState() => _PrimaryTextFieldState();
}

class _PrimaryTextFieldState extends State<PrimaryTextField> {
  String? _validatorError;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled ?? true;
    final shouldShowGreyStyle = !isEnabled;

    final displayError = widget.errorText ?? _validatorError;
    final hasError = displayError != null && displayError.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          style: TextStyle(
            color: shouldShowGreyStyle
                ? AppColors.textSecondary.withValues(alpha: 0.6)
                : AppColors.textPrimary,
            fontSize: 15.sp,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w400,
          ),
          obscureText: widget.obscureText ?? false,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          maxLength: widget.maxLength,
          autofillHints: widget.autofillHints,
          enabled: isEnabled,
          textInputAction: widget.textInputAction,
          minLines: widget.minLines,
          maxLines: (widget.obscureText ?? false) ? 1 : (widget.maxLines ?? 1),
          onFieldSubmitted: widget.onFieldSubmitted,
          onChanged: (value) {
            if (_validatorError != null) {
              setState(() {
                _validatorError = null;
              });
            }
            widget.onChanged?.call(value);
          },
          buildCounter: widget.showCounter
              ? null
              : (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) {
                  return const SizedBox.shrink();
                },

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
            labelStyle:
                widget.labelStyle ??
                TextStyle(
                  color: shouldShowGreyStyle
                      ? AppColors.textSecondary.withValues(alpha: 0.5)
                      : AppColors.textSecondary,
                  fontSize: 14.sp,
                  fontFamily: 'Poppins',
                ),
            floatingLabelStyle: TextStyle(
              color: hasError
                  ? AppColors.error
                  : (shouldShowGreyStyle
                        ? AppColors.textPrimary
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
            suffixIcon: widget.suffixWidget,
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
                color: hasError
                    ? AppColors.error
                    : (shouldShowGreyStyle
                          ? AppColors.border.withValues(alpha: 0.2)
                          : AppColors.border),
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

            // Hide default error text — we render a custom one below.
            errorStyle: const TextStyle(height: 0, fontSize: 0),
            errorMaxLines: 1,
          ),
          validator: (value) {
            if (widget.validator != null) {
              final error = widget.validator!(value);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _validatorError != error) {
                  setState(() {
                    _validatorError = error;
                  });
                }
              });
              return error;
            }
            return null;
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
