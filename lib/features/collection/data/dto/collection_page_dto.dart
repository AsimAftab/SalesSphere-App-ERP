import 'package:sales_sphere_erp/features/collection/data/dto/collection_dto.dart';

/// One paginated slice of `GET /collections`.
///
/// Cursor-based, not offset: there is no `page` param and no total count.
/// `nextCursor` is only meaningful when `hasMore` is true, so it's the sole
/// end-of-list signal — never infer the end from an empty page.
class CollectionPageDto {
  const CollectionPageDto({required this.items, this.nextCursor});

  final List<CollectionDto> items;
  final String? nextCursor;
}
