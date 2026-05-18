import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/prospects/data/dto/prospect_dto.dart';
import 'package:sales_sphere_erp/features/prospects/data/dto/prospect_image_ref.dart';
import 'package:sales_sphere_erp/features/prospects/data/prospects_api.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect_conversion_result.dart';
import 'package:sales_sphere_erp/features/prospects/domain/repositories/prospects_repository.dart';
import 'package:sales_sphere_erp/shared/domain/interest.dart';
import 'package:sales_sphere_erp/shared/domain/interest_catalogue.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the app.
/// All DTO ↔ domain mapping happens here. Prospects is purely
/// network-backed today — drift + outbox parity with parties is future
/// work, so failures bubble up to the form rather than queueing.
class ProspectsRepositoryImpl implements ProspectsRepository {
  ProspectsRepositoryImpl({required ProspectsApi api}) : _api = api;

  final ProspectsApi _api;

  @override
  Future<List<Prospect>> getProspects() async {
    final dtos = await _api.list();
    return dtos.map(_toDomain).toList(growable: false);
  }

  @override
  Future<Prospect?> getProspectById(String id) async {
    try {
      final dto = await _api.getById(id);
      return _toDomain(dto);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Prospect> addProspect(Prospect draft) async {
    final created = await _api.create(_toDto(draft));
    final domain = _toDomain(created);
    // Best-effort image upload: each local file goes to slot i+1.
    // Failures are collected with the backend's actual error message
    // so the form can show a useful snackbar instead of just a count.
    final failures = <int, String>{};
    for (var i = 0; i < draft.imagePaths.length; i++) {
      try {
        await _api.uploadImage(
          prospectId: created.id,
          filePath: draft.imagePaths[i],
          imageNumber: i + 1,
        );
      } on DioException catch (e) {
        failures[i + 1] = extractBackendErrorMessage(e) ?? 'Upload failed';
      }
    }
    if (failures.isNotEmpty) {
      throw ProspectPartialImageUploadException(
        prospect: domain,
        failures: failures,
      );
    }
    return domain;
  }

  @override
  Future<Prospect> updateProspect(Prospect prospect) async {
    final updated = await _api.update(_toDto(prospect));
    return _toDomain(updated);
  }

  @override
  Future<InterestCatalogue> getInterestCatalogue() async {
    final raw = await _api.interestCatalogue();
    return InterestCatalogue.fromMap(raw);
  }

  @override
  Future<void> addInterestCategory(String category) =>
      _api.addInterestCategory(category);

  @override
  Future<void> addInterestBrand(String category, String brand) =>
      _api.addInterestBrand(category, brand);

  @override
  Future<List<ProspectImageRef>> listImages(String prospectId) =>
      _api.listImages(prospectId);

  @override
  Future<void> uploadImage({
    required String prospectId,
    required String filePath,
    required int slot,
  }) =>
      _api.uploadImage(
        prospectId: prospectId,
        filePath: filePath,
        imageNumber: slot,
      );

  @override
  Future<void> removeImage({
    required String prospectId,
    required int slot,
  }) =>
      _api.removeImage(prospectId: prospectId, imageNumber: slot);

  @override
  Future<ProspectConversionResult> convertToParty({
    required String prospectId,
    bool keepImages = true,
  }) =>
      _api.convertToParty(prospectId: prospectId, keepImages: keepImages);

  Prospect _toDomain(ProspectDto dto) => Prospect(
        id: dto.id,
        name: dto.name,
        // DTOs stay nullable for wire compatibility; the domain marks
        // address + owner + phone non-null because the form's validators
        // require them. Records without these surface as empty strings
        // and the form forces the user to fill them on save.
        address: dto.address ?? '',
        ownerName: dto.ownerName ?? '',
        phone: dto.phone ?? '',
        panVat: dto.panVat,
        email: dto.email,
        dateJoined: dto.dateJoined,
        interests: dto.interests
            .where((i) => i.brand.isNotEmpty)
            .map((i) => Interest(category: i.category, brand: i.brand))
            .toList(growable: false),
        notes: dto.notes,
        latitude: dto.latitude,
        longitude: dto.longitude,
        imagePaths: dto.imagePaths,
      );

  ProspectDto _toDto(Prospect p) => ProspectDto(
        id: p.id,
        name: p.name,
        address: p.address,
        ownerName: p.ownerName,
        panVat: p.panVat,
        phone: p.phone,
        email: p.email,
        dateJoined: p.dateJoined,
        interests: p.interests
            .map((i) =>
                ProspectInterestDto(category: i.category, brand: i.brand))
            .toList(growable: false),
        notes: p.notes,
        latitude: p.latitude,
        longitude: p.longitude,
        imagePaths: p.imagePaths,
      );
}

/// Exposes the abstract type so consumers depend on the contract, not the
/// impl class. Tests override this provider with a fake `ProspectsRepository`.
final prospectsRepositoryProvider = Provider<ProspectsRepository>((ref) {
  return ProspectsRepositoryImpl(api: ref.watch(prospectsApiProvider));
});
