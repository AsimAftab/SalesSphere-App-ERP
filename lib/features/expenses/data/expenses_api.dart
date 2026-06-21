import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/expenses/data/dto/expense_claim_dto.dart';
import 'package:sales_sphere_erp/features/expenses/data/dto/expense_claim_image_ref.dart';
import 'package:sales_sphere_erp/features/expenses/data/dto/expense_claims_page_dto.dart';

/// `my-requests` is an infinite-scroll list — fetch a page at a time and
/// follow `nextCursor`. The category catalogue is a small reference list,
/// so fetch it in one large page (200 is the backend's max).
const int _kExpenseClaimsPageSize = 15;
const int _kExpenseCategoriesPageLimit = 200;

/// HTTP layer for the expense-claims feature. Every call hits the live
/// backend; the `{success, data}` transport envelope is peeled by
/// [_unwrapMap]. List + categories nest their rows one level deeper under
/// `data.items` (the cursor-pagination envelope). Receipt uploads reuse
/// the slot-based `/notes/{id}/images` machinery verbatim.
class ExpensesApi {
  ExpensesApi(this._dio);

  final Dio _dio;

  /// Fetch one paginated page of the signed-in rep's own claims from
  /// `GET /expense-claims/my-requests`, newest first.
  ///
  /// The server is authoritative on pagination + filtering: the inner
  /// envelope carries `items`, `hasMore`, and `nextCursor`. We trust
  /// `nextCursor` when `hasMore` is true and clear it otherwise.
  /// [status] is the wire enum string (`PENDING | APPROVED | REJECTED`);
  /// [search] narrows by title / category server-side.
  Future<ExpenseClaimsPageDto> listMine({
    int limit = _kExpenseClaimsPageSize,
    String? cursor,
    String? status,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.expenseClaimsMyRequests,
      queryParameters: <String, dynamic>{
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (status != null) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final data = _unwrapMap(response.data);
    final rawItems = data['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException(
        'Malformed expense-claims page: missing or invalid `items` array',
      );
    }
    final items = rawItems
        .map((j) => ExpenseClaimDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
    final hasMore = (data['hasMore'] as bool?) ?? false;
    final nextCursor = hasMore ? data['nextCursor'] as String? : null;
    return ExpenseClaimsPageDto(items: items, nextCursor: nextCursor);
  }

  /// `POST /expense-claims`. Body is the writable subset produced by
  /// `ExpenseClaimDto.toJson()` — the server assigns `id`, `createdAt`,
  /// the employee id, and forces `status` to `PENDING`. Returns the
  /// created row (201).
  Future<ExpenseClaimDto> create(ExpenseClaimDto draft) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.expenseClaims,
      data: draft.toJson(),
    );
    return ExpenseClaimDto.fromJson(_unwrapMap(response.data));
  }

  /// `PATCH /expense-claims/{id}` — partial update; only allowed while
  /// PENDING (the server 4xxes once APPROVED / REJECTED).
  Future<ExpenseClaimDto> update(ExpenseClaimDto claim) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      Endpoints.expenseClaimById(claim.id),
      data: claim.toJson(),
    );
    return ExpenseClaimDto.fromJson(_unwrapMap(response.data));
  }

  /// `GET /expense-claims/{id}/images`. Returns the claim's receipts,
  /// ordered by slot. Returns `[]` if the response shape is unexpected so
  /// the edit page can still render.
  Future<List<ExpenseClaimImageRef>> listImages(String claimId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.expenseClaimImages(claimId),
    );
    final body = response.data;
    if (body == null || body['success'] == false) return const [];
    final data = body['data'];
    if (data is! List<dynamic>) return const [];
    return data
        .map((j) => ExpenseClaimImageRef.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `POST /expense-claims/{id}/images` — multipart `image` file +
  /// `imageNumber` form field. Slot-based upsert (max 2): re-posting the
  /// same slot replaces the existing receipt.
  ///
  /// Same two non-obvious details as the notes / parties variants:
  ///   * `imageNumber` is streamed **before** the file part — Multer
  ///     populates `req.body` text fields as it reads, and text after a
  ///     file part can be left unread.
  ///   * The file's `Content-Type` is set explicitly from the extension.
  ///     Without it `MultipartFile.fromFile` ships
  ///     `application/octet-stream`, Cloudinary refuses the blob, and the
  ///     backend wraps the failure as a generic 500.
  Future<ExpenseClaimImageRef> uploadImage({
    required String claimId,
    required String filePath,
    required int imageNumber,
  }) async {
    final filename = filePath.split(RegExp(r'[\\/]')).last;
    if (kDebugMode) {
      try {
        final bytes = await File(filePath).length();
        debugPrint(
          '[expenses_api] uploadImage slot=$imageNumber '
          'file=$filename size=${bytes}B '
          '(${(bytes / 1024 / 1024).toStringAsFixed(2)} MB)',
        );
      } on FileSystemException {
        debugPrint(
          '[expenses_api] uploadImage slot=$imageNumber file=$filename '
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
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.expenseClaimImages(claimId),
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return ExpenseClaimImageRef.fromJson(_unwrapMap(response.data));
  }

  /// `DELETE /expense-claims/{id}/images/{slot}` — removes a specific
  /// slot. No-op idempotency on 404 is up to the caller.
  Future<void> removeImage({
    required String claimId,
    required int imageNumber,
  }) async {
    await _dio.delete<Map<String, dynamic>>(
      Endpoints.expenseClaimImageSlot(claimId, imageNumber),
    );
  }

  /// `GET /expense-claim-categories`. Paginated like the rest, but the
  /// picker wants the full set in one go — fetch a single large page and
  /// flatten to a list of names. Mirrors `parties_api.partyTypes()`.
  Future<List<String>> categories() async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.expenseClaimCategories,
      queryParameters: <String, dynamic>{
        'limit': _kExpenseCategoriesPageLimit,
      },
    );
    final data = _unwrapMap(response.data);
    final rawItems = data['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException(
        'Malformed expense-claim-categories page: missing or invalid `items` '
        'array',
      );
    }
    return rawItems
        .map((j) => (j as Map<String, dynamic>)['name'] as String)
        .toList(growable: false);
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

  Map<String, dynamic> _unwrapMap(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty expense-claims response body');
    }
    // Require `success` to be explicitly `true`. A missing / null / non-bool
    // flag must NOT slip past — that's a malformed envelope.
    final success = body['success'];
    if (success is! bool || !success) {
      throw const FormatException(
        'Malformed expense-claims envelope: invalid `success` flag',
      );
    }
    final inner = body['data'];
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed expense-claims envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }
}

final expensesApiProvider = Provider<ExpensesApi>(
  (ref) => ExpensesApi(ref.watch(dioProvider)),
);
