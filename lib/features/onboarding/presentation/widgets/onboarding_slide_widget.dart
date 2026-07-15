import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/onboarding/domain/onboarding_slide.dart';

class OnboardingSlideWidget extends StatelessWidget {
  const OnboardingSlideWidget({
    required this.slide,
    required this.pageIndex,
    super.key,
  });

  final OnboardingSlide slide;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Column(
        children: <Widget>[
          SizedBox(height: 16.h),
          Expanded(
            flex: 3,
            child: Center(
              child: SvgPicture.asset(
                slide.imagePath,
                width: 300.w,
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22.sp,
              color: AppColors.textPrimary,
              fontFamily: 'Poppins',
              height: 1.2,
            ),
          ),
          SizedBox(height: 14.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Text(
              slide.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
                height: 1.5,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
              ),
              maxLines: 4,
            ),
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }
}
