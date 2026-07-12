import 'package:sales_sphere_erp/features/targets/domain/target_drill_down_record.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_enums.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_item.dart';

/// The rep's targets for one day, plus where they came from.
class MyTargetsSnapshot {
  const MyTargetsSnapshot({required this.items, required this.fromCache});

  final List<TargetItem> items;

  /// True when the network was unreachable and these are the last-synced
  /// rows out of drift. The page surfaces this with an offline banner.
  final bool fromCache;
}

/// One page of drill-down records. (Named "slice" — `TargetDrillDownPage`
/// is already the widget.)
class TargetDrillDownSlice {
  const TargetDrillDownSlice({required this.items, this.nextCursor});

  final List<TargetDrillDownRecord> items;

  /// Opaque cursor for the next page; null when this is the last one.
  final String? nextCursor;
}

/// Abstract repository interface for employee assigned targets. Read-only —
/// targets are created and assigned by an admin on web.
abstract class TargetsRepository {
  /// Fetches assigned targets and live actuals for the current employee.
  ///
  /// [date] == null sends no query param, letting the server resolve "today"
  /// in the **org's** timezone — deliberately not the device's date. Falls
  /// back to the drift cache only when the network is unreachable.
  Future<MyTargetsSnapshot> getMyTargets({DateTime? date});

  /// Fetches the records behind one achieved number. Network-only.
  ///
  /// [periodStart] / [periodEnd] come straight off the tapped `/targets/me`
  /// row and are inclusive at both ends.
  Future<TargetDrillDownSlice> getDrillDown({
    required TargetMetric metric,
    required DateTime periodStart,
    required DateTime periodEnd,
    int limit = 50,
    String? cursor,
  });
}
