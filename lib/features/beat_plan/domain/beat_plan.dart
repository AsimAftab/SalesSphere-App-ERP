import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan_stop.dart';

/// UI-facing beat plan. Field names (`title`, `status`, `assignedDate`,
/// `startedDate`, `progress`, `total/visited/pending/skipped`) are kept stable
/// for the existing cards (`BeatPlanSummaryCard`, `RouteProgressCard`).
///
/// `status` is the title-cased label the badges render (`Active`); switch on
/// the `isActive`/`isPending`/`isCompleted` getters for logic. `stops` is
/// populated only for the detail view; the list carries an empty list and
/// reads the denormalised counters.
class BeatPlan {
  const BeatPlan({
    required this.id,
    required this.title,
    required this.status,
    required this.assignedDate,
    required this.startedDate,
    required this.progress, required this.total, required this.visited, required this.pending, required this.skipped, this.frequency = 'CUSTOM',
    this.completedAt,
    this.stops = const <BeatPlanStop>[],
    this.syncPending = false,
    this.syncError,
  });

  final String id;
  final String title;

  /// Title-cased: `Pending` | `Active` | `Completed`.
  final String status;
  final String frequency;
  final DateTime assignedDate;

  /// Non-null for card compatibility: falls back to [assignedDate] when the
  /// plan hasn't started yet (the card only renders it for non-pending plans).
  final DateTime startedDate;
  final DateTime? completedAt;

  /// 0.0–1.0.
  final double progress;
  final int total;
  final int visited;
  final int pending;
  final int skipped;

  final List<BeatPlanStop> stops;
  final bool syncPending;
  final String? syncError;

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isActive => status.toLowerCase() == 'active';
  bool get isCompleted => status.toLowerCase() == 'completed';

  BeatPlan copyWith({List<BeatPlanStop>? stops}) => BeatPlan(
        id: id,
        title: title,
        status: status,
        frequency: frequency,
        assignedDate: assignedDate,
        startedDate: startedDate,
        completedAt: completedAt,
        progress: progress,
        total: total,
        visited: visited,
        pending: pending,
        skipped: skipped,
        stops: stops ?? this.stops,
        syncPending: syncPending,
        syncError: syncError,
      );
}
