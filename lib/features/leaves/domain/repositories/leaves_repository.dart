import 'package:sales_sphere_erp/features/leaves/domain/leave.dart';

/// Domain-side contract for leaves data. The concrete implementation
/// (DTO mapping, drift persistence, outbox enqueue) lives in
/// `data/repositories/leaves_repository_impl.dart`.
abstract class LeavesRepository {
  Future<List<Leave>> getLeaves();

  Future<Leave> addLeave(Leave draft);

  Future<Leave> updateLeave(Leave leave);
}
