import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/notes/domain/note.dart';
// `notes_providers.dart` re-exports `notesRepositoryProvider`
// so the controller stays out of `features/.../data/`.
import 'package:sales_sphere_erp/features/notes/presentation/providers/notes_providers.dart';

part 'notes_controller.g.dart';

/// Routes notes write actions from the UI through the
/// repository. Reads stay on `notesListProvider` and
/// `noteByIdProvider`.
///
/// Each write method opens a `ref.keepAlive()` link for the duration
/// of its in-flight `await` and closes it in `finally`. That keeps
/// the notifier (and its `ref`) valid through the post-await
/// `ref.invalidate(...)` without permanently pinning a write-only
/// controller in memory.
@riverpod
class NotesController extends _$NotesController {
  @override
  void build() {}

  Future<Note> addNote(Note draft) async {
    final link = ref.keepAlive();
    try {
      final created = await ref.read(notesRepositoryProvider).addNote(draft);
      ref.invalidate(notesListProvider);
      return created;
    } finally {
      link.close();
    }
  }

  Future<Note> updateNote(Note note) async {
    final link = ref.keepAlive();
    try {
      final updated = await ref.read(notesRepositoryProvider).updateNote(note);
      ref.invalidate(notesListProvider);
      return updated;
    } finally {
      link.close();
    }
  }
}
