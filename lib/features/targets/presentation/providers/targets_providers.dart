import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sales_sphere_erp/features/targets/data/repositories/targets_repository_impl.dart';
import 'package:sales_sphere_erp/features/targets/domain/repositories/targets_repository.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_item.dart';

/// Provides the abstract [TargetsRepository] interface.
final targetsRepositoryProvider = Provider<TargetsRepository>((ref) {
  return const TargetsRepositoryImpl();
});

/// Fetches all assigned targets for the current employee.
final myTargetsProvider =
    FutureProvider.autoDispose<List<TargetItem>>((ref) async {
  final repository = ref.watch(targetsRepositoryProvider);
  return repository.getMyTargets();
});

/// Notifier managing the currently selected interval ('Daily' or 'Monthly').
class SelectedTargetIntervalNotifier extends Notifier<String> {
  @override
  String build() => 'Daily';

  void setInterval(String interval) {
    if (state != interval) {
      state = interval;
    }
  }
}

final selectedTargetIntervalProvider =
    NotifierProvider<SelectedTargetIntervalNotifier, String>(
  SelectedTargetIntervalNotifier.new,
);

/// Provides the list of target cards filtered by the selected interval.
final filteredTargetsProvider =
    Provider.autoDispose<AsyncValue<List<TargetItem>>>((ref) {
  final targetsAsync = ref.watch(myTargetsProvider);
  final selectedInterval = ref.watch(selectedTargetIntervalProvider);

  return targetsAsync.whenData((items) {
    return items
        .where(
          (item) =>
              item.interval.toLowerCase() == selectedInterval.toLowerCase(),
        )
        .toList();
  });
});
