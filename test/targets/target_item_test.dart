import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_enums.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_item.dart';

TargetItem _item({
  double targetValue = 100,
  double actualValue = 0,
  TargetStatus status = TargetStatus.active,
  bool isCurrency = false,
  TargetPeriodStatus periodStatus = TargetPeriodStatus.inProgress,
}) {
  return TargetItem(
    id: 't1',
    rule: 'No. of Orders',
    metric: TargetMetric.orderCount,
    interval: TargetInterval.daily,
    targetValue: targetValue,
    actualValue: actualValue,
    status: status,
    isCurrency: isCurrency,
    periodStart: DateTime(2026, 7, 12),
    periodEnd: DateTime(2026, 7, 12),
    periodLabel: 'Jul 12, 2026',
    periodStatus: periodStatus,
  );
}

void main() {
  group('TargetItem domain calculations and formatting', () {
    test('80% active target reports partial progress and not completed', () {
      final target = _item(actualValue: 80);

      expect(target.progressPercentage, 80);
      expect(target.progressFraction, 0.8);
      expect(target.isCompleted, isFalse);
    });

    test('progress caps at 100% / 1.0 when actual exceeds target', () {
      final target =
          _item(actualValue: 110, status: TargetStatus.completed);

      expect(target.progressPercentage, 100);
      expect(target.progressFraction, 1.0);
      expect(target.isCompleted, isTrue);
    });

    test('COMPLETED status marks the target complete even below target', () {
      final target = _item(actualValue: 40, status: TargetStatus.completed);

      expect(target.isCompleted, isTrue);
    });

    test('zero target value yields zero progress, not a division error', () {
      final target = _item(targetValue: 0, actualValue: 5);

      expect(target.progressPercentage, 0);
      expect(target.progressFraction, 0);
    });

    test('non-currency values format as plain decimals', () {
      final target = _item(targetValue: 15, actualValue: 12);

      expect(target.formattedActual, '12');
      expect(target.formattedTarget, '15');
    });

    test('currency flag is server-owned and drives Rs formatting', () {
      final target = _item(
        targetValue: 450000,
        actualValue: 55000,
        isCurrency: true,
      );

      expect(target.formattedActual, 'Rs 55,000');
      expect(target.formattedTarget, 'Rs 450,000');
    });
  });
}
