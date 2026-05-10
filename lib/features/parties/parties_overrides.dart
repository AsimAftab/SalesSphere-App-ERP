import 'package:sales_sphere_erp/core/sync/mutation_handler.dart';
import 'package:sales_sphere_erp/core/sync/sync_service.dart';
import 'package:sales_sphere_erp/features/parties/data/parties_sync_handler.dart';

/// ProviderScope overrides for the parties feature. Spread into the root
/// `ProviderScope` in `bootstrap()` alongside `authProviderOverrides`.
///
/// Today: registers `PartiesSyncHandler` against `mutationHandlersProvider`
/// so the sync drain knows how to reconcile `parties.create` responses
/// back into drift + the list notifier.
///
/// As other features (collections, expense claims, …) start using the
/// outbox path they'll add their own handlers; this list is the single
/// touchpoint that wires them all together.
final partiesProviderOverrides = [
  mutationHandlersProvider.overrideWith((ref) {
    final handler = PartiesSyncHandler(ref);
    return <String, MutationHandler>{handler.operation: handler};
  }),
];
