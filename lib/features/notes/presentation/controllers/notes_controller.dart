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
/// On success the controller patches the paginated list notifier
/// directly (`prependLocal` / `replaceLocal`) instead of invalidating
/// it. Invalidation would refetch every page from scratch and lose
/// the user's scroll position; an in-place patch keeps the new row
/// at the top while leaving the rest of the list untouched.
///
/// Each write method opens a `ref.keepAlive()` link for the duration
/// of its in-flight `await` and closes it in `finally`. That keeps
/// the notifier (and its `ref`) valid through the post-await state
/// patch without permanently pinning a write-only controller in
/// memory.
@riverpod
class NotesController extends _$NotesController {
  @override
  void build() {}

  Future<Note> addNote(Note draft) async {
    final link = ref.keepAlive();
    try {
      final created = await ref.read(notesRepositoryProvider).addNote(draft);
      ref.read(notesListProvider.notifier).prependLocal(created);
      return created;
    } finally {
      link.close();
    }
  }

  Future<Note> updateNote(Note note) async {
    final link = ref.keepAlive();
    try {
      final updated = await ref.read(notesRepositoryProvider).updateNote(note);
      ref.read(notesListProvider.notifier).replaceLocal(updated);
      return updated;
    } finally {
      link.close();
    }
  }
}
