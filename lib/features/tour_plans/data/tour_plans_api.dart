import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/tour_plans/data/dto/tour_plan_dto.dart';

/// Raw data source for the tour-plans endpoints. Currently backed by a
/// mutable in-memory list — swap for Dio calls once the tour-plans
/// endpoint lands in the backend OpenAPI spec. Repository callers stay
/// unchanged.
class TourPlansApi {
  TourPlansApi() {
    _store
      ..clear()
      ..addAll(_seed.map(TourPlanDto.fromJson));
  }

  static final List<Map<String, dynamic>> _seed = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': '1',
      'placeOfVisit': 'Pokhara',
      'startDate': '2026-04-12T00:00:00.000',
      'endDate': '2026-04-14T00:00:00.000',
      'purpose': 'Quarterly distributor review and on-site stock audit.',
      'status': 'approved',
      'createdAt': '2026-04-05T18:30:00.000',
    },
    <String, dynamic>{
      'id': '2',
      'placeOfVisit': 'Biratnagar',
      'startDate': '2026-05-04T00:00:00.000',
      'endDate': '2026-05-06T00:00:00.000',
      'purpose': 'New retailer onboarding and territory mapping.',
      'status': 'pending',
      'createdAt': '2026-04-20T09:15:00.000',
    },
    <String, dynamic>{
      'id': '3',
      'placeOfVisit': 'Butwal',
      'startDate': '2026-05-22T00:00:00.000',
      'endDate': '2026-05-22T00:00:00.000',
      'purpose': 'Single-day site visit for a key customer escalation.',
      'status': 'pending',
      'createdAt': '2026-05-15T11:00:00.000',
    },
    <String, dynamic>{
      'id': '4',
      'placeOfVisit': 'Janakpur',
      'startDate': '2026-03-02T00:00:00.000',
      'endDate': '2026-03-04T00:00:00.000',
      'purpose': 'Regional dealer meet — postponed by management.',
      'status': 'rejected',
      'createdAt': '2026-03-01T20:45:00.000',
    },
  ];

  final List<TourPlanDto> _store = <TourPlanDto>[];

  Future<List<TourPlanDto>> list() async {
    // Simulated round-trip so callers exercise the loading state path.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final sorted = _store.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<TourPlanDto>.unmodifiable(sorted);
  }

  Future<TourPlanDto> create(TourPlanDto draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // New requests always start as pending — the API mock owns status
    // assignment so callers can't accidentally submit pre-approved
    // rows. Real backend will enforce the same.
    final created = TourPlanDto(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      placeOfVisit: draft.placeOfVisit,
      startDate: draft.startDate,
      endDate: draft.endDate,
      purpose: draft.purpose,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    _store.add(created);
    return created;
  }

  Future<TourPlanDto> update(TourPlanDto plan) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _store.indexWhere((p) => p.id == plan.id);
    if (index == -1) {
      throw StateError('Tour plan ${plan.id} not found');
    }
    _store[index] = plan;
    return plan;
  }
}

final tourPlansApiProvider = Provider<TourPlansApi>((_) => TourPlansApi());
