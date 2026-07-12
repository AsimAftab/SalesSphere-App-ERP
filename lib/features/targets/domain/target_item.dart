import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/features/targets/domain/target_enums.dart';

/// Domain model representing an assigned target with live progress for the
/// current employee. One row of `GET /targets/me`.
class TargetItem {
  const TargetItem({
    required this.id,
    required this.rule,
    required this.metric,
    required this.interval,
    required this.targetValue,
    required this.actualValue,
    required this.status,
    required this.isCurrency,
    required this.periodStart,
    required this.periodEnd,
    required this.periodLabel,
    required this.periodStatus,
  });

  /// Assignment id. The drill-down keys on [metric] + period, not on this.
  final String id;

  /// Server-rendered display label ("No. of Orders"). Render verbatim so the
  /// rep and their manager read the same words — never rebuild it locally.
  final String rule;

  final TargetMetric metric;
  final TargetInterval interval;
  final double targetValue;
  final double actualValue;

  /// Per-period achievement (COMPLETED once actual >= target), not the
  /// assignment's lifecycle.
  final TargetStatus status;

  /// Server-owned: whether the values are money. The server knows which
  /// column each metric reads, so the server decides.
  final bool isCurrency;

  /// Scored period, inclusive at both ends. Local-midnight calendar days.
  final DateTime periodStart;
  final DateTime periodEnd;

  /// Server-rendered period label ("Jul 12, 2026"). Replaces any local
  /// date formatting for the card.
  final String periodLabel;

  final TargetPeriodStatus periodStatus;

  /// Returns true if actual reaches target or the period is completed.
  bool get isCompleted =>
      actualValue >= targetValue || status == TargetStatus.completed;

  /// Returns progress percentage (capped at 100%).
  double get progressPercentage {
    if (targetValue <= 0) return 0;
    final ratio = (actualValue / targetValue) * 100;
    return ratio > 100 ? 100 : (ratio < 0 ? 0 : ratio);
  }

  /// Returns progress fraction between 0.0 and 1.0 (capped at 1.0).
  double get progressFraction {
    if (targetValue <= 0) return 0;
    final ratio = actualValue / targetValue;
    return ratio > 1 ? 1 : (ratio < 0 ? 0 : ratio);
  }

  /// Formats the actual value according to unit (currency or decimal).
  String get formattedActual => _formatNumber(actualValue);

  /// Formats the target value according to unit (currency or decimal).
  String get formattedTarget => _formatNumber(targetValue);

  String _formatNumber(num val) {
    if (isCurrency) {
      return NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0).format(val);
    }
    return NumberFormat.decimalPattern().format(val);
  }
}
