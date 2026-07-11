import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_drill_down_generator.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_item.dart';

void main() {
  group('TargetDrillDownGenerator dynamic subheader', () {
    test('returns Visit History for rules containing visit', () {
      expect(
        TargetDrillDownGenerator.getDynamicListHeader('No. of visits'),
        'Visit History',
      );
    });

    test('returns Order History for rules containing order', () {
      expect(
        TargetDrillDownGenerator.getDynamicListHeader('No. of Orders'),
        'Order History',
      );
      expect(
        TargetDrillDownGenerator.getDynamicListHeader('Value of Orders'),
        'Order History',
      );
    });

    test('returns Activity Log for rules containing party or new', () {
      expect(
        TargetDrillDownGenerator.getDynamicListHeader('New Party'),
        'Activity Log',
      );
      expect(
        TargetDrillDownGenerator.getDynamicListHeader('New Prospect'),
        'Activity Log',
      );
    });

    test('returns Transaction History for other rules', () {
      expect(
        TargetDrillDownGenerator.getDynamicListHeader('Value of collections'),
        'Transaction History',
      );
    });
  });

  group('TargetDrillDownGenerator record generation', () {
    test('generates count-based records summing exactly to actualValue', () {
      const target = TargetItem(
        id: 't1',
        rule: 'No. of Orders',
        interval: 'Daily',
        targetValue: 15,
        actualValue: 12,
        status: 'Active',
      );

      final records = TargetDrillDownGenerator.generateRecords(target);

      expect(records.length, 12);
      final totalContribution = records.fold<num>(
        0,
        (sum, item) => sum + item.contributionValue,
      );
      expect(totalContribution, 12);
      expect(records.first.primaryTitle, startsWith('Order #ORD-'));
      expect(records.first.formattedContribution, '+1');
    });

    test('generates currency records summing exactly to actualValue', () {
      const target = TargetItem(
        id: 't2',
        rule: 'Value of Orders',
        interval: 'Monthly',
        targetValue: 450000,
        actualValue: 480000,
        status: 'Completed',
      );

      final records = TargetDrillDownGenerator.generateRecords(target);

      expect(records, isNotEmpty);
      final totalContribution = records.fold<num>(
        0,
        (sum, item) => sum + item.contributionValue,
      );
      expect(totalContribution, 480000);
      expect(records.first.formattedContribution, contains('Rs'));
    });

    test('ensures all daily target records happen on the same day', () {
      const target = TargetItem(
        id: 'daily_t1',
        rule: 'No. of Orders',
        interval: 'Daily',
        targetValue: 15,
        actualValue: 12,
        status: 'Active',
      );

      final records = TargetDrillDownGenerator.generateRecords(
        target,
        referenceDate: DateTime(2026, 7, 11, 17, 30),
      );

      expect(records, isNotEmpty);
      for (final record in records) {
        expect(record.timestamp.year, 2026);
        expect(record.timestamp.month, 7);
        expect(record.timestamp.day, 11);
      }
    });
  });
}
