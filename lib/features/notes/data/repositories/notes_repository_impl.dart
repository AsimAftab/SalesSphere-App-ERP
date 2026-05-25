import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/notes/data/dto/note_dto.dart';
import 'package:sales_sphere_erp/features/notes/data/dto/note_image_ref.dart';
import 'package:sales_sphere_erp/features/notes/data/notes_api.dart';
import 'package:sales_sphere_erp/features/notes/domain/note.dart';
import 'package:sales_sphere_erp/features/notes/domain/notes_page.dart';
import 'package:sales_sphere_erp/features/notes/domain/repositories/notes_repository.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the
/// app. All DTO ↔ domain mapping happens here. Drift persistence +
/// outbox enqueue will land alongside a future drift table for notes.
class NotesRepositoryImpl implements NotesRepository {
  NotesRepositoryImpl({required NotesApi api}) : _api = api;

  final NotesApi _api;

  @override
  Future<NotesPage> getNotesPage({
    int limit = 10,
    String? cursor,
    NotesRelatedTo? relatedTo,
  }) async {
    final pageDto = await _api.list(
      limit: limit,
      cursor: cursor,
      relatedTo: relatedTo,
    );
    final items = pageDto.items.map(_toDomain).toList(growable: false);
    return NotesPage(items: items, nextCursor: pageDto.nextCursor);
  }

  /// Creates the note via `POST /notes`, then best-effort uploads each
  /// attached local image to its 1-indexed slot. Image failures are
  /// collected and surfaced as [PartialImageUploadException] so the
  /// form can still navigate forward (the note row exists) while
  /// telling the user which uploads didn't take.
  ///
  /// Hard failures on the create itself bubble as `DioException`.
  @override
  Future<Note> addNote(Note draft) async {
    final created = await _api.create(_toDto(draft));
    final domain = _toDomain(created);

    final failures = <int, String>{};
    for (var i = 0; i < draft.imagePaths.length; i++) {
      try {
        await _api.uploadImage(
          noteId: created.id,
          filePath: draft.imagePaths[i],
          imageNumber: i + 1,
        );
      } on DioException catch (e) {
        failures[i + 1] = extractBackendErrorMessage(e) ?? 'Upload failed';
      }
    }
    if (failures.isNotEmpty) {
      throw PartialImageUploadException(note: domain, failures: failures);
    }
    return domain;
  }

  @override
  Future<Note> updateNote(Note note) async {
    final updated = await _api.update(_toDto(note));
    return _toDomain(updated);
  }

  @override
  Future<List<NoteImageRef>> listImages(String noteId) =>
      _api.listImages(noteId);

  @override
  Future<NoteImageRef> uploadImage({
    required String noteId,
    required String filePath,
    required int slot,
  }) =>
      _api.uploadImage(
        noteId: noteId,
        filePath: filePath,
        imageNumber: slot,
      );

  @override
  Future<void> removeImage({
    required String noteId,
    required int slot,
  }) =>
      _api.removeImage(noteId: noteId, imageNumber: slot);

  /// Collapse the wire shape (`customerId | prospectId | siteId`)
  /// into the domain's `linkType + linkId`. Exactly one of the three
  /// id fields is expected to be non-null; if all three are null the
  /// row is malformed and we surface that rather than silently
  /// defaulting to `party`.
  ///
  /// `linkDisplayName` falls back to a generic label until the
  /// backend joins the linked entity's name into the response.
  Note _toDomain(NoteDto dto) {
    final NoteLinkType linkType;
    final String linkId;
    if (dto.customerId != null) {
      linkType = NoteLinkType.party;
      linkId = dto.customerId!;
    } else if (dto.prospectId != null) {
      linkType = NoteLinkType.prospect;
      linkId = dto.prospectId!;
    } else if (dto.siteId != null) {
      linkType = NoteLinkType.site;
      linkId = dto.siteId!;
    } else {
      throw FormatException(
        'Note ${dto.id} has no link target (customerId/prospectId/siteId all null)',
      );
    }
    return Note(
      id: dto.id,
      title: dto.title,
      linkType: linkType,
      linkId: linkId,
      linkDisplayName: _fallbackLinkLabel(linkType),
      description: dto.description,
      createdAt: dto.createdAt,
      nextFollowUpAt: dto.followUpDate,
    );
  }

  NoteDto _toDto(Note n) => NoteDto(
    id: n.id,
    title: n.title,
    description: n.description,
    createdAt: n.createdAt,
    customerId: n.linkType == NoteLinkType.party ? n.linkId : null,
    prospectId: n.linkType == NoteLinkType.prospect ? n.linkId : null,
    siteId: n.linkType == NoteLinkType.site ? n.linkId : null,
    followUpDate: n.nextFollowUpAt,
  );

  String _fallbackLinkLabel(NoteLinkType type) {
    switch (type) {
      case NoteLinkType.party:
        return 'Customer';
      case NoteLinkType.prospect:
        return 'Prospect';
      case NoteLinkType.site:
        return 'Site';
    }
  }
}

/// Exposes the abstract type so consumers depend on the contract,
/// not the impl class. Tests override this provider with a fake
/// `NotesRepository`.
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepositoryImpl(api: ref.watch(notesApiProvider));
});
