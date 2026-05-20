import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/leaves/data/repositories/leaves_repository_impl.dart';
import 'package:sales_sphere_erp/features/leaves/domain/leave.dart';

// Re-export the repository provider so downstream consumers
// (controllers, tests) can depend on the contract surface without
// importing from `data/`. The impl import above stays because this
// file actually uses the provider in its own watch calls.
export 'package:sales_sphere_erp/features/leaves/data/repositories/leaves_repository_impl.dart'
    show leavesRepositoryProvider;

part 'leaves_providers.g.dart';

/// Convenience provider for screens that just need the current list.
@riverpod
Future<List<Leave>> leavesList(Ref ref) async {
  return ref.watch(leavesRepositoryProvider).getLeaves();
}

/// Resolves a single leave by id. Derived from the list provider's
/// `AsyncValue` so loading and error states propagate to consumers
/// instead of collapsing into `null`.
@riverpod
Future<Leave?> leaveById(Ref ref, String id) async {
  final leaves = await ref.watch(leavesListProvider.future);
  for (final leave in leaves) {
    if (leave.id == id) return leave;
  }
  return null;
}
