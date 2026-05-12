import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/miscellaneous_work/data/dto/miscellaneous_work_dto.dart';

/// Raw data source for the miscellaneous-work endpoints. Currently
/// backed by a mutable in-memory list — swap for Dio calls once the
/// endpoint lands in the backend OpenAPI spec. Repository callers
/// stay unchanged.
class MiscellaneousWorkApi {
  MiscellaneousWorkApi() {
    _store
      ..clear()
      ..addAll(_seed.map(MiscellaneousWorkDto.fromJson));
  }

  /// Hand-rolled seed rows so the screen has plausible content on
  /// first launch. Dates are anchored to today / yesterday at
  /// construction time so the list never looks stale during demos.
  static List<Map<String, dynamic>> get _seed {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'id': '1',
        'natureOfWork': 'Generator maintenance',
        'assignedBy': 'Anita Desai',
        'workDate': today.toIso8601String(),
        'address':
            '4HP8+2RJ, Avalahalli, Bangalore Division, 560119, India',
        'latitude': 13.134963,
        'longitude': 77.566870,
        'createdAt': today
            .add(const Duration(hours: 10, minutes: 30))
            .toIso8601String(),
      },
      <String, dynamic>{
        'id': '2',
        'natureOfWork': 'Inventory audit at warehouse',
        'assignedBy': 'Ramesh Kulkarni',
        'workDate': yesterday.toIso8601String(),
        'address':
            'Plot 14, Singanayakanahalli, Bengaluru, Karnataka 560064, India',
        'latitude': 13.110000,
        'longitude': 77.580000,
        'createdAt': yesterday
            .add(const Duration(hours: 14, minutes: 15))
            .toIso8601String(),
      },
    ];
  }

  final List<MiscellaneousWorkDto> _store = <MiscellaneousWorkDto>[];

  Future<List<MiscellaneousWorkDto>> list() async {
    // Simulated round-trip so callers exercise the loading state.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final sorted = _store.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<MiscellaneousWorkDto>.unmodifiable(sorted.map(_cloneDto));
  }

  Future<MiscellaneousWorkDto> create(MiscellaneousWorkDto draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final created = MiscellaneousWorkDto(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      natureOfWork: draft.natureOfWork,
      assignedBy: draft.assignedBy,
      workDate: draft.workDate,
      address: draft.address,
      latitude: draft.latitude,
      longitude: draft.longitude,
      createdAt: DateTime.now(),
      imagePaths: List<String>.unmodifiable(draft.imagePaths),
    );
    _store.add(created);
    return _cloneDto(created);
  }

  Future<MiscellaneousWorkDto> update(MiscellaneousWorkDto work) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _store.indexWhere((w) => w.id == work.id);
    if (index == -1) {
      throw StateError('MiscellaneousWork ${work.id} not found');
    }
    final updated = _cloneDto(work);
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
  MiscellaneousWorkDto _cloneDto(MiscellaneousWorkDto dto) =>
      MiscellaneousWorkDto(
        id: dto.id,
        natureOfWork: dto.natureOfWork,
        assignedBy: dto.assignedBy,
        workDate: dto.workDate,
        address: dto.address,
        latitude: dto.latitude,
        longitude: dto.longitude,
        createdAt: dto.createdAt,
        imagePaths: List<String>.unmodifiable(dto.imagePaths),
      );
}

final miscellaneousWorkApiProvider =
    Provider<MiscellaneousWorkApi>((_) => MiscellaneousWorkApi());
