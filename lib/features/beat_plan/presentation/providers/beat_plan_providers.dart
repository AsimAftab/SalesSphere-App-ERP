import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/beat_plan.dart';

part 'beat_plan_providers.g.dart';

@Riverpod(keepAlive: true)
class BeatPlanTabIndex extends _$BeatPlanTabIndex {
  @override
  int build() => 0;

  void setTab(int index) {
    state = index;
  }
}

@Riverpod(keepAlive: true)
class BeatPlanController extends _$BeatPlanController {
  @override
  Future<List<BeatPlan>> build() async {
    return _fetchMockData();
  }

  Future<List<BeatPlan>> _fetchMockData() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    return [
      BeatPlan(
        id: '1',
        title: 'Test Route',
        status: 'Active',
        assignedDate: DateTime(2026, 6, 13),
        startedDate: DateTime(2026, 6, 13),
        progress: 0.6,
        total: 5,
        visited: 3,
        pending: 2,
        skipped: 0,
      ),
      BeatPlan(
        id: '3',
        title: 'Upcoming Route',
        status: 'Pending',
        assignedDate: DateTime(2026, 6, 14),
        startedDate: DateTime(2026, 6, 14),
        progress: 0.0,
        total: 3,
        visited: 0,
        pending: 3,
        skipped: 0,
      ),
    ];
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchMockData());
  }

  Future<void> startPlan(String id) async {
    final currentPlans = state.value;
    if (currentPlans == null) return;

    final updatedPlans = currentPlans.map((plan) {
      if (plan.id == id) {
        return BeatPlan(
          id: plan.id,
          title: plan.title,
          status: 'Active',
          assignedDate: plan.assignedDate,
          startedDate: DateTime.now(),
          progress: plan.progress,
          total: plan.total,
          visited: plan.visited,
          pending: plan.pending,
          skipped: plan.skipped,
        );
      }
      return plan;
    }).toList();

    state = AsyncValue.data(updatedPlans);
  }
}
