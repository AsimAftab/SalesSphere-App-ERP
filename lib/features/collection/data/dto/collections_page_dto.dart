import 'package:sales_sphere_erp/features/collection/data/dto/collection_dto.dart';

/// One paginated slice of `GET /collections`. The wire envelope carries
/// `items`, `hasMore` and `nextCursor` — the API peels those into this shape
/// so callers don't have to.
///
/// Cursor-based, not offset: there is no `page` param and no total count.
/// `nextCursor` is only meaningful when `hasMore` is true.
class CollectionsPageDto {
  const CollectionsPageDto({required this.items, this.nextCursor});

  final List<CollectionDto> items;
  final String? nextCursor;
}
