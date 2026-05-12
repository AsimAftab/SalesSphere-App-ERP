import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/attendance/data/attendance_api.dart';
import 'package:sales_sphere_erp/features/attendance/data/dto/attendance_record_dto.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_status.dart';
import 'package:sales_sphere_erp/features/attendance/domain/repositories/attendance_repository.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the
/// app. All DTO ↔ domain mapping happens here. Drift persistence +
/// outbox enqueue will land alongside the real API.
class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl({required AttendanceApi api}) : _api = api;

  final AttendanceApi _api;

  @override
  Future<List<AttendanceRecord>> getMonth(int year, int month) async {
    final dtos = await _api.listForMonth(year, month);
    return dtos.map(_toDomain).toList(growable: false);
  }

  @override
  Future<AttendanceRecord> checkIn({
    required DateTime at,
    required String userId,
    required String userName,
    required String userRole,
    double? lat,
    double? lng,
    String? address,
  }) async {
    final dto = await _api.upsertCheckIn(
      at: at,
      userId: userId,
      userName: userName,
      userRole: userRole,
      lat: lat,
      lng: lng,
      address: address,
    );
    return _toDomain(dto);
  }

  @override
  Future<AttendanceRecord> checkOut({
    required DateTime at,
    double? lat,
    double? lng,
    String? address,
  }) async {
    final dto = await _api.upsertCheckOut(
      at: at,
      lat: lat,
      lng: lng,
      address: address,
    );
    return _toDomain(dto);
  }

  AttendanceRecord _toDomain(AttendanceRecordDto dto) => AttendanceRecord(
        id: dto.id,
        date: dto.date,
        status: _statusFromWire(dto.status),
        checkInAt: dto.checkInAt,
        checkOutAt: dto.checkOutAt,
        checkInLat: dto.checkInLat,
        checkInLng: dto.checkInLng,
        checkInAddress: dto.checkInAddress,
        checkOutLat: dto.checkOutLat,
        checkOutLng: dto.checkOutLng,
        checkOutAddress: dto.checkOutAddress,
        markedByUserId: dto.markedByUserId,
        markedByName: dto.markedByName,
        markedByRole: dto.markedByRole,
      );

  AttendanceStatus _statusFromWire(String wire) {
    switch (wire) {
      case 'present':
        return AttendanceStatus.present;
      case 'absent':
        return AttendanceStatus.absent;
      case 'leave':
        return AttendanceStatus.leave;
      case 'halfDay':
        return AttendanceStatus.halfDay;
      case 'weeklyOff':
        return AttendanceStatus.weeklyOff;
      default:
        // Surface unknown statuses loudly: silently coercing to
        // `present` would misclassify the row in the UI and — worse —
        // overwrite the backend with `'present'` on the next update.
        // If/when the backend grows a sixth status, this will crash
        // and force us to extend the enum + mapping rather than rotting
        // unnoticed.
        throw FormatException('Unsupported AttendanceStatus wire: $wire');
    }
  }
}

/// Exposes the abstract type so consumers depend on the contract,
/// not the impl class. Tests override this provider with a fake
/// `AttendanceRepository`.
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepositoryImpl(api: ref.watch(attendanceApiProvider));
});
