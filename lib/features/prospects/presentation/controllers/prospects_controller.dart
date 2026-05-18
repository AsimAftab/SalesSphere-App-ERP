import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/parties/presentation/providers/parties_providers.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect_conversion_result.dart';
import 'package:sales_sphere_erp/features/prospects/domain/repositories/prospects_repository.dart';
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
    } on ProspectPartialImageUploadException catch (e) {
      // Prospect was created; some images didn't upload. Still refresh
      // the list so the row appears, then rethrow so the form can show
      // a partial-success snackbar.
      ref
        ..invalidate(prospectsListProvider)
        ..invalidate(prospectByIdProvider(e.prospect.id));
      rethrow;
    } finally {
      link.close();
    }
  }

  Future<Prospect> updateProspect(Prospect prospect) async {
    final link = ref.keepAlive();
    try {
      final updated =
          await ref.read(prospectsRepositoryProvider).updateProspect(prospect);
      ref
        ..invalidate(prospectsListProvider)
        ..invalidate(prospectByIdProvider(prospect.id));
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

  /// Promote a prospect into a customer via
  /// `POST /prospects/{id}/convert`. On success the prospect row is gone
  /// server-side and a new customer row exists, so we invalidate both
  /// caches: the prospects list/byId so the row disappears, and the
  /// parties list (and its byId for the freshly minted customer) so the
  /// new party shows up immediately if the user navigates over.
  Future<ProspectConversionResult> convertToParty({
    required String prospectId,
    bool keepImages = true,
  }) async {
    final link = ref.keepAlive();
    try {
      final result =
          await ref.read(prospectsRepositoryProvider).convertToParty(
                prospectId: prospectId,
                keepImages: keepImages,
              );
      ref
        ..invalidate(prospectsListProvider)
        ..invalidate(prospectByIdProvider(prospectId));
      // Refresh the parties list so the new customer is visible there;
      // the partiesList notifier owns its own pagination state, so a
      // direct `refresh()` is the right primitive (cheaper than a full
      // provider invalidation and keeps the user's search query).
      await ref.read(partiesListProvider.notifier).refresh();
      return result;
    } finally {
      link.close();
    }
  }
}
