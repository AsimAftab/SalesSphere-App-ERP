import 'package:sales_sphere_erp/features/collection/domain/collection.dart';

/// One cursor-paginated slice of the Collection Plus list.
///
/// [nextCursor] is null when the server reported no more rows — the only
/// end-of-list signal there is. No total count, no page number.
class CollectionPage {
  const CollectionPage({required this.items, this.nextCursor});

  final List<Collection> items;
  final String? nextCursor;
}
