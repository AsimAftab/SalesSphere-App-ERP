import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// Hub screen surfaced from the bottom-nav "Customers" tab. Groups
/// Parties + Prospects + Sites under one entry so the user picks which
/// list to drill into. `context.push` (not `go`) keeps the navbar visible
/// and lets the destination's back arrow return here.
class CustomersHubPage extends StatelessWidget {
  const CustomersHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SvgPicture.asset(
                'assets/images/corner_bubble.svg',
                fit: BoxFit.cover,
                height: 180.h,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(height: 8.h),
                    Text(
                      'Customers',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Choose where to begin.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.sp,
                      ),
                    ),
                    SizedBox(height: 28.h),
                    _HubCard(
                      icon: Icons.business_outlined,
                      title: 'Parties',
                      subtitle: 'Active customers and accounts',
                      onTap: () => context.push(Routes.parties),
                    ),
                    SizedBox(height: 16.h),
                    _HubCard(
                      icon: Icons.person_search_outlined,
                      title: 'Prospects',
                      subtitle: 'Potential customers in your pipeline',
                      onTap: () => context.push(Routes.prospects),
                    ),
                    SizedBox(height: 16.h),
                    _HubCard(
                      icon: Icons.location_city_outlined,
                      title: 'Sites',
                      subtitle: 'Customer locations and branches',
                      onTap: () => context.push(Routes.sites),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(20.r),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 18.h,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 48.r,
                    height: 48.r,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      color: AppColors.secondary,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!disabled)
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                      size: 22.sp,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
