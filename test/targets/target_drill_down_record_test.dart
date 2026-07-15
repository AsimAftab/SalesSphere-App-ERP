import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_drill_down_record.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_enums.dart';

void main() {
  group('TargetDrillDownRecord timestamp formatting', () {
    test('DAY precision prints the calendar day with no clock', () {
      // An order's day is parked at UTC midnight. Formatted device-local in
      // Kathmandu it would read "Jul 12, 2026 5:45 AM" — the 5:45 being the
      // timezone, not the moment of sale. And read device-local in a
      // negative-offset zone the day itself would slide back to Jul 11.
      final record = TargetDrillDownRecord(
        id: 'r1',
        primaryTitle: 'ORD-DEVORG-HO-82-0003',
        subtitle: 'Pokhara Traders',
        contributionValue: 1,
        isCurrency: false,
        timestamp: DateTime.parse('2026-07-12T00:00:00.000Z'),
        datePrecision: DatePrecision.day,
      );

      expect(record.formattedTimestamp, 'Jul 12, 2026');
    });

    test('INSTANT precision prints date and clock in local time', () {
      final record = TargetDrillDownRecord(
        id: 'r2',
        primaryTitle: 'Pokhara Traders',
        subtitle: 'Unplanned visit',
        contributionValue: 1,
        isCurrency: false,
        timestamp: DateTime(2026, 7, 12, 10, 15),
        datePrecision: DatePrecision.instant,
      );

      expect(record.formattedTimestamp, 'Jul 12, 2026 10:15 AM');

      final utcTime = DateTime.utc(2026, 7, 12, 10, 15);
      final recordUtc = TargetDrillDownRecord(
        id: 'r3',
        primaryTitle: 'Pokhara Traders',
        contributionValue: 1,
        isCurrency: false,
        timestamp: utcTime,
        datePrecision: DatePrecision.instant,
      );
      // Verify that calling formattedTimestamp converts to local time first
      expect(
        recordUtc.formattedTimestamp,
        TargetDrillDownRecord(
          id: 'r3',
          primaryTitle: 'Pokhara Traders',
          contributionValue: 1,
          isCurrency: false,
          timestamp: utcTime.toLocal(),
          datePrecision: DatePrecision.instant,
        ).formattedTimestamp,
      );
    });
  });

  group('TargetDrillDownRecord contribution formatting', () {
    test('count contribution "1.00" renders as +1', () {
      final record = TargetDrillDownRecord(
        id: 'r1',
        primaryTitle: 'ORD-0001',
        contributionValue: 1,
        isCurrency: false,
        timestamp: DateTime(2026, 7, 12),
        datePrecision: DatePrecision.day,
      );

      expect(record.formattedContribution, '+1');
    });

    test('currency contribution renders with Rs and separators', () {
      final record = TargetDrillDownRecord(
        id: 'r1',
        primaryTitle: 'RCPT-0001',
        contributionValue: 1500,
        isCurrency: true,
        timestamp: DateTime(2026, 7, 12),
        datePrecision: DatePrecision.day,
      );

      expect(record.formattedContribution, '+ Rs 1,500');
    });
  });
}
