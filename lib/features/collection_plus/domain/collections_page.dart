import 'package:sales_sphere_erp/features/collection_plus/domain/collection.dart';

/// One cursor-paginated slice of the Collection Plus list.
///
/// [nextCursor] is null when the server reported no more rows — the only
/// end-of-list signal there is. No total count, no page number.
class CollectionPlusPage {
  const CollectionPlusPage({required this.items, this.nextCursor});

  final List<CollectionPlus> items;
  final String? nextCursor;
}
