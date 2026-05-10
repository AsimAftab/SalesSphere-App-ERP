import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/visit_notes/domain/visit_note.dart';
// `visit_notes_providers.dart` re-exports `visitNotesRepositoryProvider`
// so the controller stays out of `features/.../data/`.
import 'package:sales_sphere_erp/features/visit_notes/presentation/providers/visit_notes_providers.dart';

part 'visit_notes_controller.g.dart';

/// Routes visit-notes write actions from the UI through the
/// repository. Reads stay on `visitNotesListProvider` and
/// `visitNoteByIdProvider`.
///
/// Each write method opens a `ref.keepAlive()` link for the duration
/// of its in-flight `await` and closes it in `finally`. That keeps
/// the notifier (and its `ref`) valid through the post-await
/// `ref.invalidate(...)` without permanently pinning a write-only
/// controller in memory.
@riverpod
class VisitNotesController extends _$VisitNotesController {
  @override
  void build() {}

  Future<VisitNote> addVisitNote(VisitNote draft) async {
    final link = ref.keepAlive();
    try {
      final created = await ref
          .read(visitNotesRepositoryProvider)
          .addVisitNote(draft);
      ref.invalidate(visitNotesListProvider);
      return created;
    } finally {
      link.close();
    }
  }

  Future<VisitNote> updateVisitNote(VisitNote note) async {
    final link = ref.keepAlive();
    try {
      final updated = await ref
          .read(visitNotesRepositoryProvider)
          .updateVisitNote(note);
      ref.invalidate(visitNotesListProvider);
      return updated;
    } finally {
      link.close();
    }
  }
}
