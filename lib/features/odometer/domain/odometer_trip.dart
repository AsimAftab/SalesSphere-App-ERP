

enum TripStatus { pending, active, completed }

enum DistanceUnit { km, miles }

extension DistanceUnitExtension on DistanceUnit {
  String get label {
    switch (this) {
      case DistanceUnit.km:
        return 'KM';
      case DistanceUnit.miles:
        return 'MILES';
    }
  }
}

class OdometerTrip {
  const OdometerTrip({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.startReading,
    required this.distanceUnit,
    this.startPhotoUrl,
    this.startDescription,
    this.stoppedAt,
    this.stopReading,
    this.stopPhotoUrl,
    this.stopDescription,
  });

  final String id;
  final TripStatus status;
  final DistanceUnit distanceUnit;

  final DateTime startedAt;
  final int startReading;
  final String? startPhotoUrl;
  final String? startDescription;

  final DateTime? stoppedAt;
  final int? stopReading;
  final String? stopPhotoUrl;
  final String? stopDescription;

  int? get distanceTravelled {
    if (stopReading == null) return null;
    return stopReading! - startReading;
  }

  OdometerTrip copyWith({
    String? id,
    TripStatus? status,
    DistanceUnit? distanceUnit,
    DateTime? startedAt,
    int? startReading,
    String? startPhotoUrl,
    String? startDescription,
    DateTime? stoppedAt,
    int? stopReading,
    String? stopPhotoUrl,
    String? stopDescription,
  }) {
    return OdometerTrip(
      id: id ?? this.id,
      status: status ?? this.status,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      startedAt: startedAt ?? this.startedAt,
      startReading: startReading ?? this.startReading,
      startPhotoUrl: startPhotoUrl ?? this.startPhotoUrl,
      startDescription: startDescription ?? this.startDescription,
      stoppedAt: stoppedAt ?? this.stoppedAt,
      stopReading: stopReading ?? this.stopReading,
      stopPhotoUrl: stopPhotoUrl ?? this.stopPhotoUrl,
      stopDescription: stopDescription ?? this.stopDescription,
    );
  }
}
