import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/tour_plans/data/dto/tour_plan_dto.dart';

/// Raw data source for the tour-plans endpoints.
class TourPlansApi {
  TourPlansApi(this._dio) {
    _store
      ..clear()
      ..addAll(_seed.map(TourPlanDto.fromJson));
  }

  final Dio _dio;

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

  Future<List<TourPlanDto>> list({String? status, int limit = 10}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.tourPlans,
      queryParameters: <String, dynamic>{
        'limit': limit,
        if (status != null) 'status': status,
      },
    );
    final data = _unwrapMap(response.data);
    final rawItems = data['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException(
        'Malformed tour-plans page: missing or invalid `items` array',
      );
    }
    final items = rawItems
        .map((j) => TourPlanDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
    _store
      ..clear()
      ..addAll(items);
    return items;
  }

  Future<TourPlanDto?> getById(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        Endpoints.tourPlanById(id),
      );
      return TourPlanDto.fromJson(_unwrapMap(response.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<TourPlanDto> create(TourPlanDto draft) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.tourPlans,
      data: draft.toCreateJson(),
    );
    final created = TourPlanDto.fromJson(_unwrapMap(response.data));
    _store
      ..removeWhere((p) => p.id == created.id)
      ..add(created);
    return created;
  }

  Future<TourPlanDto> update(TourPlanDto plan) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      Endpoints.tourPlanById(plan.id),
      data: plan.toCreateJson(),
    );
    final updated = TourPlanDto.fromJson(_unwrapMap(response.data));
    _store
      ..removeWhere((p) => p.id == updated.id)
      ..add(updated);
    return updated;
  }

  Future<TourPlanDto> markTourPlanCompleted(String id) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.tourPlanStatus(id),
      data: <String, dynamic>{'action': 'COMPLETED'},
    );
    final updated = TourPlanDto.fromJson(_unwrapMap(response.data));
    _store
      ..removeWhere((p) => p.id == updated.id)
      ..add(updated);
    return updated;
  }

  Object _unwrapData(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty response body');
    }
    if (body['success'] == false) {
      throw const FormatException('Tour plans API returned success=false');
    }
    final inner = body['data'];
    if (inner == null) {
      throw const FormatException(
        'Malformed tour-plans envelope: missing `data`',
      );
    }
    return inner as Object;
  }

  Map<String, dynamic> _unwrapMap(Map<String, dynamic>? body) {
    final inner = _unwrapData(body);
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed tour-plans envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }
}

final tourPlansApiProvider = Provider<TourPlansApi>(
  (ref) => TourPlansApi(ref.watch(dioProvider)),
);
