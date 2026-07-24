import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// Hub screen surfaced from the bottom-nav "Field Ops" tab. Groups the
/// field-operations modules — Parties, Prospects, Sites, Unplanned
/// Visits, Collection, Notes, Miscellaneous Work — under one entry so
/// the user picks which list to drill into. `context.push` (not `go`)
/// keeps the navbar visible and lets the destination's back arrow
/// return here.
///
/// Tiles share a flat white surface; identity comes from a per-module
/// icon colour (blue / orange / green / red) tinted into a soft
/// rounded icon block.
/// NOTE: tiles are ungated. Permission gating for every module is being done in
/// one pass across the whole app; the keys and the `hasAnyPermission` helper in
/// `core/auth/permissions.dart` are already in place for it.
///
/// For Collection, gate the tile on `collections:view` OR `:view-own` — a rep
/// holds the latter, so gating on `view` alone would hide the module from
/// everyone who can legitimately use it. The module itself ships on every plan,
/// so the tile is not plan-gated; it is only *posting* that is ledger-bound,
/// and the app doesn't expose posting at all (it's web-only). Gate any future
/// post/cancel affordance on `collections:post`, which a non-accounting tenant
/// never holds.
class FieldOpsPage extends StatelessWidget {
  const FieldOpsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                  'Field Ops',
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
                  'Your field operations, all in one place.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 28.h),
                _HubGrid(specs: _tileSpecs(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Built per-build so the closures can capture the current `context`
  /// for navigation + snackbar.
  List<_TileSpec> _tileSpecs(BuildContext context) => <_TileSpec>[
    _TileSpec(
      icon: Icons.storefront_outlined,
      title: 'Parties',
      subtitle: 'Manage business partners',
      iconColor: AppColors.blue500,
      onTap: () => context.push(Routes.parties),
    ),
    _TileSpec(
      icon: Icons.person_search_outlined,
      title: 'Prospects',
      subtitle: 'Manage potential customers',
      iconColor: AppColors.orange500,
      onTap: () => context.push(Routes.prospects),
    ),
    _TileSpec(
      icon: Icons.location_city_outlined,
      title: 'Sites',
      subtitle: 'Manage potential business locations',
      iconColor: AppColors.green500,
      onTap: () => context.push(Routes.sites),
    ),
    _TileSpec(
      icon: Icons.add_location_alt_outlined,
      title: 'Unplanned Visits',
      subtitle: 'Log ad-hoc visits',
      iconColor: AppColors.purple500,
      onTap: () => context.push(Routes.unplannedVisits),
    ),
    // The single Collection module now handles all payment types.
    _TileSpec(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Collection',
      subtitle: 'Record payments collected from parties',
      iconColor: AppColors.yellow500,
      onTap: () => context.push(Routes.collection),
    ),
    _TileSpec(
      icon: Icons.event_note_outlined,
      title: 'Notes',
      subtitle: 'Log discussions, feedback & issues',
      iconColor: AppColors.red500,
      onTap: () => context.push(Routes.notes),
    ),
    _TileSpec(
      icon: Icons.work_outline_rounded,
      title: 'Miscellaneous Work',
      subtitle: 'Log odd tasks',
      iconColor: AppColors.secondaryDark,
      onTap: () => context.push(Routes.miscellaneousWorks),
    ),
  ];
}

/// Static description of one hub tile. The page builds these per-frame
/// so the `onTap` closures can capture a live `BuildContext`.
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

class _HubGrid extends StatelessWidget {
  const _HubGrid({required this.specs});

  final List<_TileSpec> specs;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 14.w,
      mainAxisSpacing: 14.h,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[for (final spec in specs) _HubTile(spec: spec)],
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({required this.spec});

  final _TileSpec spec;

  @override
  Widget build(BuildContext context) {
    // Single decoration source: a `DecoratedBox` paints the white
    // surface, the per-module border, and the soft shadow. The
    // Material above is transparent so it doesn't paint a second
    // rectangle behind the rounded card — that double-painting is
    // what was leaking rectangular edges around the rounded shape.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: spec.iconColor.withValues(alpha: 0.25)),
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
                  child: Icon(spec.icon, color: spec.iconColor, size: 20.sp),
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
                // `Flexible` lets the subtitle clip to whatever vertical
                // room is left after the icon + title + gaps. Without it,
                // the Column tries to render two 12sp lines + 1.3 line
                // height, which on tighter screens crowds past the
                // parent's bounded height and trips a RenderFlex overflow.
                Flexible(
                  child: Text(
                    spec.subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
