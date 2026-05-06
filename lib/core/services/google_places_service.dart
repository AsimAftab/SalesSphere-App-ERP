import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import 'package:sales_sphere_erp/core/config/env.dart';

/// One row in the autocomplete dropdown — `mainText` is the primary
/// label (e.g. "Thamel"), `secondaryText` is the contextual subtitle
/// (e.g. "Kathmandu, Nepal").
class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String mainText;
  final String secondaryText;

  /// Parses one entry from `suggestions[*].placePrediction` in the
  /// Places API (New) `:autocomplete` response. Returns `null` when
  /// the row is missing the placeId or structured-format payload.
  static PlacePrediction? fromJson(Map<String, dynamic> json) {
    final placeId = json['placeId'] as String?;
    if (placeId == null || placeId.isEmpty) return null;
    final structured = json['structuredFormat'] as Map<String, dynamic>?;
    final main = (structured?['mainText'] as Map<String, dynamic>?)?['text']
        as String?;
    if (main == null || main.isEmpty) return null;
    final secondary =
        (structured?['secondaryText'] as Map<String, dynamic>?)?['text']
            as String? ??
        '';
    return PlacePrediction(
      placeId: placeId,
      mainText: main,
      secondaryText: secondary,
    );
  }
}

/// Resolved place details — `name` is the short display name,
/// `formattedAddress` is the full postal-style address, `location` is
/// the canonical pin coordinates.
class PlaceDetails {
  const PlaceDetails({
    required this.name,
    required this.formattedAddress,
    required this.location,
  });

  final String name;
  final String formattedAddress;
  final LatLng location;

  /// Parses the top-level place body from `GET /v1/places/{id}`.
  /// Returns `null` if the response is missing coordinates.
  static PlaceDetails? fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>?;
    final lat = (loc?['latitude'] as num?)?.toDouble();
    final lng = (loc?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    final displayName =
        (json['displayName'] as Map<String, dynamic>?)?['text'] as String? ??
        '';
    final formatted = json['formattedAddress'] as String? ?? '';
    return PlaceDetails(
      name: displayName,
      formattedAddress: formatted,
      location: LatLng(lat, lng),
    );
  }
}

/// Thin client over the Places API (New). Uses a **separate** Dio
/// instance so the SalesSphere auth interceptor never attaches a JWT
/// to a Google call. All methods are best-effort: on any failure they
/// return `[]` / `null` so callers (the LocationPicker autocomplete
/// dropdown) degrade gracefully instead of surfacing errors to the
/// user.
class GooglePlacesService {
  GooglePlacesService({required String apiKey})
    : _apiKey = apiKey,
      _dio = Dio(
        BaseOptions(
          baseUrl: 'https://places.googleapis.com/v1',
          connectTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: <String, String>{'Content-Type': 'application/json'},
        ),
      );

  final String _apiKey;
  final Dio _dio;

  /// Autocomplete predictions for [query]. When [bias] is non-null,
  /// results are biased to a circle around that point of [radiusMeters].
  Future<List<PlacePrediction>> getAutocompletePredictions(
    String query, {
    LatLng? bias,
    double radiusMeters = 50000,
  }) async {
    if (_apiKey.isEmpty || query.trim().isEmpty) return const [];
    try {
      final body = <String, dynamic>{
        'input': query,
        if (bias != null)
          'locationBias': <String, dynamic>{
            'circle': <String, dynamic>{
              'center': <String, dynamic>{
                'latitude': bias.latitude,
                'longitude': bias.longitude,
              },
              'radius': radiusMeters,
            },
          },
      };
      final response = await _dio.post<Map<String, dynamic>>(
        '/places:autocomplete',
        data: body,
        options: Options(
          headers: <String, String>{
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask':
                'suggestions.placePrediction.placeId,'
                'suggestions.placePrediction.structuredFormat',
          },
        ),
      );
      final suggestions = response.data?['suggestions'] as List<dynamic>?;
      if (suggestions == null) return const [];
      return suggestions
          .whereType<Map<String, dynamic>>()
          .map((s) => s['placePrediction'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .map(PlacePrediction.fromJson)
          .whereType<PlacePrediction>()
          .toList(growable: false);
    } on Exception catch (_) {
      return const [];
    }
  }

  /// Resolves the canonical address + coordinates for a [placeId].
  /// Returns `null` on any failure (network, malformed response, etc).
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    if (_apiKey.isEmpty || placeId.isEmpty) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/places/$placeId',
        options: Options(
          headers: <String, String>{
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask': 'id,displayName,formattedAddress,location',
          },
        ),
      );
      final data = response.data;
      if (data == null) return null;
      return PlaceDetails.fromJson(data);
    } on Exception catch (_) {
      return null;
    }
  }
}

final googlePlacesServiceProvider = Provider<GooglePlacesService>((ref) {
  final service = GooglePlacesService(apiKey: Env.current.googlePlacesApiKey);
  return service;
});
