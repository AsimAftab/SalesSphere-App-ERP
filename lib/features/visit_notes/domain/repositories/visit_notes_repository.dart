import 'package:sales_sphere_erp/features/visit_notes/domain/visit_note.dart';

/// Domain-side contract for visit-notes data. The concrete
/// implementation (DTO mapping, drift persistence, outbox enqueue)
/// lives in `data/repositories/visit_notes_repository_impl.dart`.
abstract class VisitNotesRepository {
  Future<List<VisitNote>> getVisitNotes();

  Future<VisitNote> addVisitNote(VisitNote draft);

  Future<VisitNote> updateVisitNote(VisitNote note);
}
