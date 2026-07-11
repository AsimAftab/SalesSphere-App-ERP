import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/collection/data/dto/collection_dto.dart';
import 'package:sales_sphere_erp/features/collection/data/dto/collections_page_dto.dart';

/// Infinite-scroll page size. The backend caps `limit` at 200 and defaults
/// to 50; the bank catalogue is a small reference list fetched in one go.
const int _kCollectionsPageSize = 15;

/// HTTP layer for the Collection feature (on-account receipts — available on
/// every plan, including CRM-only orgs with no ledger).
///
/// Three contract details that bite if you miss them:
///
///  * **Every GET query is `.strict()` server-side.** One unknown param — a
///    stray `page`, `offset`, `sort` — is a hard 422, not a silent ignore.
///    Only send what the schema declares.
///  * **`POST` is idempotent on `clientRequestId`** (a v4 UUID from the
///    outbox). A replay of a key the server has seen returns **200 with the
///    original row**, not a duplicate and not a 409. 201 means newly created.
///  * **`imageNumber` must be streamed before the file part** — Multer fills
///    `req.body` as it reads, and a text field after the file can be missed.
class CollectionApi {
  CollectionApi(this._dio);

  final Dio _dio;

  /// `GET /collections` — cursor-paginated, newest first.
  ///
  /// [excludePaymentMode] is what powers the two list tabs: "My Collections"
  /// passes `CHEQUE` to exclude cheques, and the PDC tab passes
  /// `paymentMode: CHEQUE` to select only them. Both are server-side, so the
  /// tabs no longer filter a fully-loaded list in Dart.
  ///
  /// [createdById] takes a **user id**, and the row renders `createdBy.name`.
  /// [fromDate] / [toDate] filter on `createdAt` (the UI labels read
  /// "Created From / To"), *not* on the received date.
  Future<CollectionsPageDto> list({
    int limit = _kCollectionsPageSize,
    String? cursor,
    String? search,
    String? paymentMode,
    String? excludePaymentMode,
    String? chequeStatus,
    String? status,
    String? createdById,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.collections,
      queryParameters: <String, dynamic>{
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (search != null && search.isNotEmpty) 'search': search,
        if (paymentMode != null) 'paymentMode': paymentMode,
        if (excludePaymentMode != null)
          'excludePaymentMode': excludePaymentMode,
        if (chequeStatus != null) 'chequeStatus': chequeStatus,
        if (status != null) 'status': status,
        if (createdById != null) 'createdById': createdById,
        if (fromDate != null) 'fromDate': _dateToWire(fromDate),
        if (toDate != null) 'toDate': _dateToWire(toDate),
      },
    );
    return _pageFrom(_unwrapMap(response.data));
  }

  /// `GET /collections/{id}` — single-row read for cold-start deep-links.
  Future<CollectionDto> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.collectionById(id),
    );
    return CollectionDto.fromJson(_unwrapMap(response.data));
  }

  /// `POST /collections`. Lands `DRAFT` — nothing reaches the ledger until an
  /// accountant posts it. Returns the created row (201) or, on an idempotent
  /// replay of the same `clientRequestId`, the original row (200). Both bodies
  /// are the full DTO, so callers don't need to distinguish.
  Future<CollectionDto> create(CollectionDto draft) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.collections,
      data: draft.toCreateJson(),
    );
    return CollectionDto.fromJson(_unwrapMap(response.data));
  }

  /// `PATCH /collections/{id}` — DRAFT only; the server 409s once POSTED or
  /// CANCELLED. The party is immutable and is not sent.
  Future<CollectionDto> update(CollectionDto collection) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      Endpoints.collectionById(collection.id),
      data: collection.toUpdateJson(),
    );
    return CollectionDto.fromJson(_unwrapMap(response.data));
  }

  /// `DELETE /collections/{id}` — DRAFT only (409 otherwise; a posted receipt
  /// must be cancelled, which writes a reversal voucher). 204, empty body.
  Future<void> delete(String id) async {
    await _dio.delete<void>(Endpoints.collectionById(id));
  }

  /// `PATCH /collections/{id}/cheque-status`.
  ///
  /// The body key is **`status`**, not `chequeStatus`, and the schema is
  /// strict. Legal moves: `PENDING → DEPOSITED | CLEARED | BOUNCED`,
  /// `DEPOSITED → CLEARED | BOUNCED`. `CLEARED` and `BOUNCED` are terminal;
  /// anything else is a 409.
  Future<CollectionDto> updateChequeStatus({
    required String id,
    required String status,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      Endpoints.collectionChequeStatus(id),
      data: <String, dynamic>{'status': status},
    );
    return CollectionDto.fromJson(_unwrapMap(response.data));
  }

  /// `POST /collections/{id}/images` — slot-based upsert, slots 1–2. Posting
  /// an occupied slot replaces it (the old Cloudinary blob is destroyed).
  ///
  /// The response body is the raw image row (a 0-indexed `sortOrder` shape
  /// that differs from the `images[]` embedded in the collection), so we
  /// ignore it — callers refetch the collection to get the canonical list.
  ///
  /// Two non-obvious details, same as the notes / expenses / parties uploads:
  ///   * `imageNumber` is streamed **before** the file part.
  ///   * `Content-Type` is set explicitly from the extension. Without it
  ///     `MultipartFile.fromFile` ships `application/octet-stream`, Cloudinary
  ///     refuses the blob, and the failure surfaces as a generic 500.
  Future<void> uploadImage({
    required String collectionId,
    required String filePath,
    required int imageNumber,
  }) async {
    final filename = filePath.split(RegExp(r'[\\/]')).last;
    final form = FormData.fromMap(<String, dynamic>{
      'imageNumber': imageNumber.toString(),
      'image': await MultipartFile.fromFile(
        filePath,
        filename: filename,
        contentType: _mediaTypeForFilename(filename),
      ),
    });
    await _dio.post<Map<String, dynamic>>(
      Endpoints.collectionImages(collectionId),
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  /// `DELETE /collections/{id}/images/{imageNumber}` — 204, empty body.
  Future<void> removeImage({
    required String collectionId,
    required int imageNumber,
  }) async {
    await _dio.delete<void>(
      Endpoints.collectionImageSlot(collectionId, imageNumber),
    );
  }

  /// `GET /collections/bank-names` — the bank catalogue.
  ///
  /// A **suggestion list, not an enum**: `bankName` is free text on write, and
  /// the picker offers an "add a different bank" escape hatch. Unlike the
  /// other reference lists this returns a bare array, not a paginated page.
  Future<List<String>> bankNames() async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.collectionBankNames,
    );
    return _unwrapList(response.data)
        .whereType<String>()
        .toList(growable: false);
  }

  /// `GET /collections/summary` — count + total for the targets module.
  ///
  /// Note the param is **`employeeId`**, not `createdById`, and its
  /// `fromDate`/`toDate` filter the *received* date — unlike the list query,
  /// whose identically-named params filter `createdAt`. The schema is strict,
  /// so don't send a `branchId`.
  Future<CollectionSummary> summary({
    String? employeeId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.collectionSummary,
      queryParameters: <String, dynamic>{
        if (employeeId != null) 'employeeId': employeeId,
        if (fromDate != null) 'fromDate': _dateToWire(fromDate),
        if (toDate != null) 'toDate': _dateToWire(toDate),
      },
    );
    final data = _unwrapMap(response.data);
    return CollectionSummary(
      count: (data['count'] as num?)?.toInt() ?? 0,
      totalAmount: double.tryParse('${data['totalAmount'] ?? 0}') ?? 0,
    );
  }

  // ── Envelope helpers ──────────────────────────────────────────────────────
  // Mirrors `expenses_api.dart`. Duplicated per-feature by house convention
  // so the FormatException copy names the feature that failed.

  CollectionsPageDto _pageFrom(Map<String, dynamic> data) {
    final rawItems = data['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException(
        'Malformed collections page: missing or invalid `items` array',
      );
    }
    final items = rawItems
        .map((j) => CollectionDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
    final hasMore = (data['hasMore'] as bool?) ?? false;
    final nextCursor = hasMore ? data['nextCursor'] as String? : null;
    return CollectionsPageDto(items: items, nextCursor: nextCursor);
  }

  Map<String, dynamic> _unwrapMap(Map<String, dynamic>? body) {
    final inner = _unwrapData(body);
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed collections envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }

  List<dynamic> _unwrapList(Map<String, dynamic>? body) {
    final inner = _unwrapData(body);
    if (inner is! List<dynamic>) {
      throw const FormatException(
        'Malformed collections envelope: missing or invalid `data` array',
      );
    }
    return inner;
  }

  Object? _unwrapData(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty collections response body');
    }
    // Require `success` to be explicitly `true`. A missing / null / non-bool
    // flag must NOT slip past — that's a malformed envelope.
    final success = body['success'];
    if (success is! bool || !success) {
      throw const FormatException(
        'Malformed collections envelope: invalid `success` flag',
      );
    }
    return body['data'];
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
        // The server only accepts JPEG / PNG — let its mime filter reject
        // anything else explicitly (415) rather than guessing here.
        return MediaType('application', 'octet-stream');
    }
  }

  static String _dateToWire(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// `{ count, totalAmount }` from `/collections/summary`. Feeds the targets
/// module's "No. of collections" / "Value of collections" rules.
///
/// A collection counts at **creation** — a DRAFT is included. The rep
/// physically collected the money; whether an accountant has posted it yet
/// isn't something they control. CANCELLED and BOUNCED are excluded.
class CollectionSummary {
  const CollectionSummary({required this.count, required this.totalAmount});

  final int count;
  final double totalAmount;
}

final collectionApiProvider = Provider<CollectionApi>(
  (ref) => CollectionApi(ref.watch(dioProvider)),
);
