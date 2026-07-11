import 'package:intl/intl.dart';

/// Domain model representing an assigned target with actual progress
/// for an employee (Daily or Monthly interval).
class TargetItem {
  const TargetItem({
    required this.id,
    required this.rule,
    required this.interval,
    required this.targetValue,
    required this.actualValue,
    required this.status,
  });

  factory TargetItem.fromJson(Map<String, dynamic> json) {
    return TargetItem(
      id: json['id'] as String? ?? '',
      rule: json['rule'] as String? ?? '',
      interval: json['interval'] as String? ?? 'Daily',
      targetValue: (json['targetValue'] as num?) ?? 0,
      actualValue: (json['actualValue'] as num?) ?? 0,
      status: json['status'] as String? ?? 'Active',
    );
  }

  final String id;
  final String rule;
  final String interval;
  final num targetValue;
  final num actualValue;
  final String status;

  /// Returns true if actual reaches target or status is Completed.
  bool get isCompleted =>
      actualValue >= targetValue || status.toLowerCase() == 'completed';

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

  /// Checks if the rule represents a monetary/currency value.
  bool get isCurrency {
    final lower = rule.toLowerCase();
    if (lower.contains('no.') || lower.contains('count')) {
      return false;
    }
    return lower.contains('value') ||
        lower.contains('amount') ||
        lower.contains('revenue') ||
        lower.contains('sales');
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
