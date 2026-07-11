import 'package:sales_sphere_erp/features/targets/domain/repositories/targets_repository.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_item.dart';

/// Concrete repository implementation providing mock employee targets
/// for current day and month.
class TargetsRepositoryImpl implements TargetsRepository {
  const TargetsRepositoryImpl();

  @override
  Future<List<TargetItem>> getMyTargets() async {
    // Simulated network/db latency for realistic UI state transitions
    await Future<void>.delayed(const Duration(milliseconds: 250));

    const mockJsonList = <Map<String, dynamic>>[
      {
        'id': 't1',
        'rule': 'No. of Orders',
        'interval': 'Daily',
        'targetValue': 15,
        'actualValue': 12, // 80% -> Amber
        'status': 'Active',
      },
      {
        'id': 't2',
        'rule': 'Value of Orders',
        'interval': 'Monthly',
        'targetValue': 450000,
        'actualValue': 480000, // 100%+ -> Green
        'status': 'Completed',
      },
      {
        'id': 't3',
        'rule': 'No. of collections',
        'interval': 'Daily',
        'targetValue': 5,
        'actualValue': 5, // 100% -> Green
        'status': 'Completed',
      },
      {
        'id': 't4',
        'rule': 'Value of collections',
        'interval': 'Daily',
        'targetValue': 50000,
        'actualValue': 0, // 0 -> Red (No progress made)
        'status': 'Active',
      },
      {
        'id': 't5',
        'rule': 'No. of visits',
        'interval': 'Daily',
        'targetValue': 10,
        'actualValue': 6, // 60% -> Amber
        'status': 'Active',
      },
      {
        'id': 't6',
        'rule': 'New Party',
        'interval': 'Monthly',
        'targetValue': 10,
        'actualValue': 0, // 0 -> Red (No progress made)
        'status': 'Active',
      },
      {
        'id': 't7',
        'rule': 'New Prospect',
        'interval': 'Monthly',
        'targetValue': 15,
        'actualValue': 8, // 53% -> Amber
        'status': 'Active',
      },
      {
        'id': 't8',
        'rule': 'New Sites',
        'interval': 'Monthly',
        'targetValue': 5,
        'actualValue': 5, // 100% -> Green
        'status': 'Completed',
      },
    ];

    return mockJsonList.map(TargetItem.fromJson).toList();
  }
}
