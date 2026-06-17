import 'package:sales_sphere_erp/features/odometer/data/dto/odometer_record_dto.dart';

/// `data` of `GET /odometer/my-monthly-report`.
class OdometerMonthlyReportDto {
  const OdometerMonthlyReportDto({
    required this.month,
    required this.year,
    required this.records,
    required this.summary,
  });

  factory OdometerMonthlyReportDto.fromJson(Map<String, dynamic> json) {
    final raw = json['records'];
    final records = raw is List
        ? raw
            .map((e) => OdometerRecordDto.fromJson(e as Map<String, dynamic>))
            .toList(growable: false)
        : const <OdometerRecordDto>[];
    final rawSummary = json['summary'];
    final summary = rawSummary is Map<String, dynamic>
        ? OdometerMonthlySummaryDto.fromJson(rawSummary)
        : OdometerMonthlySummaryDto.empty;
    return OdometerMonthlyReportDto(
      month: (json['month'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      records: records,
      summary: summary,
    );
  }

  final int month;
  final int year;
  final List<OdometerRecordDto> records;
  final OdometerMonthlySummaryDto summary;
}

class OdometerMonthlySummaryDto {
  const OdometerMonthlySummaryDto({
    required this.totalDistance,
    required this.distanceUnit,
    required this.totalTrips,
    required this.tripsCompleted,
    required this.tripsInProgress,
    required this.avgDistancePerTrip,
  });

  factory OdometerMonthlySummaryDto.fromJson(Map<String, dynamic> json) {
    return OdometerMonthlySummaryDto(
      totalDistance: (json['totalDistance'] as num?)?.toDouble() ?? 0,
      distanceUnit: (json['distanceUnit'] as String?) ?? 'km',
      totalTrips: (json['totalTrips'] as num?)?.toInt() ?? 0,
      tripsCompleted: (json['tripsCompleted'] as num?)?.toInt() ?? 0,
      tripsInProgress: (json['tripsInProgress'] as num?)?.toInt() ?? 0,
      avgDistancePerTrip: (json['avgDistancePerTrip'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = OdometerMonthlySummaryDto(
    totalDistance: 0,
    distanceUnit: 'km',
    totalTrips: 0,
    tripsCompleted: 0,
    tripsInProgress: 0,
    avgDistancePerTrip: 0,
  );

  final double totalDistance;
  final String distanceUnit;
  final int totalTrips;
  final int tripsCompleted;
  final int tripsInProgress;
  final int avgDistancePerTrip;
}
