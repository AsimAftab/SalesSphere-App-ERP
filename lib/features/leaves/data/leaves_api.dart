import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/leaves/data/dto/leave_dto.dart';

/// Raw data source for the leaves endpoints. Currently backed by a
/// mutable in-memory list — swap for Dio calls once the leaves
/// endpoint lands in the backend OpenAPI spec. Repository callers stay
/// unchanged.
class LeavesApi {
  LeavesApi() {
    _store
      ..clear()
      ..addAll(_seed.map(LeaveDto.fromJson));
  }

  static final List<Map<String, dynamic>> _seed = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': '1',
      'category': 'sick',
      'startDate': '2026-04-12T00:00:00.000',
      'reason': 'Down with viral fever, doctor advised one day rest.',
      'status': 'approved',
      'createdAt': '2026-04-11T18:30:00.000',
    },
    <String, dynamic>{
      'id': '2',
      'category': 'religious',
      'startDate': '2026-05-04T00:00:00.000',
      'endDate': '2026-05-08T00:00:00.000',
      'reason': 'Tihar festival — observing rituals at home.',
      'status': 'approved',
      'createdAt': '2026-04-20T09:15:00.000',
    },
    <String, dynamic>{
      'id': '3',
      'category': 'familyResponsibility',
      'startDate': '2026-05-22T00:00:00.000',
      'reason': 'Accompanying parent to a hospital appointment.',
      'status': 'pending',
      'createdAt': '2026-05-15T11:00:00.000',
    },
    <String, dynamic>{
      'id': '4',
      'category': 'compassionate',
      'startDate': '2026-03-02T00:00:00.000',
      'endDate': '2026-03-04T00:00:00.000',
      'reason': 'Funeral rites for a close relative.',
      'status': 'rejected',
      'createdAt': '2026-03-01T20:45:00.000',
    },
  ];

  final List<LeaveDto> _store = <LeaveDto>[];

  Future<List<LeaveDto>> list() async {
    // Simulated round-trip so callers exercise the loading state path.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final sorted = _store.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<LeaveDto>.unmodifiable(sorted);
  }

  Future<LeaveDto> create(LeaveDto draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // New requests always start as pending — the API mock owns status
    // assignment so callers can't accidentally submit pre-approved
    // rows. Real backend will enforce the same.
    final created = LeaveDto(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      category: draft.category,
      startDate: draft.startDate,
      endDate: draft.endDate,
      reason: draft.reason,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    _store.add(created);
    return created;
  }

  Future<LeaveDto> update(LeaveDto leave) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _store.indexWhere((l) => l.id == leave.id);
    if (index == -1) {
      throw StateError('Leave ${leave.id} not found');
    }
    _store[index] = leave;
    return leave;
  }
}

final leavesApiProvider = Provider<LeavesApi>((_) => LeavesApi());
