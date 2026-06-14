import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/core/services/location_service.dart';
import 'package:sales_sphere_erp/core/utils/reverse_geocode.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
// Providers file re-exports `attendanceRepositoryProvider` so the
// controller stays out of `features/.../data/`.
import 'package:sales_sphere_erp/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:sales_sphere_erp/features/auth/presentation/controllers/auth_controller.dart';

part 'attendance_controller.g.dart';

/// Routes attendance write actions from the UI through the
/// repository. Reads stay on `attendanceMonthProvider`,
/// `attendanceByDateProvider`, and `todayAttendanceProvider`.
///
/// Each write method opens a `ref.keepAlive()` link for the duration
/// of its in-flight `await` and closes it in `finally`. That keeps
/// the notifier (and its `ref`) valid through the post-await
/// `ref.invalidate(...)` without permanently pinning a write-only
/// controller in memory.
@riverpod
class AttendanceController extends _$AttendanceController {
  @override
  void build() {}

  Future<AttendanceRecord> checkIn() async {
    final link = ref.keepAlive();
    try {
      final user = ref.read(authControllerProvider).value;
      if (user == null) {
        // Should never reach the UI: the router redirects unauth'd
        // users away from `/attendance`. Surface loudly if it does.
        throw StateError('Cannot check in without an authenticated user.');
      }
      // Best-effort GPS capture. Emulator / denied permission both
      // return null; the mock store keeps the row sans coordinates and
      // the UI falls back to a "Location unavailable" state.
      final position = await ref.read(locationServiceProvider).getCurrentLocation();
      final address = position == null
          ? null
          : await reverseGeocodeAddress(position.latitude, position.longitude);
      final now = DateTime.now();
      final created = await ref.read(attendanceRepositoryProvider).checkIn(
            at: now,
            userId: user.id,
            userName: user.fullName,
            userRole: user.systemRole ?? 'Member',
            lat: position?.latitude,
            lng: position?.longitude,
            address: address,
          );
      ref.invalidate(attendanceMonthlyReportProvider(now.year, now.month));
      return created;
    } finally {
      link.close();
    }
  }

  Future<AttendanceRecord> checkOut() async {
    final link = ref.keepAlive();
    try {
      final position = await ref.read(locationServiceProvider).getCurrentLocation();
      final address = position == null
          ? null
          : await reverseGeocodeAddress(position.latitude, position.longitude);
      final now = DateTime.now();
      final updated = await ref.read(attendanceRepositoryProvider).checkOut(
            at: now,
            lat: position?.latitude,
            lng: position?.longitude,
            address: address,
          );
      ref.invalidate(attendanceMonthlyReportProvider(now.year, now.month));
      return updated;
    } finally {
      link.close();
    }
  }
}
