/// Lifecycle of an unplanned visit. Mirrors the backend's lowercase wire
/// values (`in_progress` | `completed`); a visit is created `in_progress` by
/// `POST /unplanned-visits/start` and moves to `completed` on stop.
enum VisitStatus { inProgress, completed }

extension VisitStatusX on VisitStatus {
  bool get isInProgress => this == VisitStatus.inProgress;
  bool get isCompleted => this == VisitStatus.completed;

  String get label => switch (this) {
    VisitStatus.inProgress => 'In Progress',
    VisitStatus.completed => 'Completed',
  };
}
