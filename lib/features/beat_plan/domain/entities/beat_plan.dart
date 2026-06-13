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
  });
}
