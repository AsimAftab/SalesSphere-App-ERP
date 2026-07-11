import 'package:sales_sphere_erp/features/targets/domain/target_drill_down_record.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_item.dart';

/// Helper class that generates deterministic mock drill-down records and
/// dynamic subheaders for any [TargetItem] until the backend drill-down API is ready.
class TargetDrillDownGenerator {
  TargetDrillDownGenerator._();

  static const List<String> _partyNames = <String>[
    'Global Tech Solutions',
    'Apex Enterprise Systems',
    'Zenith Logistics Ltd.',
    'Sunrise Retailers',
    'Paramount Traders',
    'Orion Healthcare Group',
    'Crest Industries',
    'Vanguard Commercial',
    'Pinnacle Supply Co.',
    'Evergreen Corp',
    'Horizon Marketing',
    'Sterling Exports',
    'Prime Ventures Ltd.',
    'Nexus Networks',
    'Optima Hardware',
  ];

  /// Returns dynamic list subheader based on rule name.
  static String getDynamicListHeader(String rule) {
    final lower = rule.toLowerCase();
    if (lower.contains('visit')) {
      return 'Visit History';
    }
    if (lower.contains('order')) {
      return 'Order History';
    }
    if (lower.contains('party') || lower.contains('new')) {
      return 'Activity Log';
    }
    return 'Transaction History';
  }

  /// Generates deterministic records that sum exactly to target.actualValue.
  static List<TargetDrillDownRecord> generateRecords(
    TargetItem target, {
    DateTime? referenceDate,
  }) {
    if (target.actualValue <= 0) {
      return const <TargetDrillDownRecord>[];
    }

    final lowerRule = target.rule.toLowerCase();
    final isOrderRule = lowerRule.contains('order');
    final isVisitRule = lowerRule.contains('visit');
    final isPartyOrNewRule =
        lowerRule.contains('party') || lowerRule.contains('new');

    final baseDate = referenceDate ?? DateTime(2026, 7, 11, 17, 30);
    final isDaily = target.interval.toLowerCase() == 'daily';

    if (target.isCurrency) {
      // Split total actual currency amount across deterministic transactions
      return _generateCurrencyRecords(
        totalValue: target.actualValue,
        baseDate: baseDate,
        isOrderRule: isOrderRule,
        isDaily: isDaily,
      );
    } else {
      // Generate individual items with contribution = 1 that sum to actualValue
      return _generateCountRecords(
        totalCount: target.actualValue.toInt(),
        baseDate: baseDate,
        isOrderRule: isOrderRule,
        isVisitRule: isVisitRule,
        isPartyOrNewRule: isPartyOrNewRule,
        isDaily: isDaily,
      );
    }
  }

  static List<TargetDrillDownRecord> _generateCurrencyRecords({
    required num totalValue,
    required DateTime baseDate,
    required bool isOrderRule,
    required bool isDaily,
  }) {
    if (totalValue <= 0) return const <TargetDrillDownRecord>[];

    // Split across up to 5 transactions for realism
    final count = totalValue > 50000 ? 5 : (totalValue > 10000 ? 3 : 1);
    final records = <TargetDrillDownRecord>[];
    var remaining = totalValue;

    final dayStart = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      9,
      15,
    );

    for (var i = 0; i < count; i++) {
      final isLast = i == count - 1;
      final amount = isLast
          ? remaining
          : ((remaining / (count - i)) / 1000).round() * 1000;
      if (!isLast) remaining -= amount;

      final partyName = _partyNames[i % _partyNames.length];
      final primaryTitle = isOrderRule
          ? 'Order #ORD-${10042 + i}'
          : 'Collection #PAY-${8821 + i}';
      final subtitle = partyName;

      final timestamp = isDaily
          ? dayStart.add(Duration(minutes: i * 45))
          : baseDate.subtract(Duration(days: i, hours: i * 2));

      records.add(
        TargetDrillDownRecord(
          id: 'curr_$i',
          primaryTitle: primaryTitle,
          subtitle: subtitle,
          contributionValue: amount,
          isCurrency: true,
          timestamp: timestamp,
        ),
      );
    }

    return records;
  }

  static List<TargetDrillDownRecord> _generateCountRecords({
    required int totalCount,
    required DateTime baseDate,
    required bool isOrderRule,
    required bool isVisitRule,
    required bool isPartyOrNewRule,
    required bool isDaily,
  }) {
    final records = <TargetDrillDownRecord>[];
    final dayStart = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      9,
    );

    for (var i = 0; i < totalCount; i++) {
      final partyName = _partyNames[i % _partyNames.length];
      final String primaryTitle;
      final String? subtitle;

      if (isOrderRule) {
        primaryTitle = 'Order #ORD-${10042 + i}';
        subtitle = partyName;
      } else if (isVisitRule) {
        primaryTitle = partyName;
        subtitle = 'Site Visit Verified';
      } else if (isPartyOrNewRule) {
        primaryTitle = partyName;
        subtitle = 'New Entity Registered';
      } else {
        primaryTitle = partyName;
        subtitle = 'Recorded Transaction';
      }

      final timestamp = isDaily
          ? dayStart.add(Duration(minutes: i * 35))
          : baseDate.subtract(Duration(days: i, hours: (i % 4) * 2));

      records.add(
        TargetDrillDownRecord(
          id: 'count_$i',
          primaryTitle: primaryTitle,
          subtitle: subtitle,
          contributionValue: 1,
          isCurrency: false,
          timestamp: timestamp,
        ),
      );
    }

    return records;
  }
}
