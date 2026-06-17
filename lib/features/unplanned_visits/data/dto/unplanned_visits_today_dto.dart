import 'package:sales_sphere_erp/features/unplanned_visits/data/dto/unplanned_visit_dto.dart';

/// `data` of `GET /unplanned-visits/status/today`.
class UnplannedVisitsTodayDto {
  const UnplannedVisitsTodayDto({
    required this.visits,
    required this.hasActiveVisit,
    this.activeVisitId,
  });

  factory UnplannedVisitsTodayDto.fromJson(Map<String, dynamic> json) {
    final raw = json['visits'];
    final visits = raw is List
        ? raw
              .map(
                (e) => UnplannedVisitDto.fromJson(e as Map<String, dynamic>),
              )
              .toList(growable: false)
        : const <UnplannedVisitDto>[];
    return UnplannedVisitsTodayDto(
      visits: visits,
      hasActiveVisit: (json['hasActiveVisit'] as bool?) ?? false,
      activeVisitId: json['activeVisitId'] as String?,
    );
  }

  final List<UnplannedVisitDto> visits;
  final bool hasActiveVisit;
  final String? activeVisitId;
}
