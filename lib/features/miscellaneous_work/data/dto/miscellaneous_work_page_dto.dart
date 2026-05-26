import 'package:sales_sphere_erp/features/miscellaneous_work/data/dto/miscellaneous_work_dto.dart';

/// One paginated slice of `GET /miscellaneous-work`. The wire envelope
/// carries `items`, `hasMore`, and `nextCursor` — the API extracts
/// those into this shape so callers don't have to.
class MiscellaneousWorkPageDto {
  const MiscellaneousWorkPageDto({required this.items, this.nextCursor});

  final List<MiscellaneousWorkDto> items;
  final String? nextCursor;
}
