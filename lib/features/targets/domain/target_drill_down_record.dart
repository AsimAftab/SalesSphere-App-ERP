import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/features/targets/domain/target_enums.dart';

/// Represents a single activity/transaction record contributing to an assigned
/// target's actual value. One row of `GET /targets/drill-down`.
class TargetDrillDownRecord {
  const TargetDrillDownRecord({
    required this.id,
    required this.primaryTitle,
    required this.contributionValue,
    required this.isCurrency,
    required this.timestamp,
    required this.datePrecision,
    this.subtitle,
  });

  final String id;

  /// Primary display title (e.g., Party Name for visits/parties, or Order Number for orders).
  final String primaryTitle;

  /// Subtitle (e.g., Party Name for orders, or activity description).
  final String? subtitle;

  /// Amount or count contributed by this record.
  final double contributionValue;

  /// Whether [contributionValue] should be formatted as currency.
  final bool isCurrency;

  /// When the activity occurred — but read [datePrecision] before formatting.
  final DateTime timestamp;

  /// [DatePrecision.day] rows park a calendar day at UTC midnight; a clock
  /// printed off one would just be the org's UTC offset.
  final DatePrecision datePrecision;

  /// Formatted timestamp: date + clock for real instants; date only for
  /// calendar-day rows. The DAY branch reads in UTC — the day was stored at
  /// UTC midnight, so device-local time in a negative-offset zone would slide
  /// it back a day.
  String get formattedTimestamp => switch (datePrecision) {
        DatePrecision.instant =>
          DateFormat('MMM d, yyyy h:mm a').format(timestamp),
        DatePrecision.day =>
          DateFormat('MMM d, yyyy').format(timestamp.toUtc()),
      };

  /// Returns formatted contribution string (e.g., '+ Rs 1,500' or '+1').
  String get formattedContribution {
    if (isCurrency) {
      final formatted =
          NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0).format(
        contributionValue,
      );
      return '+ $formatted';
    }
    return '+${contributionValue.toInt()}';
  }
}
