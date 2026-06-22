import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/catalog/data/dto/product_category_dto.dart';
import 'package:sales_sphere_erp/features/catalog/data/dto/product_dto.dart';

/// HTTP layer for the catalog feature. Reads the product + category
/// catalogues from the backend (`/products`, `/product-categories`). Both
/// are cursor-paginated; the repository pages through to the end so the UI
/// keeps its client-side search + category filter.
class CatalogApi {
  CatalogApi(this._dio);

  final Dio _dio;

  /// One page of `GET /products`. Defaults to ACTIVE products only;
  /// `categoryId` / `search` are server-side filters (the catalog page
  /// also filters locally, so callers may omit them and filter in Dart).
  Future<ProductsPageDto> listProducts({
    int limit = 100,
    String? cursor,
    String? categoryId,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.products,
      queryParameters: <String, dynamic>{
        'limit': limit,
        'status': 'ACTIVE',
        if (cursor != null) 'cursor': cursor,
        if (categoryId != null) 'categoryId': categoryId,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final data = _unwrapMap(response.data);
    final items = _items(data)
        .map((j) => ProductDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
    return ProductsPageDto(items: items, nextCursor: _nextCursor(data));
  }

  /// One page of `GET /product-categories` (ACTIVE only).
  Future<ProductCategoriesPageDto> listCategories({
    int limit = 100,
    String? cursor,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.productCategories,
      queryParameters: <String, dynamic>{
        'limit': limit,
        'status': 'ACTIVE',
        if (cursor != null) 'cursor': cursor,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final data = _unwrapMap(response.data);
    final items = _items(data)
        .map((j) => ProductCategoryDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
    return ProductCategoriesPageDto(items: items, nextCursor: _nextCursor(data));
  }

  List<dynamic> _items(Map<String, dynamic> data) {
    final raw = data['items'];
    if (raw is! List<dynamic>) {
      throw const FormatException(
        'Malformed catalog page: missing or invalid `items` array',
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
      throw const FormatException('Catalog API returned success=false');
    }
    final inner = body['data'];
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed catalog envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }
}

final catalogApiProvider = Provider<CatalogApi>(
  (ref) => CatalogApi(ref.watch(dioProvider)),
);
