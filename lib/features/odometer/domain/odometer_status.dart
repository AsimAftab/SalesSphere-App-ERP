/// Lifecycle of an odometer trip. Wire values are lowercase
/// (`not_started` | `in_progress` | `completed`); the repository maps them to
/// this enum and throws on anything unknown. `notStarted` exists in the
/// backend schema but isn't produced by the start/stop flow today.
enum OdometerStatus { notStarted, inProgress, completed }

extension OdometerStatusX on OdometerStatus {
  bool get isInProgress => this == OdometerStatus.inProgress;
  bool get isCompleted => this == OdometerStatus.completed;
}

/// Reading unit. `name` (`km` / `miles`) is the exact lowercase wire value, so
/// requests send `unit.name` directly. `label` is the uppercase UI form.
enum DistanceUnit { km, miles }

extension DistanceUnitX on DistanceUnit {
  String get label {
    switch (this) {
      case DistanceUnit.km:
        return 'KM';
      case DistanceUnit.miles:
        return 'MILES';
    }
  }
}
