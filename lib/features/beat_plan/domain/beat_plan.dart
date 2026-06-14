class BeatPlan {
  final String id;
  final String title;
  final String status;
  final DateTime assignedDate;
  final DateTime startedDate;
  final double progress; // 0.0 to 1.0
  final int total;
  final int visited;
  final int pending;
  final int skipped;

  const BeatPlan({
    required this.id,
    required this.title,
    required this.status,
    required this.assignedDate,
    required this.startedDate,
    required this.progress,
    required this.total,
    required this.visited,
    required this.pending,
    required this.skipped,
  })  : assert(progress >= 0.0 && progress <= 1.0, 'Progress must be between 0.0 and 1.0'),
        assert(visited + pending + skipped == total, 'Stop counts must equal total');
}
