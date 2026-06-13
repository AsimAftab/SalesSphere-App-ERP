import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';

/// Manages the local state of odometer trips for this session.
/// Since there is no backend API yet, this holds the trips in memory.
class OdometerNotifier extends Notifier<List<OdometerTrip>> {
  @override
  List<OdometerTrip> build() {
    return []; // Start with no trips
  }

  Future<void> startTrip({
    required int startReading,
    required DistanceUnit unit,
    String? photoUrl,
    String? description,
  }) async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(seconds: 1));

    final newTrip = OdometerTrip(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      status: TripStatus.active,
      startedAt: DateTime.now(),
      startReading: startReading,
      distanceUnit: unit,
      startPhotoUrl: photoUrl,
      startDescription: description,
    );

    state = [...state, newTrip];
  }

  Future<void> stopTrip({
    required String tripId,
    required int stopReading,
    String? photoUrl,
    String? description,
  }) async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(seconds: 1));

    state = state.map((trip) {
      if (trip.id == tripId) {
        return trip.copyWith(
          status: TripStatus.completed,
          stoppedAt: DateTime.now(),
          stopReading: stopReading,
          stopPhotoUrl: photoUrl,
          stopDescription: description,
        );
      }
      return trip;
    }).toList();
  }
}

final odometerProvider = NotifierProvider<OdometerNotifier, List<OdometerTrip>>(() {
  return OdometerNotifier();
});

/// Exposes the currently active trip (if any).
final activeTripProvider = Provider<OdometerTrip?>((ref) {
  final trips = ref.watch(odometerProvider);
  return trips.where((t) => t.status == TripStatus.active).firstOrNull;
});

/// Exposes only the completed trips for today.
final completedTripsProvider = Provider<List<OdometerTrip>>((ref) {
  final trips = ref.watch(odometerProvider);
  final now = DateTime.now();
  return trips.where((t) => 
    t.status == TripStatus.completed &&
    t.startedAt.year == now.year &&
    t.startedAt.month == now.month &&
    t.startedAt.day == now.day
  ).toList();
});
