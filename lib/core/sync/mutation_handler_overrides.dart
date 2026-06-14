import 'package:sales_sphere_erp/core/sync/mutation_handler.dart';
import 'package:sales_sphere_erp/core/sync/sync_service.dart';
import 'package:sales_sphere_erp/features/beat_plan/data/beat_plan_sync_handler.dart';
import 'package:sales_sphere_erp/features/beat_plan/data/repositories/beat_plan_repository_impl.dart';
import 'package:sales_sphere_erp/features/parties/data/parties_sync_handler.dart';

/// Single composition point for every feature's [MutationHandler].
///
/// `mutationHandlersProvider` can only be overridden once — a second
/// `overrideWith` would replace the first, silently dropping a feature's
/// handler. So all feature handlers are merged here and the app installs this
/// one override in `bootstrap()`. New features add their handler to the list
/// below.
final mutationHandlersOverride =
    mutationHandlersProvider.overrideWith((ref) {
  final handlers = <String, MutationHandler>{};
  void register(MutationHandler handler) =>
      handlers[handler.operation] = handler;

  register(PartiesSyncHandler(ref));
  register(BeatPlanStopSyncHandler(ref, kBeatPlanVisitOperation));
  register(BeatPlanStopSyncHandler(ref, kBeatPlanSkipOperation));

  return handlers;
});
