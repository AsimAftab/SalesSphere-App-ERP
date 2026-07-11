import 'package:sales_sphere_erp/features/collection_plus/data/dto/collection_plus_dto.dart';

/// One paginated slice of `GET /collection-plus`.
///
/// Cursor-based, not offset: there is no `page` param and no total count.
/// `nextCursor` is only meaningful when `hasMore` is true, so it's the sole
/// end-of-list signal — never infer the end from an empty page.
class CollectionPlusPageDto {
  const CollectionPlusPageDto({required this.items, this.nextCursor});

  final List<CollectionPlusDto> items;
  final String? nextCursor;
}
