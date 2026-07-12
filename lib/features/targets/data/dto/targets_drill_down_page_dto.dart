import 'package:sales_sphere_erp/features/targets/data/dto/target_transaction_dto.dart';

/// One page of the cursor-paginated `GET /targets/drill-down` response.
class TargetsDrillDownPageDto {
  const TargetsDrillDownPageDto({required this.items, this.nextCursor});

  final List<TargetTransactionDto> items;

  /// Opaque — pass back as `?cursor=`, never parse. Only meaningful when the
  /// server said `hasMore`; null means this was the last page.
  final String? nextCursor;
}
