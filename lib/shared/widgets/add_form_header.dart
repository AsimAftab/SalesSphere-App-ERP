import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Large-title navy header for the create/"add" form pages: a back button on a
/// top row, then a prominent left-aligned title and a one-line description of
/// what the form is for.
///
/// Centralising it keeps every add screen identical (one title size, one
/// spacing) instead of each page hand-rolling its own `_Header`. The form
/// sheet below supplies its own rounded top corners, so this widget owns only
/// the coloured band.
class AddFormHeader extends StatelessWidget {
  const AddFormHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    super.key,
  });

  /// Page title — already states the action + subject, e.g. "Add New Party".
  final String title;

  /// One-line description of what the form is for, e.g. "Enter the new
  /// party's details". Genuine context, not marketing copy.
  final String subtitle;

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 0),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                  onPressed: onBack,
                  tooltip: 'Back',
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                    ),
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
