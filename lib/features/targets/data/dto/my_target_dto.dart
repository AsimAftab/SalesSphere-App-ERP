import 'package:sales_sphere_erp/features/collection/data/dto/wire_codecs.dart';

/// Wire DTO for one row of `GET /targets/me` (`MyTarget` in the OpenAPI spec).
///
/// `targetValue` / `actualValue` arrive as **2dp decimal strings** ("99.00")
/// even for counts — the house rule for every magnitude on this platform, so
/// neither client branches on `metric` to parse a number. Enums stay raw wire
/// strings here (SCREAMING_SNAKE); the repository maps them to domain enums.
class MyTargetDto {
  const MyTargetDto({
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

  /// Hard casts on required fields are deliberate: a missing field is a
  /// malformed row and must throw loudly, not default silently.
  factory MyTargetDto.fromJson(Map<String, dynamic> json) {
    return MyTargetDto(
      id: json['id'] as String,
      rule: json['rule'] as String,
      metric: json['metric'] as String,
      interval: json['interval'] as String,
      targetValue: parseMoney(json['targetValue']),
      actualValue: parseMoney(json['actualValue']),
      status: json['status'] as String,
      isCurrency: json['isCurrency'] as bool,
      periodStart: parseWireDate(json['periodStart'] as String),
      periodEnd: parseWireDate(json['periodEnd'] as String),
      periodLabel: json['periodLabel'] as String,
      periodStatus: json['periodStatus'] as String,
    );
  }

  final String id;
  final String rule;

  /// Raw wire enum, e.g. `ORDER_COUNT`.
  final String metric;

  /// Raw wire enum: `DAILY` | `MONTHLY`.
  final String interval;

  final double targetValue;
  final double actualValue;

  /// Raw wire enum: `ACTIVE` | `COMPLETED` (per period).
  final String status;

  final bool isCurrency;

  /// Inclusive calendar days, local-midnight after [parseWireDate].
  final DateTime periodStart;
  final DateTime periodEnd;

  final String periodLabel;

  /// Raw wire enum: `IN_PROGRESS` | `CLOSED`.
  final String periodStatus;
}
