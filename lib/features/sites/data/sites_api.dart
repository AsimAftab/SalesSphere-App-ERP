import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/sites/data/dto/site_category_dto.dart';
import 'package:sales_sphere_erp/features/sites/data/dto/site_dto.dart';
import 'package:sales_sphere_erp/features/sites/data/dto/site_image_ref.dart';
import 'package:sales_sphere_erp/features/sites/data/dto/sub_organization_dto.dart';

/// Page size for the one-shot fetches that back the picker dropdowns.
/// Categories + sub-organizations are bounded reference lists; a single
/// large page keeps the call simple. Revisit when an org legitimately
/// grows past 100 of either.
const int _kReferenceListPageLimit = 100;

/// HTTP layer for the sites feature. List, byId, PATCH, image
/// upload/list/delete, interest catalogue, and sub-org dropdown all
/// hit real `/sites…` endpoints. `POST /sites` is the last mocked
/// write path — when it lands the holding `_writeStore` goes away.
class SitesApi {
  SitesApi(this._dio);

  final Dio _dio;

  // ── Sites list / byId / write ───────────────────────────────────────────

  /// Fetch one paginated page from `GET /sites`. The server is
  /// authoritative on pagination: the inner envelope carries `items`,
  /// `hasMore`, and `nextCursor`. Optional `search` filters by
  /// name/address on the server side.
  ///
  /// Returns just the flat `List<SiteDto>` for now since the mobile
  /// list provider doesn't paginate yet — when we add infinite scroll
  /// this method graduates to returning a `SitesPageDto` (items +
  /// nextCursor), same shape as `PartiesPageDto`.
  Future<List<SiteDto>> list({
    int limit = 20,
    String? cursor,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.sites,
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
        'Malformed sites page: missing or invalid `items` array',
      );
    }
    return rawItems
        .map((j) => SiteDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Single-row read for deep-link / detail cold-starts.
  Future<SiteDto> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.siteById(id),
    );
    return SiteDto.fromJson(_unwrapMap(response.data));
  }

  /// `PATCH /sites/{id}`. The writable body shape is produced by
  /// `SiteDto.toJson()` — server-managed fields (`id`, `createdAt`,
  /// `organizationId`, `companyId`, …) are intentionally excluded so
  /// the backend treats omitted fields as untouched and explicit
  /// nulls as a clear.
  Future<SiteDto> update(SiteDto site) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      Endpoints.siteById(site.id),
      data: site.toJson(),
    );
    return SiteDto.fromJson(_unwrapMap(response.data));
  }

  // ── Site images (multipart upload + slot delete + gallery list) ─────────

  /// `GET /sites/{id}/images`. Returns the site's gallery ordered by
  /// `sortOrder` ascending. Returns `[]` if the response envelope is
  /// shaped unexpectedly so the edit page can still render.
  Future<List<SiteImageRef>> listImages(String siteId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        Endpoints.siteImages(siteId),
      );
      final body = response.data;
      if (body == null || body['success'] == false) {
        debugPrint('[sites_api] listImages $siteId failed: body=$body');
        return const [];
      }
      final data = body['data'];
      if (data is! List<dynamic>) {
        debugPrint('[sites_api] listImages $siteId: data is not a list, got ${data.runtimeType}');
        return const [];
      }
      return data
          .map((j) => SiteImageRef.fromJson(j as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      debugPrint('[sites_api] listImages $siteId network error: ${e.message}');
      return const [];
    } catch (e, st) {
      debugPrint('[sites_api] listImages $siteId unexpected error: $e\n$st');
      return const [];
    }
  }

  /// `POST /sites/{id}/images` — multipart `image` file + integer
  /// `imageNumber` form field. Slot-based upsert: re-posting the same
  /// slot replaces the existing image. Mirrors `PartiesApi.uploadImage`
  /// — same Multer parsing order pitfall and Cloudinary content-type
  /// requirement apply here.
  Future<void> uploadImage({
    required String siteId,
    required String filePath,
    required int imageNumber,
  }) async {
    final filename = filePath.split(RegExp(r'[\\/]')).last;
    if (kDebugMode) {
      try {
        final bytes = await File(filePath).length();
        debugPrint(
          '[sites_api] uploadImage slot=$imageNumber '
          'file=$filename size=${bytes}B (${(bytes / 1024 / 1024).toStringAsFixed(2)} MB)',
        );
      } on FileSystemException {
        debugPrint(
          '[sites_api] uploadImage slot=$imageNumber file=$filename '
          'size=<stat failed>',
        );
      }
    }
    final form = FormData.fromMap(<String, dynamic>{
      // `imageNumber` is added before the file: Multer streams parts
      // in order and populates `req.body` text fields as it goes.
      'imageNumber': imageNumber.toString(),
      'image': await MultipartFile.fromFile(
        filePath,
        filename: filename,
        contentType: _mediaTypeForFilename(filename),
      ),
    });
    await _dio.post<Map<String, dynamic>>(
      Endpoints.siteImages(siteId),
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  /// Maps a filename's extension to a `Content-Type`. The backend only
  /// accepts JPEG and PNG; anything else falls back to
  /// `application/octet-stream` so the mime filter rejects it
  /// explicitly. Form-level validation in `isAllowedImageFile`
  /// (`shared/utils/image_validation.dart`) is meant to catch this
  /// earlier — this branch is defence-in-depth.
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

  /// `DELETE /sites/{id}/images/{imageNumber}` — removes a specific
  /// slot. 404 idempotency is up to the caller.
  Future<void> removeImage({
    required String siteId,
    required int imageNumber,
  }) async {
    await _dio.delete<Map<String, dynamic>>(
      Endpoints.siteImageSlot(siteId, imageNumber),
    );
  }

  // ── Reference catalogues (real) ─────────────────────────────────────────

  /// `GET /site-categories`. Reference-list shape; one large page is
  /// fetched and flattened to a `category → brands` map for the
  /// existing `InterestCatalogue.fromMap` constructor. If a real org
  /// grows past `_kReferenceListPageLimit` categories we'll switch to
  /// a paginated/search-driven picker.
  Future<Map<String, List<String>>> interestCatalogue() async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.siteCategories,
      queryParameters: <String, dynamic>{'limit': _kReferenceListPageLimit},
    );
    final data = _unwrapMap(response.data);
    final rawItems = data['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException(
        'Malformed site-categories page: missing or invalid `items` array',
      );
    }
    final out = <String, List<String>>{};
    for (final item in rawItems) {
      if (item is! Map<String, dynamic>) continue;
      final dto = SiteCategoryDto.fromJson(item);
      out[dto.name] = dto.brands;
    }
    return out;
  }

  /// `GET /site-sub-organizations`. Reference-list shape.
  Future<List<SubOrganizationDto>> subOrganizations() async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.siteSubOrganizations,
      queryParameters: <String, dynamic>{'limit': _kReferenceListPageLimit},
    );
    final data = _unwrapMap(response.data);
    final rawItems = data['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException(
        'Malformed site-sub-organizations page: missing or invalid `items` array',
      );
    }
    return rawItems
        .map((j) => SubOrganizationDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `POST /sites`. Same writable body shape as `update()` (produced
  /// by `SiteDto.toJson()`): `subOrganizationName` instead of id,
  /// `interests: [{ categoryName, brands }]`, `siteContacts` as
  /// tuples, `dateJoined` as `YYYY-MM-DD`. Server assigns `id`,
  /// `status`, timestamps, etc. and echoes the created row.
  Future<SiteDto> create(SiteDto draft) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.sites,
      data: draft.toJson(),
    );
    return SiteDto.fromJson(_unwrapMap(response.data));
  }

  // Note: there are no separate "add category" / "add brand" endpoints.
  // The server auto-upserts unknown category names and brand entries
  // when they appear inside `POST /sites` (or `PATCH /sites/{id}`) under
  // `interests: [{ categoryName, brands: [...] }]`. The interest picker
  // adds the new entry to the user's selection locally and the write
  // request carries it through — no separate round-trip needed.

  // ── Envelope helper ─────────────────────────────────────────────────────
  // Mirrors `parties_api.dart:_unwrapMap`. Promote to a shared helper
  // once a third caller appears.
  Map<String, dynamic> _unwrapMap(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty response body');
    }
    if (body['success'] == false) {
      throw const FormatException('Sites API returned success=false');
    }
    final inner = body['data'];
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed sites envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }
}

final sitesApiProvider = Provider<SitesApi>(
  (ref) => SitesApi(ref.watch(dioProvider)),
);
