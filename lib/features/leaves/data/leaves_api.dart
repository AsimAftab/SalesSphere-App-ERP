import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/leaves/data/dto/leave_dto.dart';

/// HTTP layer for leaves. Every call hits the live backend; the
/// `{success, data}` transport envelope is peeled by [_unwrap]. The list
/// endpoint nests its rows one level deeper under `data.items` (the
/// cursor-pagination envelope).
class LeavesApi {
  LeavesApi(this._dio);

  final Dio _dio;

  /// `GET /leaves/my-requests` — the signed-in user's own leave requests.
  /// We pull a single large page (no pagination UI yet); 200 is the
  /// backend's max page size and far exceeds a field rep's realistic
  /// request count.
  Future<List<LeaveDto>> listMine() async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.leavesMyRequests,
      queryParameters: <String, dynamic>{'limit': 200},
    );
    final data = _unwrap(response.data);
    final items = data['items'];
    if (items is! List) {
      throw const FormatException(
        'Malformed leaves envelope: missing or invalid `items` array',
      );
    }
    return items
        .map((e) => LeaveDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `POST /leaves` — body `{category, reason, startDate, endDate?}`. The
  /// server resolves the employee from the session and forces the status to
  /// PENDING. Returns the created row (201).
  Future<LeaveDto> create(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.leaves,
      data: body,
    );
    return LeaveDto.fromJson(_unwrap(response.data));
  }

  /// `PATCH /leaves/:id` — partial update; only allowed while PENDING.
  Future<LeaveDto> update(String id, Map<String, dynamic> body) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      Endpoints.leaveById(id),
      data: body,
    );
    return LeaveDto.fromJson(_unwrap(response.data));
  }

  /// Peels the outer `{success, data}` transport envelope and returns the
  /// inner object.
  Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty leaves response body');
    }
    if (body['success'] == false) {
      throw const FormatException('Leaves API returned success=false');
    }
    final inner = body['data'];
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed leaves envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }
}

final leavesApiProvider = Provider<LeavesApi>(
  (ref) => LeavesApi(ref.watch(dioProvider)),
);
