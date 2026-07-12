import 'package:sales_sphere_erp/features/collection/data/dto/wire_codecs.dart';

/// Wire DTO for one drill-down record (`TargetTransaction` in the OpenAPI
/// spec): the order / receipt / visit / directory entry behind an achieved
/// number.
class TargetTransactionDto {
  const TargetTransactionDto({
    required this.id,
    required this.title,
    required this.value,
    required this.isCurrency,
    required this.date,
    required this.datePrecision,
    this.subtitle,
  });

  factory TargetTransactionDto.fromJson(Map<String, dynamic> json) {
    return TargetTransactionDto(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      value: parseMoney(json['value']),
      isCurrency: json['isCurrency'] as bool,
      // Full ISO instant. For DAY-precision rows this is the calendar day
      // parked at UTC midnight — formatting handles that, not parsing.
      date: DateTime.parse(json['date'] as String),
      datePrecision: json['datePrecision'] as String,
    );
  }

  final String id;

  /// Doc number or entity name (`ORD-…`, `RCPT-…`, or the party's name).
  final String title;

  /// Counterparty, or e.g. "Unplanned visit". Nullable on the wire.
  final String? subtitle;

  /// Row contribution: the amount for a VALUE metric, `"1.00"` for a COUNT.
  final double value;

  final bool isCurrency;
  final DateTime date;

  /// Raw wire enum: `DAY` | `INSTANT`.
  final String datePrecision;
}
