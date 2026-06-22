import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/orders/data/dto/estimate_dto.dart';
import 'package:sales_sphere_erp/features/orders/data/dto/invoice_dto.dart';
import 'package:sales_sphere_erp/features/orders/data/dto/org_print_profile_dto.dart';

/// HTTP layer for the orders feature. An "order" is a backend invoice and
/// an "estimate" is a backend estimate; this class wraps both plus the
/// org print-profile used for the document "From" block.
class OrdersApi {
  OrdersApi(this._dio);

  final Dio _dio;

  // ── Orders (invoices) ──────────────────────────────────────────────────

  Future<InvoicesPageDto> listInvoices({
    int limit = 100,
    String? cursor,
    String? search,
    String? fulfillmentStatus,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.invoices,
      queryParameters: <String, dynamic>{
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (search != null && search.isNotEmpty) 'search': search,
        if (fulfillmentStatus != null) 'fulfillmentStatus': fulfillmentStatus,
      },
    );
    final data = _unwrapMap(response.data);
    final items = _items(data)
        .map((j) => InvoiceDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
    return InvoicesPageDto(items: items, nextCursor: _nextCursor(data));
  }

  Future<InvoiceDto> getInvoice(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.invoiceById(id),
    );
    return InvoiceDto.fromJson(_unwrapMap(response.data));
  }

  /// `POST /invoices`. [body] is the mobile create payload (customerId,
  /// expectedDeliveryDate, overallDiscountPercent, taxRate, items with
  /// unitPrice/listPrice, clientRequestId). Returns the created order — or,
  /// on idempotent replay of the same `clientRequestId`, the original.
  Future<InvoiceDto> createInvoice(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.invoices,
      data: body,
    );
    return InvoiceDto.fromJson(_unwrapMap(response.data));
  }

  // ── Estimates ──────────────────────────────────────────────────────────

  Future<EstimatesPageDto> listEstimates({
    int limit = 100,
    String? cursor,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.estimates,
      queryParameters: <String, dynamic>{
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final data = _unwrapMap(response.data);
    final items = _items(data)
        .map((j) => EstimateDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
    return EstimatesPageDto(items: items, nextCursor: _nextCursor(data));
  }

  Future<EstimateDto> getEstimate(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.estimateById(id),
    );
    return EstimateDto.fromJson(_unwrapMap(response.data));
  }

  Future<EstimateDto> createEstimate(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.estimates,
      data: body,
    );
    return EstimateDto.fromJson(_unwrapMap(response.data));
  }

  Future<void> deleteEstimate(String id) async {
    await _dio.delete<dynamic>(Endpoints.estimateById(id));
  }

  /// `POST /estimates/{id}/convert`. Returns the (now ACCEPTED) estimate
  /// carrying `convertedInvoiceId`; the caller fetches that invoice to get
  /// the new order.
  Future<EstimateDto> convertEstimate(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.estimateConvert(id),
      data: body,
    );
    return EstimateDto.fromJson(_unwrapMap(response.data));
  }

  // ── Org print profile ──────────────────────────────────────────────────

  Future<OrgPrintProfileDto> getPrintProfile() async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.organizationsPrintProfile,
    );
    return OrgPrintProfileDto.fromJson(_unwrapMap(response.data));
  }

  // ── Envelope helpers ───────────────────────────────────────────────────

  List<dynamic> _items(Map<String, dynamic> data) {
    final raw = data['items'];
    if (raw is! List<dynamic>) {
      throw const FormatException(
        'Malformed orders page: missing or invalid `items` array',
      );
    }
    return raw;
  }

  String? _nextCursor(Map<String, dynamic> data) {
    final hasMore = (data['hasMore'] as bool?) ?? false;
    return hasMore ? data['nextCursor'] as String? : null;
  }

  Map<String, dynamic> _unwrapMap(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty response body');
    }
    if (body['success'] == false) {
      throw const FormatException('Orders API returned success=false');
    }
    final inner = body['data'];
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed orders envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }
}

final ordersApiProvider = Provider<OrdersApi>(
  (ref) => OrdersApi(ref.watch(dioProvider)),
);
