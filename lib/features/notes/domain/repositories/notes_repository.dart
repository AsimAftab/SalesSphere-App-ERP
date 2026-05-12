import 'package:sales_sphere_erp/features/notes/domain/note.dart';

/// Domain-side contract for notes data. The concrete
/// implementation (DTO mapping, drift persistence, outbox enqueue)
/// lives in `data/repositories/notes_repository_impl.dart`.
abstract class NotesRepository {
  Future<List<Note>> getNotes();

  Future<Note> addNote(Note draft);

  Future<Note> updateNote(Note note);
}
