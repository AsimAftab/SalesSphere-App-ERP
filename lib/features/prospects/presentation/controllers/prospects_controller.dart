import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';
// `prospects_providers.dart` re-exports `prospectsRepositoryProvider`
// so the controller stays out of `features/.../data/`.
import 'package:sales_sphere_erp/features/prospects/presentation/providers/prospects_providers.dart';

part 'prospects_controller.g.dart';

/// Routes prospects write actions from the UI through the repository.
/// Reads stay on `prospectsListProvider`, `prospectByIdProvider`, and
/// `prospectInterestsProvider`.
///
/// Each write method opens a `ref.keepAlive()` link for the duration
/// of its in-flight `await` and closes it in `finally`. That keeps
/// the notifier (and its `ref`) valid through the post-await
/// `ref.invalidate(...)` without permanently pinning a write-only
/// controller in memory.
///
/// The controller now talks to `prospectsRepositoryProvider` directly —
/// the trivial passthrough use cases were removed because they only
/// forwarded a single repo call and added no business logic.
@riverpod
class ProspectsController extends _$ProspectsController {
  @override
  void build() {}

  Future<Prospect> addProspect(Prospect draft) async {
    final link = ref.keepAlive();
    try {
      final created =
          await ref.read(prospectsRepositoryProvider).addProspect(draft);
      ref.invalidate(prospectsListProvider);
      return created;
    } finally {
      link.close();
    }
  }

  Future<Prospect> updateProspect(Prospect prospect) async {
    final link = ref.keepAlive();
    try {
      final updated =
          await ref.read(prospectsRepositoryProvider).updateProspect(prospect);
      ref.invalidate(prospectsListProvider);
      return updated;
    } finally {
      link.close();
    }
  }

  Future<void> addInterestCategory(String category) async {
    final link = ref.keepAlive();
    try {
      await ref.read(prospectsRepositoryProvider).addInterestCategory(category);
      ref.invalidate(prospectInterestsProvider);
    } finally {
      link.close();
    }
  }

  Future<void> addInterestBrand({
    required String category,
    required String brand,
  }) async {
    final link = ref.keepAlive();
    try {
      await ref
          .read(prospectsRepositoryProvider)
          .addInterestBrand(category, brand);
      ref.invalidate(prospectInterestsProvider);
    } finally {
      link.close();
    }
  }
}
