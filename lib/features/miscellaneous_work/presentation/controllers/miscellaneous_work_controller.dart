import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/miscellaneous_work/domain/miscellaneous_work.dart';
// Providers file re-exports `miscellaneousWorkRepositoryProvider` so
// the controller stays out of `features/.../data/`.
import 'package:sales_sphere_erp/features/miscellaneous_work/presentation/providers/miscellaneous_work_providers.dart';

part 'miscellaneous_work_controller.g.dart';

/// Routes miscellaneous-work write actions from the UI through the
/// repository. Reads stay on `miscellaneousWorkListProvider` and
/// `miscellaneousWorkByIdProvider`.
///
/// On success the controller patches the paginated list notifier
/// directly (`prependLocal` / `replaceLocal`) instead of invalidating
/// it. Invalidation would refetch every page from scratch and lose
/// the user's scroll position; an in-place patch keeps the new row
/// at the top while leaving the rest of the list untouched.
///
/// Each write method opens a `ref.keepAlive()` link for the duration
/// of its in-flight `await` and closes it in `finally`. That keeps
/// the notifier (and its `ref`) valid through the post-await state
/// patch without permanently pinning a write-only controller in
/// memory.
@riverpod
class MiscellaneousWorkController extends _$MiscellaneousWorkController {
  @override
  void build() {}

  Future<MiscellaneousWork> addWork(MiscellaneousWork draft) async {
    final link = ref.keepAlive();
    try {
      final created =
          await ref.read(miscellaneousWorkRepositoryProvider).addWork(draft);
      ref.read(miscellaneousWorkListProvider.notifier).prependLocal(created);
      return created;
    } finally {
      link.close();
    }
  }

  Future<MiscellaneousWork> updateWork(MiscellaneousWork work) async {
    final link = ref.keepAlive();
    try {
      final updated =
          await ref.read(miscellaneousWorkRepositoryProvider).updateWork(work);
      ref.read(miscellaneousWorkListProvider.notifier).replaceLocal(updated);
      return updated;
    } finally {
      link.close();
    }
  }
}
