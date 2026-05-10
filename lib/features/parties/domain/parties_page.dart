import 'package:sales_sphere_erp/features/parties/domain/party.dart';

/// One slice of the paginated parties list returned from the repository.
/// `nextCursor == null` ⇒ the server has no more pages for this query.
class PartiesPage {
  const PartiesPage({required this.items, this.nextCursor});

  final List<Party> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
