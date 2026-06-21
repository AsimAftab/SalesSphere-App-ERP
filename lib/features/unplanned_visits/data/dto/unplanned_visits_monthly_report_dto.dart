import 'package:sales_sphere_erp/features/unplanned_visits/data/dto/unplanned_visit_dto.dart';

/// `data` of `GET /unplanned-visits/my-monthly-report?year=&month=`. Mirrors
/// `OdometerMonthlyReportDto` so the two field-ops features parse the same
/// shape. `records` reuse the shared [UnplannedVisitDto] verbatim — the rows
/// are byte-identical to `/:id`, `status/today`, `start` and `stop`.
class UnplannedVisitsMonthlyReportDto {
  const UnplannedVisitsMonthlyReportDto({
    required this.month,
    required this.year,
    required this.records,
    required this.summary,
  });

  factory UnplannedVisitsMonthlyReportDto.fromJson(Map<String, dynamic> json) {
    final raw = json['records'];
    final records = raw is List
        ? raw
              .map((e) => UnplannedVisitDto.fromJson(e as Map<String, dynamic>))
              .toList(growable: false)
        : const <UnplannedVisitDto>[];
    final rawSummary = json['summary'];
    final summary = rawSummary is Map<String, dynamic>
        ? UnplannedVisitsMonthlySummaryDto.fromJson(rawSummary)
        : UnplannedVisitsMonthlySummaryDto.empty;
    return UnplannedVisitsMonthlyReportDto(
      month: (json['month'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      records: records,
      summary: summary,
    );
  }

  final int month;
  final int year;
  final List<UnplannedVisitDto> records;
  final UnplannedVisitsMonthlySummaryDto summary;
}

/// Headline counts for the month — powers the home summary card's stat tiles.
class UnplannedVisitsMonthlySummaryDto {
  const UnplannedVisitsMonthlySummaryDto({
    required this.totalVisits,
    required this.visitsCompleted,
    required this.visitsInProgress,
    required this.followUps,
  });

  factory UnplannedVisitsMonthlySummaryDto.fromJson(Map<String, dynamic> json) {
    return UnplannedVisitsMonthlySummaryDto(
      totalVisits: (json['totalVisits'] as num?)?.toInt() ?? 0,
      visitsCompleted: (json['visitsCompleted'] as num?)?.toInt() ?? 0,
      visitsInProgress: (json['visitsInProgress'] as num?)?.toInt() ?? 0,
      followUps: (json['followUps'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = UnplannedVisitsMonthlySummaryDto(
    totalVisits: 0,
    visitsCompleted: 0,
    visitsInProgress: 0,
    followUps: 0,
  );

  final int totalVisits;
  final int visitsCompleted;
  final int visitsInProgress;
  final int followUps;
}
