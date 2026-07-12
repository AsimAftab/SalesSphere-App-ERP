import 'package:flutter/material.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_enums.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_item.dart';

/// Single source of the progress colour for the card and the drill-down page.
///
/// Zero progress is only a failure once the period has fully elapsed. A rep
/// holding a monthly target at 8am on the 1st has done nothing wrong — while
/// the server says `IN_PROGRESS`, zero renders neutral, not red. Web does the
/// same; diverging here would show amber on the phone and red on the
/// manager's screen for the same target.
Color targetProgressColor(TargetItem target) {
  if (target.progressPercentage >= 100) return AppColors.success;
  if (target.actualValue == 0) {
    return target.periodStatus == TargetPeriodStatus.inProgress
        ? AppColors.textSecondary // still time
        : AppColors.error; // the period closed on nothing
  }
  return AppColors.warning;
}

/// Drill-down list header, keyed off the metric enum — never the `rule`
/// label, which the platform may rename.
String drillDownHeaderFor(TargetMetric metric) => switch (metric) {
      TargetMetric.orderCount || TargetMetric.orderValue => 'Order History',
      TargetMetric.visitCount => 'Visit History',
      TargetMetric.newParty ||
      TargetMetric.newProspect ||
      TargetMetric.newSite =>
        'Activity Log',
      TargetMetric.collectionCount ||
      TargetMetric.collectionValue =>
        'Transaction History',
    };
