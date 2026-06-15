import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/beat_plan/data/dto/beat_plan_dto.dart';

/// Reps only ever see their own assignments, and a rep won't have hundreds of
/// live plans — one large page is simpler than threading pagination.
const int _kBeatPlansPageLimit = 100;

/// HTTP layer for beat plans. Reads hit `/beat-plans`; writes (`start`,
/// `visit`, `skip`) post to the corresponding action endpoints. Live tracking
/// writes do NOT go here — they go over the socket.
class BeatPlanApi {
  BeatPlanApi(this._dio);

  final Dio _dio;

  /// `GET /beat-plans?mine=true` — the caller's assigned plans.
  Future<BeatPlansPageDto> list({
    int limit = _kBeatPlansPageLimit,
    String? cursor,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.beatPlans,
      queryParameters: <String, dynamic>{
        'mine': true,
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );
    final data = _unwrapMap(response.data);
    final rawItems = data['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException(
        'Malformed beat-plans page: missing or invalid `items` array',
      );
    }
    final items = rawItems
        .map((j) => BeatPlanDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
    final hasMore = (data['hasMore'] as bool?) ?? false;
    final nextCursor = hasMore ? data['nextCursor'] as String? : null;
    return BeatPlansPageDto(items: items, nextCursor: nextCursor);
  }

  /// `GET /beat-plans/:id` — full detail including stops.
  Future<BeatPlanDto> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.beatPlanById(id),
    );
    return BeatPlanDto.fromJson(_unwrapMap(response.data));
  }

  /// `POST /beat-plans/:id/start` — transition to ACTIVE.
  Future<BeatPlanDto> start(String id) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.beatPlanStart(id),
    );
    return BeatPlanDto.fromJson(_unwrapMap(response.data));
  }

  /// `POST /beat-plans/:id/visit` — marks a stop visited with timing/notes/
  /// follow-up. Returns the full updated beat plan (with all stops).
  Future<BeatPlanDto> visit({
    required String beatPlanId,
    required String stopId,
    double? latitude,
    double? longitude,
    DateTime? visitStartedAt,
    DateTime? visitEndedAt,
    String? notes,
    DateTime? followUpDate,
    String? idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.beatPlanVisit(beatPlanId),
      data: visitBody(
        stopId: stopId,
        latitude: latitude,
        longitude: longitude,
        visitStartedAt: visitStartedAt,
        visitEndedAt: visitEndedAt,
        notes: notes,
        followUpDate: followUpDate,
      ),
      options: idempotencyKey == null
          ? null
          : Options(headers: <String, String>{
              'Idempotency-Key': idempotencyKey,
            }),
    );
    return BeatPlanDto.fromJson(_unwrapMap(response.data));
  }

  /// `POST /beat-plans/:id/stops/:stopId/images` — upload (slot 1) the visit
  /// proof photo. Multipart: `imageNumber` first, then the `image` file.
  /// Returns the stored Cloudinary URL.
  Future<String?> uploadStopImage({
    required String beatPlanId,
    required String stopId,
    required String filePath,
  }) async {
    final filename = filePath.split(RegExp(r'[\\/]')).last;
    final form = FormData.fromMap(<String, dynamic>{
      'imageNumber': '1',
      'image': await MultipartFile.fromFile(
        filePath,
        filename: filename,
        contentType: _mediaTypeForFilename(filename),
      ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.beatPlanStopImages(beatPlanId, stopId),
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    final body = response.data;
    if (body == null) return null;
    // The image endpoint returns the raw `{id, slot, url, sortOrder}` (some
    // deployments wrap it in `{data: ...}`) — handle both.
    final inner = body['data'];
    final obj = inner is Map<String, dynamic> ? inner : body;
    return obj['url'] as String?;
  }

  MediaType _mediaTypeForFilename(String filename) {
    final dotIdx = filename.lastIndexOf('.');
    final ext = dotIdx >= 0 ? filename.substring(dotIdx + 1).toLowerCase() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  /// `POST /beat-plans/:id/skip` — body `{stopId, latitude?, longitude?}`.
  Future<void> skip({
    required String beatPlanId,
    required String stopId,
    double? latitude,
    double? longitude,
    String? idempotencyKey,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      Endpoints.beatPlanSkip(beatPlanId),
      data: visitBody(stopId: stopId, latitude: latitude, longitude: longitude),
      options: idempotencyKey == null
          ? null
          : Options(headers: <String, String>{
              'Idempotency-Key': idempotencyKey,
            }),
    );
  }

  /// Shared body builder — also used by the repository to mint the outbox
  /// payload so online + queued writes stay byte-identical. Always pass an
  /// explicit [visitEndedAt] so an offline replay doesn't re-stamp to a later
  /// server `now()`.
  static Map<String, dynamic> visitBody({
    required String stopId,
    double? latitude,
    double? longitude,
    DateTime? visitStartedAt,
    DateTime? visitEndedAt,
    String? notes,
    DateTime? followUpDate,
  }) =>
      <String, dynamic>{
        'stopId': stopId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (visitStartedAt != null)
          'visitStartedAt': visitStartedAt.toUtc().toIso8601String(),
        if (visitEndedAt != null)
          'visitEndedAt': visitEndedAt.toUtc().toIso8601String(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        // Date-only (org-TZ start of day) — send the local calendar date so a
        // UTC conversion can't shift it across midnight.
        if (followUpDate != null)
          'followUpDate': '${followUpDate.year.toString().padLeft(4, '0')}-'
              '${followUpDate.month.toString().padLeft(2, '0')}-'
              '${followUpDate.day.toString().padLeft(2, '0')}',
      };

  Map<String, dynamic> _unwrapMap(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty response body');
    }
    if (body['success'] == false) {
      throw const FormatException('Beat-plans API returned success=false');
    }
    final inner = body['data'];
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed beat-plans envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }
}

final beatPlanApiProvider = Provider<BeatPlanApi>(
  (ref) => BeatPlanApi(ref.watch(dioProvider)),
);
