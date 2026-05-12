import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/notes/data/dto/note_dto.dart';
import 'package:sales_sphere_erp/features/notes/data/notes_api.dart';
import 'package:sales_sphere_erp/features/notes/domain/note.dart';
import 'package:sales_sphere_erp/features/notes/domain/repositories/notes_repository.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the
/// app. All DTO ↔ domain mapping happens here. Drift persistence +
/// outbox enqueue will land alongside the real API.
class NotesRepositoryImpl implements NotesRepository {
  NotesRepositoryImpl({required NotesApi api}) : _api = api;

  final NotesApi _api;

  @override
  Future<List<Note>> getNotes() async {
    final dtos = await _api.list();
    return dtos.map(_toDomain).toList(growable: false);
  }

  @override
  Future<Note> addNote(Note draft) async {
    final created = await _api.create(_toDto(draft));
    return _toDomain(created);
  }

  @override
  Future<Note> updateNote(Note note) async {
    final updated = await _api.update(_toDto(note));
    return _toDomain(updated);
  }

  Note _toDomain(NoteDto dto) => Note(
    id: dto.id,
    title: dto.title,
    linkType: _linkTypeFromWire(dto.linkType),
    linkId: dto.linkId,
    linkDisplayName: dto.linkDisplayName,
    description: dto.description,
    createdAt: dto.createdAt,
    imagePaths: dto.imagePaths,
    nextFollowUpAt: dto.nextFollowUpAt,
  );

  NoteDto _toDto(Note n) => NoteDto(
    // Server assigns the canonical id on create — placeholder here.
    id: n.id,
    title: n.title,
    linkType: _linkTypeToWire(n.linkType),
    linkId: n.linkId,
    linkDisplayName: n.linkDisplayName,
    description: n.description,
    createdAt: n.createdAt,
    imagePaths: n.imagePaths,
    nextFollowUpAt: n.nextFollowUpAt,
  );

  NoteLinkType _linkTypeFromWire(String wire) {
    switch (wire) {
      case 'party':
        return NoteLinkType.party;
      case 'prospect':
        return NoteLinkType.prospect;
      case 'site':
        return NoteLinkType.site;
      default:
        // Surface unknown link types loudly: silently coercing to
        // `party` would misclassify the row in the UI and — worse —
        // overwrite the backend with `'party'` on the next update.
        // If/when the backend grows a fourth link type, this will
        // crash and force us to extend the enum + mapping rather than
        // rotting unnoticed.
        throw FormatException('Unsupported Note linkType: $wire');
    }
  }

  String _linkTypeToWire(NoteLinkType type) {
    switch (type) {
      case NoteLinkType.party:
        return 'party';
      case NoteLinkType.prospect:
        return 'prospect';
      case NoteLinkType.site:
        return 'site';
    }
  }
}

/// Exposes the abstract type so consumers depend on the contract,
/// not the impl class. Tests override this provider with a fake
/// `NotesRepository`.
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepositoryImpl(api: ref.watch(notesApiProvider));
});
