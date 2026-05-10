import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';
import 'package:sales_sphere_erp/features/prospects/domain/usecases/add_interest_brand_usecase.dart';
import 'package:sales_sphere_erp/features/prospects/domain/usecases/add_interest_category_usecase.dart';
import 'package:sales_sphere_erp/features/prospects/domain/usecases/add_prospect_usecase.dart';
import 'package:sales_sphere_erp/features/prospects/domain/usecases/update_prospect_usecase.dart';
import 'package:sales_sphere_erp/features/prospects/presentation/providers/prospects_providers.dart';

part 'prospects_controller.g.dart';

/// Routes prospects write actions from the UI through the use cases.
/// Reads stay on `prospectsListProvider`, `prospectByIdProvider`, and
/// `prospectInterestsProvider`.
///
/// `build()` returns void — the controller has no observable state of
/// its own, it just exposes write methods. Consumers call
/// `ref.read(prospectsControllerProvider.notifier).addProspect(...)`.
///
/// Marked `keepAlive: true` so the notifier survives across the
/// `await` inside its write methods. Without it, the controller is
/// auto-disposed mid-call (no listeners hold it open) and the
/// follow-up `ref.invalidate(...)` after the await fails because
/// the underlying provider element is already gone.
@Riverpod(keepAlive: true)
class ProspectsController extends _$ProspectsController {
  @override
  void build() {}

  Future<Prospect> addProspect(Prospect draft) async {
    final created = await ref.read(addProspectUseCaseProvider)(draft);
    ref.invalidate(prospectsListProvider);
    return created;
  }

  Future<Prospect> updateProspect(Prospect prospect) async {
    final updated = await ref.read(updateProspectUseCaseProvider)(prospect);
    ref.invalidate(prospectsListProvider);
    return updated;
  }

  Future<void> addInterestCategory(String category) async {
    await ref.read(addInterestCategoryUseCaseProvider)(category);
    ref.invalidate(prospectInterestsProvider);
  }

  Future<void> addInterestBrand({
    required String category,
    required String brand,
  }) async {
    await ref.read(addInterestBrandUseCaseProvider)(
      category: category,
      brand: brand,
    );
    ref.invalidate(prospectInterestsProvider);
  }
}
