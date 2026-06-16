import 'package:sales_sphere_erp/features/odometer/data/dto/odometer_record_dto.dart';

/// `data` of `GET /odometer/status/today`.
class OdometerTodayStatusDto {
  const OdometerTodayStatusDto({
    required this.trips,
    required this.hasActiveTrip,
    this.activeTripId,
  });

  factory OdometerTodayStatusDto.fromJson(Map<String, dynamic> json) {
    final raw = json['trips'];
    final trips = raw is List
        ? raw
            .map((e) => OdometerRecordDto.fromJson(e as Map<String, dynamic>))
            .toList(growable: false)
        : const <OdometerRecordDto>[];
    return OdometerTodayStatusDto(
      trips: trips,
      hasActiveTrip: (json['hasActiveTrip'] as bool?) ?? false,
      activeTripId: json['activeTripId'] as String?,
    );
  }

  final List<OdometerRecordDto> trips;
  final bool hasActiveTrip;
  final String? activeTripId;
}
