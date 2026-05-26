import 'package:sales_sphere_erp/features/miscellaneous_work/domain/miscellaneous_work.dart';

/// One slice of the paginated miscellaneous-work list returned from
/// the repository. `nextCursor == null` ⇒ the server has no more
/// pages for this query.
class MiscellaneousWorkPage {
  const MiscellaneousWorkPage({required this.items, this.nextCursor});

  final List<MiscellaneousWork> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
