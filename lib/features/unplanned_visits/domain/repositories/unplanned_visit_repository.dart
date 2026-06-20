import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit_exceptions.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visits_monthly_report.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visits_today.dart';

/// Contract for unplanned-visit reads + writes. The concrete
/// `UnplannedVisitRepositoryImpl` is the DTO ↔ domain translation boundary;
/// the Riverpod provider exposes this abstract type so consumers depend on the
/// contract (and tests can swap a fake).
abstract class UnplannedVisitRepository {
  /// `GET /unplanned-visits/status/today`.
  Future<UnplannedVisitsToday> getTodayStatus();

  /// `GET /unplanned-visits/:id`.
  Future<UnplannedVisit> getById(String id);

  /// The month's visits + summary, powering the home summary card and the
  /// history page.
  ///
  /// The backend endpoint (`GET /unplanned-visits/my-monthly-report`) is not
  /// live yet; the impl assembles this from `status/today` for the current
  /// month and returns an empty report for other months. Swap to the real
  /// endpoint here once it ships.
  Future<UnplannedVisitsMonthlyReport> getMonthlyReport(int year, int month);

  /// `POST /unplanned-visits/start`. Creates a visit (`in_progress`) to the
  /// given target. Coordinates are optional (a missing fix sends nulls); the
  /// caller is responsible for the geofence gate before invoking this.
  ///
  /// Throws [UnplannedVisitConflictException] with code
  /// `UNPLANNED_VISIT_IN_PROGRESS` if a visit is already open.
  Future<UnplannedVisit> startVisit({
    required VisitTargetType targetType,
    required String targetId,
    double? latitude,
    double? longitude,
    String? address,
  });

  /// `POST /unplanned-visits/stop`. Completes the rep's open visit, attaching
  /// the proof photo, optional description and follow-up date.
  ///
  /// Throws [UnplannedVisitConflictException] with code
  /// `UNPLANNED_VISIT_NO_ACTIVE` if there's nothing to stop.
  Future<UnplannedVisit> stopVisit({
    required String imagePath,
    String? description,
    DateTime? followUpDate,
    double? latitude,
    double? longitude,
    String? address,
  });

  /// `DELETE /unplanned-visits/:id`.
  Future<void> deleteVisit(String id);
}
