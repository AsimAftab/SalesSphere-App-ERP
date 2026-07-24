import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/collection/data/dto/collection_dto.dart';
import 'package:sales_sphere_erp/features/collection/data/dto/collection_page_dto.dart';

const int _kCollectionPageSize = 15;

/// HTTP layer for Collection Plus â€” receipts allocated across specific
/// invoices, oldest-first.
///
/// **ACCOUNTING plans only.** The permission keys `collection-plus:*` simply
/// don't exist in a CRM-only tenant's session, so every route here 403s for
/// them. That's the whole feature gate; the UI just hides the tile.
///
/// Speaks [CollectionDto], which extends the plain `CollectionDto` with the
/// three things only a ledger-backed receipt has: `status`, `voucherId` and
/// `allocations`. `/collections` returns none of them â€” sharing one DTO across
/// both endpoints is what made `status` a required field the server never sent.
class CollectionApi {
  CollectionApi(this._dio);

  final Dio _dio;

  /// `GET /collection-plus` â€” cursor-paginated, newest first.
  Future<CollectionPageDto> list({
    int limit = _kCollectionPageSize,
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
      Endpoints.collection,
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

  Future<CollectionDto> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.collectionById(id),
    );
    return CollectionDto.fromJson(_unwrapMap(response.data));
  }

  /// `POST /collection-plus`.
  ///
  /// Sends the **selected `invoiceIds`, never a split**. The server runs FIFO
  /// against live balances and returns the authoritative `allocations`. If the
  /// selection no longer covers the amount â€” because another rep collected
  /// against the same invoice while this one was offline â€” it refuses with a
  /// 422 rather than re-allocating.
  Future<CollectionDto> create(
    CollectionDto draft, {
    required List<String> invoiceIds,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.collection,
      data: draft.toCreateJson(invoiceIds: invoiceIds),
    );
    return CollectionDto.fromJson(_unwrapMap(response.data));
  }

  /// `PATCH /collection-plus/{id}` â€” DRAFT only.
  Future<CollectionDto> update(
    CollectionDto collection, {
    required List<String> invoiceIds,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      Endpoints.collectionById(collection.id),
      data: collection.toUpdateJson(invoiceIds: invoiceIds),
    );
    return CollectionDto.fromJson(_unwrapMap(response.data));
  }

  Future<void> delete(String id) async {
    await _dio.delete<void>(Endpoints.collectionById(id));
  }

  /// `PATCH /collection-plus/{id}/cheque-status`. Body key is `status`.
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

  /// `GET /collection-plus/parties/{partyId}/outstanding`.
  ///
  /// Returns the party's unsettled invoices **oldest-first, fully-paid rows
  /// already dropped** â€” the same order the server's FIFO uses, so the preview
  /// can consume it as-is.
  ///
  /// [excludeCollectionId] is **mandatory in edit mode.** It releases that
  /// receipt's own allocations back into the pool. Without it, the collection
  /// being edited is still holding down the very money it's about to
  /// re-allocate, and re-saving it unchanged fails validation every single
  /// time.
  ///
  /// Only POSTED invoices are collectible â€” a rep's order that's still DRAFT
  /// isn't a receivable yet and won't appear. An empty list means "nothing to
  /// settle", not a bug.
  ///
  /// [asOfDate] caps the read to what was actually due on that calendar date:
  /// the server drops invoices issued after it and ignores payments received
  /// after it. Pass the receipt's Received Date so a backdated collection sees
  /// the balances that existed then â€” a July-15 invoice must not appear in a
  /// July-10 receipt's picker, and a July-15 payment must not erase a balance
  /// the July-10 receipt is settling.
  Future<List<OutstandingInvoiceDto>> outstandingForParty({
    required String partyId,
    String? excludeCollectionId,
    DateTime? asOfDate,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.collectionOutstanding(partyId),
      queryParameters: <String, dynamic>{
        if (excludeCollectionId != null)
          'excludeCollectionId': excludeCollectionId,
        if (asOfDate != null) 'asOfDate': _dateToWire(asOfDate),
      },
    );
    return _outstandingFrom(_unwrapList(response.data));
  }

  /// `GET /collection-plus/invoice-meta?ids=a,b,c`.
  ///
  /// Hydrates the picker when editing: unlike the outstanding read, this keeps
  /// rows that are already fully paid, so an invoice this receipt settled
  /// still renders. Note `ids` is a **comma-joined string**, not repeated
  /// query params.
  Future<List<OutstandingInvoiceDto>> invoiceMeta({
    required List<String> invoiceIds,
    String? excludeCollectionId,
  }) async {
    if (invoiceIds.isEmpty) return const <OutstandingInvoiceDto>[];
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.collectionInvoiceMeta,
      queryParameters: <String, dynamic>{
        'ids': invoiceIds.join(','),
        if (excludeCollectionId != null)
          'excludeCollectionId': excludeCollectionId,
      },
    );
    return _outstandingFrom(_unwrapList(response.data));
  }

  /// Slot-based proof upload, 1â€“2. `imageNumber` streams before the file.
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

  Future<void> removeImage({
    required String collectionId,
    required int imageNumber,
  }) async {
    await _dio.delete<void>(
      Endpoints.collectionImageSlot(collectionId, imageNumber),
    );
  }

  /// `GET /collection-plus/bank-names` â€” same catalogue as `/collections`.
  Future<List<String>> bankNames() async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.collectionBankNames,
    );
    return _unwrapList(
      response.data,
    ).whereType<String>().toList(growable: false);
  }

  /// `GET /collection-plus/summary` â€” count + total for the targets module.
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

  // â”€â”€ Envelope helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  CollectionPageDto _pageFrom(Map<String, dynamic> data) {
    final rawItems = data['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException(
        'Malformed collection-plus page: missing or invalid `items` array',
      );
    }
    final items = rawItems
        .map((j) => CollectionDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
    final hasMore = (data['hasMore'] as bool?) ?? false;
    final nextCursor = hasMore ? data['nextCursor'] as String? : null;
    return CollectionPageDto(items: items, nextCursor: nextCursor);
  }

  List<OutstandingInvoiceDto> _outstandingFrom(List<dynamic> raw) => raw
      .whereType<Map<String, dynamic>>()
      .map(OutstandingInvoiceDto.fromJson)
      .toList(growable: false);

  Map<String, dynamic> _unwrapMap(Map<String, dynamic>? body) {
    final inner = _unwrapData(body);
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed collection-plus envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }

  List<dynamic> _unwrapList(Map<String, dynamic>? body) {
    final inner = _unwrapData(body);
    if (inner is! List<dynamic>) {
      throw const FormatException(
        'Malformed collection-plus envelope: missing or invalid `data` array',
      );
    }
    return inner;
  }

  Object? _unwrapData(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty collection-plus response body');
    }
    final success = body['success'];
    if (success is! bool || !success) {
      throw const FormatException(
        'Malformed collection-plus envelope: invalid `success` flag',
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
        return MediaType('application', 'octet-stream');
    }
  }

  static String _dateToWire(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final collectionApiProvider = Provider<CollectionApi>(
  (ref) => CollectionApi(ref.watch(dioProvider)),
);
class CollectionSummary {
  const CollectionSummary({required this.count, required this.totalAmount});
  final int count;
  final double totalAmount;
}
