import 'package:intl/intl.dart';

/// Represents a single activity/transaction record contributing to an assigned
/// target's actual value.
class TargetDrillDownRecord {
  const TargetDrillDownRecord({
    required this.id,
    required this.primaryTitle,
    required this.contributionValue,
    required this.isCurrency,
    required this.timestamp,
    this.subtitle,
  });

  final String id;

  /// Primary display title (e.g., Party Name for visits/parties, or Order Number for orders).
  final String primaryTitle;

  /// Subtitle (e.g., Party Name for orders, or activity description).
  final String? subtitle;

  /// Amount or count contributed by this record.
  final num contributionValue;

  /// Whether [contributionValue] should be formatted as currency.
  final bool isCurrency;

  /// Exact date and time the activity occurred.
  final DateTime timestamp;

  /// Returns exact date and time string formatted as 'Jul 5, 2026 10:15 AM'.
  String get formattedTimestamp {
    return DateFormat('MMM d, yyyy h:mm a').format(timestamp);
  }

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
