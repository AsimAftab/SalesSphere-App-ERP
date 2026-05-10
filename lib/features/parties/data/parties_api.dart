import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/parties/data/dto/parties_page_dto.dart';
import 'package:sales_sphere_erp/features/parties/data/dto/party_dto.dart';
import 'package:sales_sphere_erp/features/parties/data/dto/party_image_ref.dart';

/// Customer types are a small reference list; fetching one large page
/// is simpler than threading pagination through the form picker.
const int _kCustomerTypesPageLimit = 100;

/// HTTP layer for the parties feature. All read + write paths now hit the
/// real `/customers` and `/customer-types` endpoints; the mock in-memory
/// store is retired.
class PartiesApi {
  PartiesApi(this._dio);

  final Dio _dio;

  /// Fetch one paginated page from `GET /customers`.
  ///
  /// The server is authoritative on pagination: the inner envelope carries
  /// `items`, `hasMore`, and `nextCursor`. We trust `nextCursor` when
  /// `hasMore` is true and clear it otherwise — this avoids the trailing
  /// "fetched a final empty page" round-trip the client-side inference
  /// pattern was prone to.
  Future<PartiesPageDto> list({
    int limit = 20,
    String? cursor,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.customers,
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
        'Malformed customers page: missing or invalid `items` array',
      );
    }
    final items = rawItems
        .map((j) => PartyDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
    final hasMore = (data['hasMore'] as bool?) ?? false;
    final nextCursor = hasMore ? data['nextCursor'] as String? : null;
    return PartiesPageDto(items: items, nextCursor: nextCursor);
  }

  /// Single-row read for cold-start deep-links — used by the repo's drift
  /// fallback in `getPartyById`.
  Future<PartyDto> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.customerById(id),
    );
    return PartyDto.fromJson(_unwrapMap(response.data));
  }

  /// `POST /customers`. Body is the writable subset produced by
  /// `PartyDto.toJson()` — server assigns `id`, `createdAt`, etc.
  /// `customerType` is sent as a plain name string; the backend
  /// auto-upserts the corresponding `customer_types` row.
  Future<PartyDto> create(PartyDto draft) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.customers,
      data: draft.toJson(),
    );
    return PartyDto.fromJson(_unwrapMap(response.data));
  }

  /// `PATCH /customers/{id}`. Same writable shape as `create`; the
  /// server treats omitted fields as untouched and explicit `null` as a
  /// clear (per `CustomerUpdateBody` on the backend).
  Future<PartyDto> update(PartyDto party) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      Endpoints.customerById(party.id),
      data: party.toJson(),
    );
    return PartyDto.fromJson(_unwrapMap(response.data));
  }

  /// `GET /customers/{id}/images`. Returns the customer's gallery,
  /// ordered by `sortOrder` ascending. Used to hydrate the edit form's
  /// picker so the user sees existing images and can delete or replace
  /// them. Returns `[]` if the response shape is unexpected so the
  /// edit page can still render.
  Future<List<PartyImageRef>> listImages(String customerId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.customerImages(customerId),
    );
    final body = response.data;
    if (body == null || body['success'] == false) return const [];
    final data = body['data'];
    if (data is! List<dynamic>) return const [];
    return data
        .map((j) => PartyImageRef.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `POST /customers/{id}/images` — multipart `image` file + integer
  /// `imageNumber` form field. Slot-based upsert: re-posting the same
  /// slot replaces the existing image.
  ///
  /// Two non-obvious details:
  ///   * `imageNumber` is added **before** the file. Multer (the
  ///     backend's multipart parser) streams parts in order and
  ///     populates `req.body` text fields as it goes — having text
  ///     come after a file part can leave them unread on some
  ///     versions, even though Postman shrugs and works fine.
  ///   * The file's `Content-Type` is set explicitly from the
  ///     extension. Without it, `MultipartFile.fromFile` ships
  ///     `application/octet-stream`, Cloudinary refuses to treat the
  ///     blob as an image, and the backend wraps the failure as a
  ///     generic 500 — exactly what we hit on the first attempt.
  Future<void> uploadImage({
    required String customerId,
    required String filePath,
    required int imageNumber,
  }) async {
    final filename = filePath.split(RegExp(r'[\\/]')).last;
    // Stat the file before upload so a backend 500 we can't decode
    // (the server's catch-all wraps Multer/Cloudinary errors as
    // generic "Internal server error") still leaves a breadcrumb of
    // what we actually shipped. PrettyDioLogger doesn't surface part
    // sizes, so without this we'd be debugging blind.
    if (kDebugMode) {
      try {
        final bytes = await File(filePath).length();
        debugPrint(
          '[parties_api] uploadImage slot=$imageNumber '
          'file=$filename size=${bytes}B (${(bytes / 1024 / 1024).toStringAsFixed(2)} MB)',
        );
      } on FileSystemException {
        debugPrint(
          '[parties_api] uploadImage slot=$imageNumber file=$filename '
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
      Endpoints.customerImages(customerId),
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  /// Maps a filename's extension to a `Content-Type`. The backend only
  /// accepts JPEG and PNG; anything else falls back to
  /// `application/octet-stream` so the server's mime filter rejects it
  /// explicitly. Form-level validation in `isAllowedImageFile`
  /// (`shared/utils/image_validation.dart`) is meant to catch this
  /// earlier — this branch is a defence-in-depth safety net.
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

  /// `DELETE /customers/{id}/images/{imageNumber}` — removes a specific
  /// slot. No-op idempotency on 404 is up to the caller (we just
  /// propagate the error).
  Future<void> removeImage({
    required String customerId,
    required int imageNumber,
  }) async {
    await _dio.delete<Map<String, dynamic>>(
      Endpoints.customerImageSlot(customerId, imageNumber),
    );
  }

  /// `GET /customer-types`. Paginated like `/customers`, but the picker
  /// wants the full set in one go — fetch a single large page and flatten
  /// to a list of names. If `hasMore` is true at this limit the org has
  /// >100 customer types and we'll revisit (autocomplete with server-side
  /// search) before that's a real problem.
  Future<List<String>> partyTypes() async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.customerTypes,
      queryParameters: <String, dynamic>{'limit': _kCustomerTypesPageLimit},
    );
    final data = _unwrapMap(response.data);
    final rawItems = data['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException(
        'Malformed customer-types page: missing or invalid `items` array',
      );
    }
    return rawItems
        .map((j) => (j as Map<String, dynamic>)['name'] as String)
        .toList(growable: false);
  }

  // ── Envelope helper ───────────────────────────────────────────────────────
  // Mirrors `auth_api.dart:_unwrap`; promote to `lib/core/api/api_envelope.dart`
  // once a third caller appears.
  Map<String, dynamic> _unwrapMap(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty response body');
    }
    if (body['success'] == false) {
      throw const FormatException('Customers API returned success=false');
    }
    final inner = body['data'];
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed customers envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }
}

final partiesApiProvider = Provider<PartiesApi>(
  (ref) => PartiesApi(ref.watch(dioProvider)),
);
