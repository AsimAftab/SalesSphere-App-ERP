import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/data/dto/miscellaneous_work_dto.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/data/dto/miscellaneous_work_image_ref.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/data/miscellaneous_work_api.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/domain/miscellaneous_work.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/domain/miscellaneous_work_page.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/domain/repositories/miscellaneous_work_repository.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the
/// app. All DTO ↔ domain mapping happens here. Drift persistence +
/// outbox enqueue will land alongside a future drift table.
class MiscellaneousWorkRepositoryImpl implements MiscellaneousWorkRepository {
  MiscellaneousWorkRepositoryImpl({required MiscellaneousWorkApi api})
      : _api = api;

  final MiscellaneousWorkApi _api;

  @override
  Future<MiscellaneousWorkPage> getPage({
    int limit = 10,
    String? cursor,
  }) async {
    final pageDto = await _api.list(limit: limit, cursor: cursor);
    final items = pageDto.items.map(_toDomain).toList(growable: false);
    return MiscellaneousWorkPage(items: items, nextCursor: pageDto.nextCursor);
  }

  /// Creates the row via `POST /miscellaneous-work`, then best-effort
  /// uploads each attached local image to its 1-indexed slot. Image
  /// failures are collected and surfaced as
  /// [MiscellaneousWorkPartialImageUploadException] so the form can
  /// still navigate forward (the row exists) while telling the user
  /// which uploads didn't take.
  ///
  /// Hard failures on the create itself bubble as `DioException`.
  @override
  Future<MiscellaneousWork> addWork(MiscellaneousWork draft) async {
    final created = await _api.create(_toDto(draft));
    final domain = _toDomain(created);

    final failures = <int, String>{};
    for (var i = 0; i < draft.imagePaths.length; i++) {
      try {
        await _api.uploadImage(
          id: created.id,
          filePath: draft.imagePaths[i],
          imageNumber: i + 1,
        );
      } on DioException catch (e) {
        failures[i + 1] = extractBackendErrorMessage(e) ?? 'Upload failed';
      }
    }
    if (failures.isNotEmpty) {
      throw MiscellaneousWorkPartialImageUploadException(
        work: domain,
        failures: failures,
      );
    }
    return domain;
  }

  @override
  Future<MiscellaneousWork> updateWork(MiscellaneousWork work) async {
    final updated = await _api.update(work.id, _toDto(work));
    return _toDomain(updated);
  }

  @override
  Future<List<MiscellaneousWorkImageRef>> listImages(String id) =>
      _api.listImages(id);

  @override
  Future<MiscellaneousWorkImageRef> uploadImage({
    required String id,
    required String filePath,
    required int slot,
  }) =>
      _api.uploadImage(id: id, filePath: filePath, imageNumber: slot);

  @override
  Future<void> removeImage({required String id, required int slot}) =>
      _api.removeImage(id: id, imageNumber: slot);

  MiscellaneousWork _toDomain(MiscellaneousWorkDto dto) => MiscellaneousWork(
        id: dto.id,
        natureOfWork: dto.natureOfWork,
        assignedBy: dto.assignedBy,
        workDate: dto.workDate,
        address: dto.address,
        latitude: dto.latitude,
        longitude: dto.longitude,
        createdAt: dto.createdAt,
        imagePaths: dto.images,
      );

  MiscellaneousWorkDto _toDto(MiscellaneousWork w) => MiscellaneousWorkDto(
        id: w.id,
        natureOfWork: w.natureOfWork,
        assignedBy: w.assignedBy,
        workDate: w.workDate,
        address: w.address,
        latitude: w.latitude,
        longitude: w.longitude,
        createdAt: w.createdAt,
        images: w.imagePaths,
      );
}

/// Exposes the abstract type so consumers depend on the contract,
/// not the impl class. Tests override this provider with a fake
/// `MiscellaneousWorkRepository`.
final miscellaneousWorkRepositoryProvider =
    Provider<MiscellaneousWorkRepository>((ref) {
  return MiscellaneousWorkRepositoryImpl(
    api: ref.watch(miscellaneousWorkApiProvider),
  );
});
