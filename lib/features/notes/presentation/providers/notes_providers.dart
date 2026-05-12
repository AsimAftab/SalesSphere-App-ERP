import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:sales_sphere_erp/features/notes/domain/note.dart';

// Re-export the repository provider so downstream consumers
// (controllers, tests) can depend on the contract surface without
// importing from `data/`. The impl import above stays because this
// file actually uses the provider in its own watch calls.
export 'package:sales_sphere_erp/features/notes/data/repositories/notes_repository_impl.dart'
    show notesRepositoryProvider;

part 'notes_providers.g.dart';

/// Convenience provider for screens that just need the current list.
@riverpod
Future<List<Note>> notesList(Ref ref) async {
  return ref.watch(notesRepositoryProvider).getNotes();
}

/// Resolves a single note by id. Derived from the list
/// provider's `AsyncValue` so loading and error states propagate to
/// consumers instead of collapsing into `null`.
@riverpod
Future<Note?> noteById(Ref ref, String id) async {
  final notes = await ref.watch(notesListProvider.future);
  for (final note in notes) {
    if (note.id == id) return note;
  }
  return null;
}
