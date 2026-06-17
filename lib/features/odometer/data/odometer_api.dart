import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/odometer/data/dto/odometer_monthly_report_dto.dart';
import 'package:sales_sphere_erp/features/odometer/data/dto/odometer_record_dto.dart';
import 'package:sales_sphere_erp/features/odometer/data/dto/odometer_today_status_dto.dart';

/// HTTP layer for odometer. Every call hits the live backend; the
/// `{success, data}` envelope is peeled by [_unwrap]. Start/stop are
/// `multipart/form-data` so the photo rides along in the `image` field.
///
/// No CSRF header is attached: the backend's CSRF middleware exempts mobile
/// (`x-client-type: mobile`) / Bearer-token requests, both of which the shared
/// `DioClient` already sends.
class OdometerApi {
  OdometerApi(this._dio);

  final Dio _dio;

  /// `GET /odometer/status/today`.
  Future<OdometerTodayStatusDto> fetchTodayStatus() async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.odometerStatusToday,
    );
    return OdometerTodayStatusDto.fromJson(_unwrap(response.data));
  }

  /// `GET /odometer/my-monthly-report?year=&month=`.
  Future<OdometerMonthlyReportDto> fetchMonthlyReport(
    int year,
    int month,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.odometerMyMonthlyReport,
      queryParameters: <String, dynamic>{'year': year, 'month': month},
    );
    return OdometerMonthlyReportDto.fromJson(_unwrap(response.data));
  }

  /// `GET /odometer/:id`.
  Future<OdometerRecordDto> fetchById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.odometerById(id),
    );
    return OdometerRecordDto.fromJson(_unwrap(response.data));
  }

  /// `POST /odometer/start` (multipart). [unit] is the lowercase wire value
  /// (`km` / `miles`). Returns the created trip (`status: in_progress`).
  Future<OdometerRecordDto> start({
    required double startReading,
    required String unit,
    String? description,
    double? latitude,
    double? longitude,
    String? address,
    String? imagePath,
  }) async {
    final form = await _tripForm(
      readingField: 'startReading',
      unitField: 'startUnit',
      descriptionField: 'startDescription',
      reading: startReading,
      unit: unit,
      description: description,
      latitude: latitude,
      longitude: longitude,
      address: address,
      imagePath: imagePath,
    );
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.odometerStart,
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return OdometerRecordDto.fromJson(_unwrap(response.data));
  }

  /// `POST /odometer/stop` (multipart). Returns the completed trip with the
  /// server-computed `distance`.
  Future<OdometerRecordDto> stop({
    required double stopReading,
    required String unit,
    String? description,
    double? latitude,
    double? longitude,
    String? address,
    String? imagePath,
  }) async {
    final form = await _tripForm(
      readingField: 'stopReading',
      unitField: 'stopUnit',
      descriptionField: 'stopDescription',
      reading: stopReading,
      unit: unit,
      description: description,
      latitude: latitude,
      longitude: longitude,
      address: address,
      imagePath: imagePath,
    );
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.odometerStop,
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return OdometerRecordDto.fromJson(_unwrap(response.data));
  }

  /// `DELETE /odometer/:id`.
  Future<void> delete(String id) async {
    await _dio.delete<Map<String, dynamic>>(Endpoints.odometerById(id));
  }

  /// Builds the start/stop multipart body. Text fields go in **before** the
  /// file: Multer streams parts in order and may leave text fields that follow
  /// a file part unread. The file's `Content-Type` is set explicitly — without
  /// it `MultipartFile.fromFile` ships `application/octet-stream`, Cloudinary
  /// refuses the blob, and the backend wraps it as a generic 500.
  Future<FormData> _tripForm({
    required String readingField,
    required String unitField,
    required String descriptionField,
    required double reading,
    required String unit,
    String? description,
    double? latitude,
    double? longitude,
    String? address,
    String? imagePath,
  }) async {
    final map = <String, dynamic>{
      readingField: reading.toString(),
      unitField: unit,
      if (description != null && description.isNotEmpty)
        descriptionField: description,
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
      if (address != null && address.isNotEmpty) 'address': address,
    };
    if (imagePath != null) {
      final filename = imagePath.split(RegExp(r'[\\/]')).last;
      map['image'] = await MultipartFile.fromFile(
        imagePath,
        filename: filename,
        contentType: _mediaTypeForFilename(filename),
      );
    }
    return FormData.fromMap(map);
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
      throw const FormatException('Empty odometer response body');
    }
    if (body['success'] == false) {
      throw const FormatException('Odometer API returned success=false');
    }
    final inner = body['data'];
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed odometer envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }
}

final odometerApiProvider = Provider<OdometerApi>(
  (ref) => OdometerApi(ref.watch(dioProvider)),
);
