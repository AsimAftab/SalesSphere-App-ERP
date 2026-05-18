import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/prospects/data/dto/prospect_dto.dart';
import 'package:sales_sphere_erp/features/prospects/data/dto/prospect_image_ref.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect_conversion_result.dart';

/// Page size for the live `GET /prospects` integration. Matches the
/// `?limit=10` requested by the list screen.
const int _kProspectsPageLimit = 10;

/// HTTP layer for the prospects feature. Read + write paths now hit the
/// real `/prospects` endpoints; the interest catalogue is still mocked
/// in-memory until a `/prospect-interests` endpoint exists.
class ProspectsApi {
  ProspectsApi(this._dio);

  final Dio _dio;

  /// Page size used when pulling the prospect-category catalogue. The
  /// backend's pagination ceiling is generous; one large page covers
  /// realistic catalogue sizes without threading load-more through the
  /// picker. If `hasMore` ever returns true at this limit we'll need to
  /// add server-side autocomplete instead.
  static const int _kCategoriesPageLimit = 200;

  /// Session-local additions made via [addInterestCategory] /
  /// [addInterestBrand]. Merged on top of the network response inside
  /// [interestCatalogue] so inline adds remain visible until the user
  /// refreshes from the backend (which is when their inline picks will
  /// have been persisted via prospect-create or some future
  /// `/prospect-categories` POST).
  static final Map<String, List<String>> _pendingAdditions =
      <String, List<String>>{};

  /// Fetch one page from `GET /prospects`. The server is authoritative on
  /// pagination — the inner envelope carries `items`, `hasMore`, and
  /// `nextCursor`. The caller only consumes `items` for now; pagination
  /// state is plumbed through once the list page learns load-more.
  Future<List<ProspectDto>> list({
    int limit = _kProspectsPageLimit,
    String? cursor,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.prospects,
      queryParameters: <String, dynamic>{
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final data = _unwrapMap(response.data);
    final rawItems = data['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException(
        'Malformed prospects page: missing or invalid `items` array',
      );
    }
    return rawItems
        .map((j) => ProspectDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Single-row read for cold-start deep-links. Body is the same
  /// envelope shape as `list()` but with the prospect object inline at
  /// `data` (no `items` array).
  Future<ProspectDto> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.prospectById(id),
    );
    return ProspectDto.fromJson(_unwrapMap(response.data));
  }

  /// `POST /prospects`. Body is the writable subset produced by
  /// `ProspectDto.toJson()` — server assigns `id`, `createdAt`,
  /// `interests[i].id`, etc.
  Future<ProspectDto> create(ProspectDto draft) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.prospects,
      data: draft.toJson(),
    );
    return ProspectDto.fromJson(_unwrapMap(response.data));
  }

  /// `PATCH /prospects/{id}`. Same writable shape as `create`; the server
  /// treats omitted fields as untouched and explicit `null` as a clear.
  Future<ProspectDto> update(ProspectDto prospect) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      Endpoints.prospectById(prospect.id),
      data: prospect.toJson(),
    );
    return ProspectDto.fromJson(_unwrapMap(response.data));
  }

  /// `GET /prospects/{id}/images`. Returns the prospect's gallery,
  /// ordered by `sortOrder` ascending. Used to hydrate the edit form's
  /// picker so the user sees existing images and can delete or replace
  /// them. Returns `[]` if the response shape is unexpected so the
  /// edit page can still render.
  Future<List<ProspectImageRef>> listImages(String prospectId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.prospectImages(prospectId),
    );
    final body = response.data;
    if (body == null || body['success'] == false) return const [];
    final data = body['data'];
    if (data is! List<dynamic>) return const [];
    return data
        .map((j) => ProspectImageRef.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `POST /prospects/{id}/images` — multipart `image` file + integer
  /// `imageNumber` form field. Slot-based upsert: re-posting the same
  /// slot replaces the existing image.
  ///
  /// Mirrors the parties + sites image-upload pattern, including the
  /// two non-obvious details:
  ///   * `imageNumber` is added **before** the file. Multer streams
  ///     parts in order and populates `req.body` text fields as it
  ///     goes — text after a file part can be left unread.
  ///   * The file's `Content-Type` is set explicitly from the
  ///     extension. Without it, `MultipartFile.fromFile` ships
  ///     `application/octet-stream`, Cloudinary refuses the blob, and
  ///     the backend wraps the failure as a generic 500.
  Future<void> uploadImage({
    required String prospectId,
    required String filePath,
    required int imageNumber,
  }) async {
    final filename = filePath.split(RegExp(r'[\\/]')).last;
    if (kDebugMode) {
      try {
        final bytes = await File(filePath).length();
        debugPrint(
          '[prospects_api] uploadImage slot=$imageNumber '
          'file=$filename size=${bytes}B (${(bytes / 1024 / 1024).toStringAsFixed(2)} MB)',
        );
      } on FileSystemException {
        debugPrint(
          '[prospects_api] uploadImage slot=$imageNumber file=$filename '
          'size=<stat failed>',
        );
      }
    }
    final form = FormData.fromMap(<String, dynamic>{
      'imageNumber': imageNumber.toString(),
      'image': await MultipartFile.fromFile(
        filePath,
        filename: filename,
        contentType: _mediaTypeForFilename(filename),
      ),
    });
    await _dio.post<Map<String, dynamic>>(
      Endpoints.prospectImages(prospectId),
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  /// Maps a filename's extension to a `Content-Type`. The backend only
  /// accepts JPEG and PNG; anything else falls back to
  /// `application/octet-stream` so the server's mime filter rejects it
  /// explicitly.
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

  /// `DELETE /prospects/{id}/images/{imageNumber}` — removes a specific
  /// slot. No-op idempotency on 404 is up to the caller.
  Future<void> removeImage({
    required String prospectId,
    required int imageNumber,
  }) async {
    await _dio.delete<Map<String, dynamic>>(
      Endpoints.prospectImageSlot(prospectId, imageNumber),
    );
  }

  /// `POST /prospects/{id}/convert` — promotes the prospect into a real
  /// customer. The backend handles the row swap server-side; we just
  /// surface the new `customerId` so the UI can navigate to the
  /// resulting party detail. `keepImages` controls whether the
  /// prospect's gallery is copied over (Cloudinary copy + slot
  /// re-bind).
  Future<ProspectConversionResult> convertToParty({
    required String prospectId,
    bool keepImages = true,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.prospectConvert(prospectId),
      data: <String, dynamic>{'keepImages': keepImages},
    );
    final data = _unwrapMap(response.data);
    final customerId = data['customerId'];
    if (customerId is! String || customerId.isEmpty) {
      throw const FormatException(
        'Malformed convert response: missing `customerId`',
      );
    }
    return ProspectConversionResult(
      convertedFromProspectId:
          (data['convertedFromProspectId'] as String?) ?? prospectId,
      customerId: customerId,
      transferredImageCount:
          (data['transferredImageCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// `GET /prospect-categories` — paginated list of categories with their
  /// brands. The picker wants the full catalogue in one go; we fetch
  /// one large page and flatten. Local additions made in this session
  /// (via [addInterestCategory] / [addInterestBrand]) are merged on
  /// top so an inline pick stays visible until the network catalogue
  /// next refreshes.
  Future<Map<String, List<String>>> interestCatalogue() async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.prospectCategories,
      queryParameters: <String, dynamic>{'limit': _kCategoriesPageLimit},
    );
    final data = _unwrapMap(response.data);
    final rawItems = data['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException(
        'Malformed prospect-categories page: missing or invalid `items`',
      );
    }
    final result = <String, List<String>>{};
    for (final item in rawItems) {
      if (item is! Map<String, dynamic>) continue;
      final name = item['name'] as String?;
      if (name == null || name.isEmpty) continue;
      final brands = (item['brands'] as List<dynamic>?)
              ?.cast<String>()
              .toList() ??
          <String>[];
      result[name] = brands;
    }
    // Merge pending session-local additions so the picker shows them
    // immediately (the backend doesn't have a "create category"
    // endpoint yet — categories materialise when a prospect that
    // references them is saved).
    for (final entry in _pendingAdditions.entries) {
      final list = result.putIfAbsent(entry.key, () => <String>[]);
      for (final brand in entry.value) {
        if (!list.contains(brand)) list.add(brand);
      }
    }
    return <String, List<String>>{
      for (final entry in result.entries)
        entry.key: List<String>.unmodifiable(entry.value),
    };
  }

  Future<void> addInterestCategory(String category) async {
    _pendingAdditions.putIfAbsent(category, () => <String>[]);
  }

  Future<void> addInterestBrand(String category, String brand) async {
    final list = _pendingAdditions.putIfAbsent(category, () => <String>[]);
    if (!list.contains(brand)) list.add(brand);
  }

  // ── Envelope helper ───────────────────────────────────────────────────────
  // Mirrors `parties_api.dart:_unwrapMap`; promote to a shared helper once a
  // third caller appears.
  Map<String, dynamic> _unwrapMap(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty response body');
    }
    if (body['success'] == false) {
      throw const FormatException('Prospects API returned success=false');
    }
    final inner = body['data'];
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed prospects envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }
}

final prospectsApiProvider = Provider<ProspectsApi>(
  (ref) => ProspectsApi(ref.watch(dioProvider)),
);
