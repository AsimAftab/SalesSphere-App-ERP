import 'package:sales_sphere_erp/features/collection/domain/collection.dart';

/// One cursor-paginated slice of the collections list.
///
/// [nextCursor] is null when the server reported no more rows — that's the
/// only "end of list" signal there is. There is no total count and no page
/// number, so never infer the end from an empty page.
class CollectionsPage {
  const CollectionsPage({required this.items, this.nextCursor});

  final List<Collection> items;
  final String? nextCursor;
}
