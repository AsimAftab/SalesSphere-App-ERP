import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/notes/data/dto/note_dto.dart';

/// Raw data source for the notes endpoints. Currently backed by
/// a mutable in-memory list — swap for Dio calls once the notes
/// endpoint lands in the backend OpenAPI spec. Repository callers stay
/// unchanged.
class NotesApi {
  NotesApi() {
    _store
      ..clear()
      ..addAll(_seed.map(NoteDto.fromJson));
  }

  static final List<Map<String, dynamic>> _seed = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': '1',
      'title': 'Quarterly review with Anil',
      'linkType': 'party',
      'linkId': '1',
      'linkDisplayName': 'Bibhuti Traders',
      'description':
          'Discussed Q1 performance, restock schedule, and renewal of the supply contract.',
      'createdAt': '2026-04-22T10:30:00.000',
    },
    <String, dynamic>{
      'id': '2',
      'title': 'Initial pitch — Eastern Region',
      'linkType': 'prospect',
      'linkId': '1',
      'linkDisplayName': 'Sample Prospect 1',
      'description':
          'Walked through the catalogue, left product samples, follow-up scheduled for next week.',
      'createdAt': '2026-04-25T14:15:00.000',
    },
    <String, dynamic>{
      'id': '3',
      'title': 'Site visit — power outage check',
      'linkType': 'site',
      'linkId': '1',
      'linkDisplayName': 'Acme Warehouse',
      'description':
          'Backup generator inspected, fuel topped up. Recommend a quarterly load test.',
      'createdAt': '2026-04-28T09:00:00.000',
    },
  ];

  final List<NoteDto> _store = <NoteDto>[];

  Future<List<NoteDto>> list() async {
    // Simulated round-trip so callers exercise the loading state path.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final sorted = _store.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<NoteDto>.unmodifiable(sorted.map(_cloneDto));
  }

  Future<NoteDto> create(NoteDto draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final created = NoteDto(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: draft.title,
      linkType: draft.linkType,
      linkId: draft.linkId,
      linkDisplayName: draft.linkDisplayName,
      description: draft.description,
      createdAt: DateTime.now(),
      imagePaths: List<String>.unmodifiable(draft.imagePaths),
      nextFollowUpAt: draft.nextFollowUpAt,
    );
    _store.add(created);
    return _cloneDto(created);
  }

  Future<NoteDto> update(NoteDto note) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _store.indexWhere((n) => n.id == note.id);
    if (index == -1) {
      throw StateError('Note ${note.id} not found');
    }
    final updated = _cloneDto(note);
    _store[index] = updated;
    return _cloneDto(updated);
  }

  /// Defensive copy of a DTO. The mock store needs to insulate itself
  /// from caller mutation in both directions: callers can't mutate
  /// what they put in (so a later `imagePaths.add(...)` doesn't bleed
  /// into seeded state) and can't mutate what they get out (so a
  /// `list()` consumer can't reorder the store by sorting in place).
  /// `imagePaths` is wrapped in `unmodifiable` to enforce that on the
  /// list as well, not just the DTO reference.
  NoteDto _cloneDto(NoteDto dto) => NoteDto(
    id: dto.id,
    title: dto.title,
    linkType: dto.linkType,
    linkId: dto.linkId,
    linkDisplayName: dto.linkDisplayName,
    description: dto.description,
    createdAt: dto.createdAt,
    imagePaths: List<String>.unmodifiable(dto.imagePaths),
    nextFollowUpAt: dto.nextFollowUpAt,
  );
}

final notesApiProvider = Provider<NotesApi>((_) => NotesApi());
