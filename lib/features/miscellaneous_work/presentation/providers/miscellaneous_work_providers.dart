import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/miscellaneous_work/data/repositories/miscellaneous_work_repository_impl.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/domain/miscellaneous_work.dart';

// Re-export the repository provider so downstream consumers
// (controllers, tests) can depend on the contract surface without
// importing from `data/`. The impl import above stays because this
// file actually uses the provider in its own watch calls.
export 'package:sales_sphere_erp/features/miscellaneous_work/data/repositories/miscellaneous_work_repository_impl.dart'
    show miscellaneousWorkRepositoryProvider;

part 'miscellaneous_work_providers.g.dart';

/// Convenience provider for screens that just need the current list.
@riverpod
Future<List<MiscellaneousWork>> miscellaneousWorkList(Ref ref) async {
  return ref.watch(miscellaneousWorkRepositoryProvider).getAll();
}

/// Resolves a single work item by id. Derived from the list provider's
/// `AsyncValue` so loading and error states propagate to consumers
/// instead of collapsing into `null`.
@riverpod
Future<MiscellaneousWork?> miscellaneousWorkById(Ref ref, String id) async {
  final items = await ref.watch(miscellaneousWorkListProvider.future);
  for (final w in items) {
    if (w.id == id) return w;
  }
  return null;
}
