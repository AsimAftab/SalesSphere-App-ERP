import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/widgets/visit_times_strip.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';

/// Rich card summarising one visit: a "Visit N" tag + target + status over a
/// Started / Ended / Duration strip (the beat-plan stop card's time summary).
/// Used on the home carousel — [number] is the visit's 1-based position in the
/// day so the rep can tell the cards apart.
class VisitSummaryCard extends StatelessWidget {
  const VisitSummaryCard({
    required this.visit,
    required this.number,
    this.onTap,
    super.key,
  });

  final UnplannedVisit visit;
  final int number;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = visit.isInProgress;

    final card = Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ── "Visit N (Type)" title + status ──────────────────────────
          Row(
            children: <Widget>[
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: 'Visit $number',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      TextSpan(
                        text: '  (${visit.target.type.label})',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              StatusBadge(
                label: active ? 'On Visit' : 'Completed',
                color: active ? AppColors.blue500 : AppColors.green500,
              ),
            ],
          ),
          SizedBox(height: 6.h),
          // ── Entity name (second line, may wrap to 2 lines) ───────────
          Text(
            visit.target.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          SizedBox(height: 16.h),
          // ── Started / Ended / Duration ───────────────────────────────
          VisitTimesStrip(visit: visit),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: card,
    );
  }
}
