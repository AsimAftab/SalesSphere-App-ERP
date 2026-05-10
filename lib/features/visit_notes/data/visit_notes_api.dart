import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/visit_notes/data/dto/visit_note_dto.dart';

/// Raw data source for the visit-notes endpoints. Currently backed by
/// a mutable in-memory list — swap for Dio calls once the visit-notes
/// endpoint lands in the backend OpenAPI spec. Repository callers stay
/// unchanged.
class VisitNotesApi {
  VisitNotesApi() {
    _store
      ..clear()
      ..addAll(_seed.map(VisitNoteDto.fromJson));
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

  final List<VisitNoteDto> _store = <VisitNoteDto>[];

  Future<List<VisitNoteDto>> list() async {
    // Simulated round-trip so callers exercise the loading state path.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List<VisitNoteDto>.unmodifiable(
      _store.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  Future<VisitNoteDto> create(VisitNoteDto draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final created = VisitNoteDto(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: draft.title,
      linkType: draft.linkType,
      linkId: draft.linkId,
      linkDisplayName: draft.linkDisplayName,
      description: draft.description,
      createdAt: DateTime.now(),
      imagePaths: draft.imagePaths,
    );
    _store.add(created);
    return created;
  }

  Future<VisitNoteDto> update(VisitNoteDto note) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _store.indexWhere((n) => n.id == note.id);
    if (index == -1) {
      throw StateError('Visit note ${note.id} not found');
    }
    _store[index] = note;
    return note;
  }
}

final visitNotesApiProvider = Provider<VisitNotesApi>((_) => VisitNotesApi());
