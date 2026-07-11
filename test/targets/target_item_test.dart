import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_item.dart';

void main() {
  group('TargetItem domain calculations and formatting', () {
    test('calculates percentage correctly and caps at 100%', () {
      const activeTarget = TargetItem(
        id: 't1',
        rule: 'No. of Orders',
        interval: 'Daily',
        targetValue: 15,
        actualValue: 12,
        status: 'Active',
      );

      expect(activeTarget.progressPercentage, closeTo(80.0, 0.01));
      expect(activeTarget.progressFraction, closeTo(0.8, 0.01));
      expect(activeTarget.isCompleted, isFalse);

      const overachievedTarget = TargetItem(
        id: 't2',
        rule: 'Value of collections',
        interval: 'Daily',
        targetValue: 50000,
        actualValue: 55000,
        status: 'Completed',
      );

      expect(overachievedTarget.progressPercentage, equals(100));
      expect(overachievedTarget.progressFraction, equals(1));
      expect(overachievedTarget.isCompleted, isTrue);
    });

    test('formats currency vs non-currency rules appropriately', () {
      const orderTarget = TargetItem(
        id: 't1',
        rule: 'No. of Orders',
        interval: 'Daily',
        targetValue: 15,
        actualValue: 12,
        status: 'Active',
      );

      expect(orderTarget.isCurrency, isFalse);
      expect(orderTarget.formattedActual, equals('12'));
      expect(orderTarget.formattedTarget, equals('15'));

      const collectionTarget = TargetItem(
        id: 't2',
        rule: 'Value of collections',
        interval: 'Daily',
        targetValue: 50000,
        actualValue: 55000,
        status: 'Completed',
      );

      expect(collectionTarget.isCurrency, isTrue);
      expect(collectionTarget.formattedActual, equals('Rs 55,000'));
      expect(collectionTarget.formattedTarget, equals('Rs 50,000'));

      const noOfCollectionsTarget = TargetItem(
        id: 't3',
        rule: 'No. of collections',
        interval: 'Daily',
        targetValue: 5,
        actualValue: 5,
        status: 'Completed',
      );

      expect(noOfCollectionsTarget.isCurrency, isFalse);
      expect(noOfCollectionsTarget.formattedActual, equals('5'));
      expect(noOfCollectionsTarget.formattedTarget, equals('5'));
    });
  });
}
