import 'package:sales_sphere_erp/features/targets/domain/target_item.dart';

/// Abstract repository interface for employee assigned targets.
abstract class TargetsRepository {
  /// Fetches assigned targets and actuals for the current employee.
  Future<List<TargetItem>> getMyTargets();
}
