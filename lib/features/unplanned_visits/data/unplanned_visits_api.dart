import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/data/dto/unplanned_visit_dto.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/data/dto/unplanned_visits_today_dto.dart';

/// HTTP layer for unplanned visits. Every call hits the live backend; the
/// `{success, data}` envelope is peeled by [_unwrap]. Start is JSON; stop is
/// `multipart/form-data` so the single proof photo rides along in the `image`
/// field.
///
/// No CSRF header is attached: the backend's CSRF middleware exempts mobile
/// (`x-client-type: mobile`) / Bearer-token requests, both of which the shared
/// `DioClient` already sends.
class UnplannedVisitsApi {
  UnplannedVisitsApi(this._dio);

  final Dio _dio;

  /// `GET /unplanned-visits/status/today`.
  Future<UnplannedVisitsTodayDto> fetchTodayStatus() async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.unplannedVisitsStatusToday,
    );
    return UnplannedVisitsTodayDto.fromJson(_unwrap(response.data));
  }

  /// `GET /unplanned-visits/:id`.
  Future<UnplannedVisitDto> fetchById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.unplannedVisitById(id),
    );
    return UnplannedVisitDto.fromJson(_unwrap(response.data));
  }

  /// `POST /unplanned-visits/start`. [targetType] is the lowercase wire value
  /// (`customer` / `prospect` / `site`); exactly one id field is sent. Returns
  /// the created visit (`status: in_progress`).
  Future<UnplannedVisitDto> start({
    required String targetType,
    required String targetId,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final body = <String, dynamic>{
      switch (targetType) {
        'customer' => 'customerId',
        'prospect' => 'prospectId',
        _ => 'siteId',
      }: targetId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (address != null && address.isNotEmpty) 'address': address,
    };
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.unplannedVisitStart,
      data: body,
    );
    return UnplannedVisitDto.fromJson(_unwrap(response.data));
  }

  /// `POST /unplanned-visits/stop` (multipart). The server finds the rep's
  /// open visit (no id needed). Returns the completed visit.
  Future<UnplannedVisitDto> stop({
    required String imagePath,
    String? description,
    DateTime? followUpDate,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final filename = imagePath.split(RegExp(r'[\\/]')).last;
    final map = <String, dynamic>{
      if (description != null && description.isNotEmpty)
        'description': description,
      // Calendar day only — the backend stores follow-up as a date.
      if (followUpDate != null)
        'followUpDate': followUpDate.toIso8601String().split('T').first,
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
      if (address != null && address.isNotEmpty) 'address': address,
      // File goes last: Multer streams parts in order and may leave text
      // fields that follow a file part unread. The Content-Type is set
      // explicitly — without it the blob ships as application/octet-stream
      // and the server's mime filter / Cloudinary rejects it.
      'image': await MultipartFile.fromFile(
        imagePath,
        filename: filename,
        contentType: _mediaTypeForFilename(filename),
      ),
    };
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.unplannedVisitStop,
      data: FormData.fromMap(map),
      options: Options(contentType: 'multipart/form-data'),
    );
    return UnplannedVisitDto.fromJson(_unwrap(response.data));
  }

  /// `DELETE /unplanned-visits/:id`.
  Future<void> delete(String id) async {
    await _dio.delete<Map<String, dynamic>>(Endpoints.unplannedVisitById(id));
  }

  /// Maps a filename's extension to a `Content-Type`. The backend only accepts
  /// JPEG and PNG; anything else falls back to `application/octet-stream` so
  /// the server's mime filter rejects it explicitly.
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

  /// Peels the outer `{success, data}` transport envelope.
  Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty unplanned-visit response body');
    }
    if (body['success'] == false) {
      throw const FormatException('Unplanned-visit API returned success=false');
    }
    final inner = body['data'];
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed unplanned-visit envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }
}

final unplannedVisitsApiProvider = Provider<UnplannedVisitsApi>(
  (ref) => UnplannedVisitsApi(ref.watch(dioProvider)),
);
