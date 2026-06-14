import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';

/// Read-only REST companion to the socket layer (live writes go over the
/// socket). Used by the cold-start reconciler to ask the server whether a beat
/// plan still has an open tracking session.
class TrackingApi {
  TrackingApi(this._dio);

  final Dio _dio;

  /// `GET /tracking/:beatPlanId` → the active/paused session's status, or null
  /// when there's no open session (or the body is `data: null`).
  Future<String?> activeSessionStatus(String beatPlanId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.trackingByBeatPlan(beatPlanId),
    );
    final body = response.data;
    if (body == null || body['success'] == false) return null;
    final data = body['data'];
    if (data is! Map<String, dynamic>) return null;
    return data['status'] as String?;
  }
}

final trackingApiProvider = Provider<TrackingApi>(
  (ref) => TrackingApi(ref.watch(dioProvider)),
);
