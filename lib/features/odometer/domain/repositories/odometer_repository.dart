import 'package:sales_sphere_erp/features/odometer/domain/odometer_monthly_report.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_today_status.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';

/// Contract for the odometer data source. The concrete impl
/// (`OdometerRepositoryImpl`) handles wire-DTO ↔ domain mapping and translates
/// the backend's structured `409` errors into typed conflict exceptions.
/// Tests substitute fakes via the Riverpod override.
abstract class OdometerRepository {
  /// `GET /odometer/status/today` — today's trips + active-trip flag.
  Future<OdometerTodayStatus> getTodayStatus();

  /// `GET /odometer/my-monthly-report?year=&month=` — the month's trips plus a
  /// server-computed summary.
  Future<OdometerMonthlyReport> getMonthlyReport(int year, int month);

  /// `GET /odometer/:id` — a single trip.
  Future<OdometerTrip> getTripById(String id);

  /// `POST /odometer/start` (multipart). Opens a new trip for today; the server
  /// rejects a second open trip with `ODOMETER_TRIP_IN_PROGRESS`. Coordinates,
  /// address, and the photo are optional. Returns the created trip.
  Future<OdometerTrip> startTrip({
    required double startReading,
    required DistanceUnit unit,
    String? description,
    double? latitude,
    double? longitude,
    String? address,
    String? imagePath,
  });

  /// `POST /odometer/stop` (multipart). Completes today's open trip; the server
  /// rejects with `ODOMETER_NO_ACTIVE_TRIP` when none is open. Returns the
  /// completed trip with the server-computed distance.
  Future<OdometerTrip> stopTrip({
    required double stopReading,
    required DistanceUnit unit,
    String? description,
    double? latitude,
    double? longitude,
    String? address,
    String? imagePath,
  });

  /// `DELETE /odometer/:id` — removes a trip (and its Cloudinary images).
  Future<void> deleteTrip(String id);
}
