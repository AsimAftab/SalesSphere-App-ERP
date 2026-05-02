import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Read-only display of a single coordinate (latitude or longitude) styled
/// to match the rest of the disabled form fields. The label always floats
/// above the value, and the value renders inside the outlined surface.
class CoordField extends StatelessWidget {
  const CoordField({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        prefixIcon: Icon(
          Icons.explore_outlined,
          color: AppColors.textSecondary,
          size: 20.sp,
        ),
        labelStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13.sp,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 15.sp,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
