import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/data/dto/miscellaneous_work_dto.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/data/dto/miscellaneous_work_image_ref.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/data/dto/miscellaneous_work_page_dto.dart';

/// HTTP layer for the miscellaneous-work feature. The list, create,
/// update, and image upload/delete paths all hit the real backend.
class MiscellaneousWorkApi {
  MiscellaneousWorkApi(this._dio);

  final Dio _dio;

  /// Fetch one paginated page from `GET /miscellaneous-work`.
  ///
  /// The server is authoritative on pagination — the inner envelope
  /// carries `items`, `hasMore`, and `nextCursor`. We trust
  /// `nextCursor` when `hasMore` is true and clear it otherwise.
  Future<MiscellaneousWorkPageDto> list({
    int limit = 10,
    String? cursor,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.miscellaneousWork,
      queryParameters: <String, dynamic>{
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );
    final data = _unwrapMap(response.data);
    final rawItems = data['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException(
        'Malformed miscellaneous-work page: missing or invalid `items` array',
      );
    }
    final items = rawItems
        .map((j) => MiscellaneousWorkDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
    final hasMore = (data['hasMore'] as bool?) ?? false;
    final nextCursor = hasMore ? data['nextCursor'] as String? : null;
    return MiscellaneousWorkPageDto(items: items, nextCursor: nextCursor);
  }

  /// `POST /miscellaneous-work`. Body is the writable subset produced
  /// by `MiscellaneousWorkDto.toJson()` — server assigns `id`,
  /// `createdAt`, `createdById`, `organizationId`, etc.
  Future<MiscellaneousWorkDto> create(MiscellaneousWorkDto draft) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.miscellaneousWork,
      data: draft.toJson(),
    );
    return MiscellaneousWorkDto.fromJson(_unwrapMap(response.data));
  }

  /// `PATCH /miscellaneous-work/{id}`. Same writable shape as
  /// `create`. The response carries the full row including the
  /// embedded `images` array, but image sync (upload/delete) is the
  /// edit page's job — we just return the row.
  Future<MiscellaneousWorkDto> update(
    String id,
    MiscellaneousWorkDto patch,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      Endpoints.miscellaneousWorkById(id),
      data: patch.toJson(),
    );
    return MiscellaneousWorkDto.fromJson(_unwrapMap(response.data));
  }

  /// `GET /miscellaneous-work/{id}`. Same shape as the PATCH response —
  /// the full row plus an embedded `images` array of full image objects
  /// (with `sortOrder`, `imageUrl`, etc).
  Future<MiscellaneousWorkDto> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.miscellaneousWorkById(id),
    );
    return MiscellaneousWorkDto.fromJson(_unwrapMap(response.data));
  }

  /// Returns the row's gallery as `MiscellaneousWorkImageRef`s,
  /// ordered by `sortOrder` ascending. Reads the embedded image
  /// objects from `GET /miscellaneous-work/{id}` so the edit page sees
  /// real slot numbers (not array indices). Empty list when the row
  /// has no images.
  Future<List<MiscellaneousWorkImageRef>> listImages(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.miscellaneousWorkById(id),
    );
    final body = response.data;
    if (body == null || body['success'] == false) return const [];
    final data = body['data'];
    if (data is! Map<String, dynamic>) return const [];
    final raw = data['images'];
    if (raw is! List<dynamic>) return const [];
    final refs = <MiscellaneousWorkImageRef>[];
    for (final entry in raw) {
      // The list endpoint embeds images as plain URL strings; the
      // detail endpoint embeds them as full objects. Only the latter
      // carries enough data to derive a slot, so non-map entries are
      // skipped here.
      if (entry is Map<String, dynamic>) {
        refs.add(MiscellaneousWorkImageRef.fromJson(entry));
      }
    }
    refs.sort((a, b) => a.slot.compareTo(b.slot));
    return List<MiscellaneousWorkImageRef>.unmodifiable(refs);
  }

  /// `POST /miscellaneous-work/{id}/images` — multipart `image` file +
  /// `imageNumber` form field. Slot-based upsert: re-posting the same
  /// slot replaces the existing image.
  ///
  /// Same two non-obvious details as the notes / parties / sites
  /// variants:
  ///   * `imageNumber` is added **before** the file. Multer streams
  ///     parts in order and populates `req.body` text fields as it
  ///     goes — text after a file part can be left unread.
  ///   * The file's `Content-Type` is set explicitly from the
  ///     extension. Without it, `MultipartFile.fromFile` ships
  ///     `application/octet-stream`, Cloudinary refuses the blob, and
  ///     the backend wraps the failure as a generic 500.
  Future<MiscellaneousWorkImageRef> uploadImage({
    required String id,
    required String filePath,
    required int imageNumber,
  }) async {
    final filename = filePath.split(RegExp(r'[\\/]')).last;
    if (kDebugMode) {
      try {
        final bytes = await File(filePath).length();
        debugPrint(
          '[miscellaneous_work_api] uploadImage slot=$imageNumber '
          'file=$filename size=${bytes}B '
          '(${(bytes / 1024 / 1024).toStringAsFixed(2)} MB)',
        );
      } on FileSystemException {
        debugPrint(
          '[miscellaneous_work_api] uploadImage slot=$imageNumber '
          'file=$filename size=<stat failed>',
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
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.miscellaneousWorkImages(id),
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return MiscellaneousWorkImageRef.fromJson(_unwrapMap(response.data));
  }

  /// `DELETE /miscellaneous-work/{id}/images/{slot}` — removes a
  /// specific slot. No-op idempotency on 404 is up to the caller.
  Future<void> removeImage({
    required String id,
    required int imageNumber,
  }) async {
    await _dio.delete<Map<String, dynamic>>(
      Endpoints.miscellaneousWorkImageSlot(id, imageNumber),
    );
  }

  /// Maps a filename's extension to a `Content-Type`. The backend only
  /// accepts JPEG and PNG; anything else falls back to
  /// `application/octet-stream` so the server's mime filter rejects
  /// it explicitly.
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

  Map<String, dynamic> _unwrapMap(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty response body');
    }
    if (body['success'] == false) {
      throw const FormatException(
        'Miscellaneous-work API returned success=false',
      );
    }
    final inner = body['data'];
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed miscellaneous-work envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }
}

final miscellaneousWorkApiProvider = Provider<MiscellaneousWorkApi>(
  (ref) => MiscellaneousWorkApi(ref.watch(dioProvider)),
);
