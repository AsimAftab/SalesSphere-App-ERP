import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/visit_notes/data/dto/visit_note_dto.dart';
import 'package:sales_sphere_erp/features/visit_notes/data/visit_notes_api.dart';
import 'package:sales_sphere_erp/features/visit_notes/domain/repositories/visit_notes_repository.dart';
import 'package:sales_sphere_erp/features/visit_notes/domain/visit_note.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the
/// app. All DTO ↔ domain mapping happens here. Drift persistence +
/// outbox enqueue will land alongside the real API.
class VisitNotesRepositoryImpl implements VisitNotesRepository {
  VisitNotesRepositoryImpl({required VisitNotesApi api}) : _api = api;

  final VisitNotesApi _api;

  @override
  Future<List<VisitNote>> getVisitNotes() async {
    final dtos = await _api.list();
    return dtos.map(_toDomain).toList(growable: false);
  }

  @override
  Future<VisitNote> addVisitNote(VisitNote draft) async {
    final created = await _api.create(_toDto(draft));
    return _toDomain(created);
  }

  @override
  Future<VisitNote> updateVisitNote(VisitNote note) async {
    final updated = await _api.update(_toDto(note));
    return _toDomain(updated);
  }

  VisitNote _toDomain(VisitNoteDto dto) => VisitNote(
        id: dto.id,
        title: dto.title,
        linkType: _linkTypeFromWire(dto.linkType),
        linkId: dto.linkId,
        linkDisplayName: dto.linkDisplayName,
        description: dto.description,
        createdAt: dto.createdAt,
        imagePaths: dto.imagePaths,
      );

  VisitNoteDto _toDto(VisitNote n) => VisitNoteDto(
        // Server assigns the canonical id on create — placeholder here.
        id: n.id,
        title: n.title,
        linkType: _linkTypeToWire(n.linkType),
        linkId: n.linkId,
        linkDisplayName: n.linkDisplayName,
        description: n.description,
        createdAt: n.createdAt,
        imagePaths: n.imagePaths,
      );

  VisitNoteLinkType _linkTypeFromWire(String wire) {
    switch (wire) {
      case 'party':
        return VisitNoteLinkType.party;
      case 'prospect':
        return VisitNoteLinkType.prospect;
      case 'site':
        return VisitNoteLinkType.site;
      default:
        // Defensive: a future link type from the backend shouldn't
        // crash the list. Fall through to `party`; the DTO's display
        // name still renders correctly.
        return VisitNoteLinkType.party;
    }
  }

  String _linkTypeToWire(VisitNoteLinkType type) {
    switch (type) {
      case VisitNoteLinkType.party:
        return 'party';
      case VisitNoteLinkType.prospect:
        return 'prospect';
      case VisitNoteLinkType.site:
        return 'site';
    }
  }
}

/// Exposes the abstract type so consumers depend on the contract,
/// not the impl class. Tests override this provider with a fake
/// `VisitNotesRepository`.
final visitNotesRepositoryProvider = Provider<VisitNotesRepository>((ref) {
  return VisitNotesRepositoryImpl(api: ref.watch(visitNotesApiProvider));
});
