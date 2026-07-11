import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// "More" tab landing screen — surfaces account-adjacent destinations.
/// Mirrors `FieldOpsPage`'s chrome (large header, 2-col tile grid,
/// soft-shadow flat surface, per-module accent colour) so both
/// bottom-nav landing surfaces read as the same family.
///
/// Two tiles are wired (Settings and Attendance); the second column waits for
/// future tiles (notifications, help & support, about, language…).
/// Profile and Sign out both live one level deeper, inside Settings.
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    const subtitle = 'Manage features and settings';

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: 8.h),
                Text(
                  'More',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 28.h),
                _MoreGrid(specs: _tileSpecs(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Built per-build so the closures can capture the current `context`
  /// for navigation. Append to this list as future tiles land — the
  /// 2-col grid auto-flows.
  List<_TileSpec> _tileSpecs(BuildContext context) => <_TileSpec>[
        _TileSpec(
          icon: Icons.calendar_today_outlined,
          title: 'Attendance',
          subtitle: 'Mark and track daily attendance',
          iconColor: AppColors.indigo500,
          onTap: () => context.push(Routes.attendance),
        ),
        _TileSpec(
          icon: Icons.event_busy_outlined,
          title: 'Leave Request',
          subtitle: 'Apply for leave and track approval',
          iconColor: AppColors.cyan500,
          onTap: () => context.push(Routes.leaves),
        ),
        _TileSpec(
          icon: Icons.speed_outlined,
          title: 'Odometer',
          subtitle: 'Track distance during field visits',
          iconColor: AppColors.warning,
          onTap: () => context.push(Routes.odometer),
        ),
        _TileSpec(
          icon: Icons.currency_rupee,
          title: 'Expense Claims',
          subtitle: 'Submit and manage expenses',
          iconColor: AppColors.fuchsia600,
          onTap: () => context.push(Routes.expenseClaims),
        ),
        _TileSpec(
          icon: Icons.navigation_outlined,
          title: 'Tour Plan',
          subtitle: 'Plan and manage daily field visits',
          iconColor: AppColors.rose600,
          onTap: () => context.push(Routes.tourPlans),
        ),
        _TileSpec(
          icon: Icons.track_changes_outlined,
          title: 'Targets',
          subtitle: 'Track daily and monthly goals',
          iconColor: AppColors.targetAccent,
          onTap: () => context.push(Routes.targets),
        ),
        _TileSpec(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'App preferences and account',
          // Settings is account chrome rather than a domain module, so
          // it picks up a neutral grey accent instead of one of the
          // hub palette colours.
          iconColor: AppColors.textSecondary,
          onTap: () => context.push(Routes.settings),
        ),
      ];
}

/// Static description of one tile. The page builds these per-frame
/// so `onTap` closures can capture a live `BuildContext`.
@immutable
class _TileSpec {
  const _TileSpec({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;
}

class _MoreGrid extends StatelessWidget {
  const _MoreGrid({required this.specs});

  final List<_TileSpec> specs;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 14.w,
      mainAxisSpacing: 14.h,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        for (final spec in specs) _MoreTile(spec: spec),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.spec});

  final _TileSpec spec;

  @override
  Widget build(BuildContext context) {
    // Single decoration source: a `DecoratedBox` paints the white
    // surface, the per-module border, and the soft shadow. The
    // Material above is transparent so it doesn't paint a second
    // rectangle behind the rounded card.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: spec.iconColor.withValues(alpha: 0.25),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20.r),
        child: InkWell(
          onTap: spec.onTap,
          borderRadius: BorderRadius.circular(20.r),
          child: Padding(
            padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 18.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 42.r,
                  height: 42.r,
                  decoration: BoxDecoration(
                    color: spec.iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    spec.icon,
                    color: spec.iconColor,
                    size: 20.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  spec.title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  spec.subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
