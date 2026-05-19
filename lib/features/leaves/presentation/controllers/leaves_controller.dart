import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/leaves/domain/leave.dart';
// `leaves_providers.dart` re-exports `leavesRepositoryProvider`
// so the controller stays out of `features/.../data/`.
import 'package:sales_sphere_erp/features/leaves/presentation/providers/leaves_providers.dart';

part 'leaves_controller.g.dart';

/// Routes leave write actions from the UI through the repository.
/// Reads stay on `leavesListProvider` and `leaveByIdProvider`.
///
/// Each write method opens a `ref.keepAlive()` link for the duration
/// of its in-flight `await` and closes it in `finally`. That keeps the
/// notifier (and its `ref`) valid through the post-await
/// `ref.invalidate(...)` without permanently pinning a write-only
/// controller in memory.
@riverpod
class LeavesController extends _$LeavesController {
  @override
  void build() {}

  Future<Leave> addLeave(Leave draft) async {
    final link = ref.keepAlive();
    try {
      final created = await ref.read(leavesRepositoryProvider).addLeave(draft);
      ref.invalidate(leavesListProvider);
      return created;
    } finally {
      link.close();
    }
  }

  Future<Leave> updateLeave(Leave leave) async {
    final link = ref.keepAlive();
    try {
      final updated = await ref
          .read(leavesRepositoryProvider)
          .updateLeave(leave);
      ref.invalidate(leavesListProvider);
      return updated;
    } finally {
      link.close();
    }
  }
}
