import 'package:sales_sphere_erp/features/notes/domain/note.dart';

/// One slice of the paginated notes list returned from the
/// repository. `nextCursor == null` ⇒ the server has no more pages
/// for this query.
class NotesPage {
  const NotesPage({required this.items, this.nextCursor});

  final List<Note> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
