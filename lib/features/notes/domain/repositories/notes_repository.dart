import 'package:sales_sphere_erp/features/notes/data/dto/note_image_ref.dart';
import 'package:sales_sphere_erp/features/notes/data/notes_api.dart';
import 'package:sales_sphere_erp/features/notes/domain/note.dart';
import 'package:sales_sphere_erp/features/notes/domain/notes_page.dart';

/// Thrown by [NotesRepository.addNote] when the note row was
/// successfully created but at least one of the attached image
/// uploads failed. Carries the created [note] so callers can still
/// reflect the new row in the UI, plus per-slot [failures] keyed by
/// 1-indexed slot number with the backend's error message (or a
/// generic fallback when the response had no shape we recognised).
///
/// Hard failures (the note itself couldn't be created) keep bubbling
/// as the underlying `DioException` — those reach the form's generic
/// catch and leave the user on the page to retry.
class PartialImageUploadException implements Exception {
  const PartialImageUploadException({
    required this.note,
    required this.failures,
  });

  final Note note;
  final Map<int, String> failures;

  /// 1-indexed slot numbers that failed, in deterministic order so
  /// the form's snackbar copy is stable across runs.
  List<int> get failedSlots => failures.keys.toList()..sort();

  /// Convenience for snackbars: the first failure's backend message,
  /// or the generic fallback when there were none.
  String get firstMessage =>
      failures.isEmpty ? 'Upload failed' : failures.values.first;

  @override
  String toString() =>
      'PartialImageUploadException(note=${note.id}, failures=$failures)';
}

/// Domain-side contract for notes data. The concrete
/// implementation (DTO mapping, drift persistence, outbox enqueue)
/// lives in `data/repositories/notes_repository_impl.dart`.
abstract class NotesRepository {
  /// One paginated slice of `GET /notes`. Pass [cursor] to load the
  /// next page; pass [relatedTo] to narrow to a single link type.
  Future<NotesPage> getNotesPage({
    int limit = 10,
    String? cursor,
    NotesRelatedTo? relatedTo,
  });

  /// Persists the note + attached images. On image-only failures,
  /// throws [PartialImageUploadException] carrying the created note
  /// so the caller can still reflect the new row in the UI.
  Future<Note> addNote(Note draft);

  Future<Note> updateNote(Note note);

  /// Fetch the note's current image gallery for the edit form's
  /// picker to hydrate. Returns `[]` for a note with no images.
  Future<List<NoteImageRef>> listImages(String noteId);

  /// Upload (or replace) one image slot.
  Future<NoteImageRef> uploadImage({
    required String noteId,
    required String filePath,
    required int slot,
  });

  /// Delete one image slot.
  Future<void> removeImage({
    required String noteId,
    required int slot,
  });
}
