import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/visit_notes/data/repositories/visit_notes_repository_impl.dart';
import 'package:sales_sphere_erp/features/visit_notes/domain/visit_note.dart';

// Re-export the repository provider so downstream consumers
// (controllers, tests) can depend on the contract surface without
// importing from `data/`. The impl import above stays because this
// file actually uses the provider in its own watch calls.
export 'package:sales_sphere_erp/features/visit_notes/data/repositories/visit_notes_repository_impl.dart'
    show visitNotesRepositoryProvider;

part 'visit_notes_providers.g.dart';

/// Convenience provider for screens that just need the current list.
@riverpod
Future<List<VisitNote>> visitNotesList(Ref ref) async {
  return ref.watch(visitNotesRepositoryProvider).getVisitNotes();
}

/// Resolves a single visit note by id. Derived from the list
/// provider's `AsyncValue` so loading and error states propagate to
/// consumers instead of collapsing into `null`.
@riverpod
Future<VisitNote?> visitNoteById(Ref ref, String id) async {
  final notes = await ref.watch(visitNotesListProvider.future);
  for (final note in notes) {
    if (note.id == id) return note;
  }
  return null;
}
