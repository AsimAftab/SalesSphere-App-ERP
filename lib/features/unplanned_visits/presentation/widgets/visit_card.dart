import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/visit_formatting.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';

/// Compact card for one visit in the home page's "Today's visits" list.
class VisitCard extends StatelessWidget {
  const VisitCard({required this.visit, required this.onTap, super.key});

  final UnplannedVisit visit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = visit.isInProgress;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: SizedBox(
                  width: 52.r,
                  height: 52.r,
                  child: visit.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: visit.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.background,
                          ),
                          errorWidget: (_, __, ___) => _IconFallback(active: active),
                        )
                      : _IconFallback(active: active),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      visit.target.displayName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${visit.target.type.label} · ${formatVisitTime(visit.startedAt)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              StatusBadge(
                label: active ? 'On Visit' : 'Done',
                color: active ? AppColors.blue500 : AppColors.green500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconFallback extends StatelessWidget {
  const _IconFallback({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.blue500 : AppColors.green500;
    return Container(
      color: color.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Icon(Icons.pin_drop_rounded, color: color, size: 22.sp),
    );
  }
}
