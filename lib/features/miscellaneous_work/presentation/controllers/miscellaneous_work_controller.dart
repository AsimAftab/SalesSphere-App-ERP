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
/// Each write method opens a `ref.keepAlive()` link for the duration
/// of its in-flight `await` and closes it in `finally`. That keeps
/// the notifier (and its `ref`) valid through the post-await
/// `ref.invalidate(...)` without permanently pinning a write-only
/// controller in memory.
@riverpod
class MiscellaneousWorkController extends _$MiscellaneousWorkController {
  @override
  void build() {}

  Future<MiscellaneousWork> addWork(MiscellaneousWork draft) async {
    final link = ref.keepAlive();
    try {
      final created =
          await ref.read(miscellaneousWorkRepositoryProvider).addWork(draft);
      ref.invalidate(miscellaneousWorkListProvider);
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
      ref.invalidate(miscellaneousWorkListProvider);
      return updated;
    } finally {
      link.close();
    }
  }
}
