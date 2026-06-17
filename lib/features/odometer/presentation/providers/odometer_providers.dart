import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/odometer/data/repositories/odometer_repository_impl.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_monthly_report.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_today_status.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';

// Re-export the repository provider so consumers (controller, tests) depend on
// the contract surface without importing from `data/`.
export 'package:sales_sphere_erp/features/odometer/data/repositories/odometer_repository_impl.dart'
    show odometerRepositoryProvider;

part 'odometer_providers.g.dart';

/// Today's trips + active-trip flag from `GET /odometer/status/today`. Single
/// source of truth for the home page's status, active-trip card, and carousel.
@riverpod
Future<OdometerTodayStatus> odometerTodayStatus(Ref ref) async {
  return ref.watch(odometerRepositoryProvider).getTodayStatus();
}

/// The month's trips + server-computed summary from
/// `GET /odometer/my-monthly-report`. Powers the home summary card and the
/// history page.
@riverpod
Future<OdometerMonthlyReport> odometerMonthlyReport(
  Ref ref,
  int year,
  int month,
) async {
  return ref.watch(odometerRepositoryProvider).getMonthlyReport(year, month);
}

/// A single trip for the detail page. Prefers a cached copy from today's status
/// or the current month's report (so navigating from a list doesn't refetch),
/// falling back to `GET /odometer/:id`.
@riverpod
Future<OdometerTrip> odometerTripById(Ref ref, String id) async {
  final today = ref.read(odometerTodayStatusProvider).value;
  if (today != null) {
    for (final t in today.trips) {
      if (t.id == id) return t;
    }
  }
  final now = DateTime.now();
  final month =
      ref.read(odometerMonthlyReportProvider(now.year, now.month)).value;
  if (month != null) {
    for (final t in month.records) {
      if (t.id == id) return t;
    }
  }
  return ref.watch(odometerRepositoryProvider).getTripById(id);
}
