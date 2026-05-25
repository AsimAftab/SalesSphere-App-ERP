import 'package:sales_sphere_erp/features/notes/data/dto/note_dto.dart';

/// One paginated slice of `GET /notes`. The wire envelope carries
/// `items`, `hasMore`, and `nextCursor` — the API extracts those into
/// this shape so callers don't have to.
class NotesPageDto {
  const NotesPageDto({required this.items, this.nextCursor});

  final List<NoteDto> items;
  final String? nextCursor;
}
