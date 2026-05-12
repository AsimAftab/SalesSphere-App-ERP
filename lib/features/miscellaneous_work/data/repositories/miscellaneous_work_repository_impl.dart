import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/miscellaneous_work/data/dto/miscellaneous_work_dto.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/data/miscellaneous_work_api.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/domain/miscellaneous_work.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/domain/repositories/miscellaneous_work_repository.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the
/// app. All DTO ↔ domain mapping happens here. Drift persistence +
/// outbox enqueue will land alongside the real API.
class MiscellaneousWorkRepositoryImpl implements MiscellaneousWorkRepository {
  MiscellaneousWorkRepositoryImpl({required MiscellaneousWorkApi api})
      : _api = api;

  final MiscellaneousWorkApi _api;

  @override
  Future<List<MiscellaneousWork>> getAll() async {
    final dtos = await _api.list();
    return dtos.map(_toDomain).toList(growable: false);
  }

  @override
  Future<MiscellaneousWork> addWork(MiscellaneousWork draft) async {
    final created = await _api.create(_toDto(draft));
    return _toDomain(created);
  }

  @override
  Future<MiscellaneousWork> updateWork(MiscellaneousWork work) async {
    final updated = await _api.update(_toDto(work));
    return _toDomain(updated);
  }

  MiscellaneousWork _toDomain(MiscellaneousWorkDto dto) => MiscellaneousWork(
        id: dto.id,
        natureOfWork: dto.natureOfWork,
        assignedBy: dto.assignedBy,
        workDate: dto.workDate,
        address: dto.address,
        latitude: dto.latitude,
        longitude: dto.longitude,
        createdAt: dto.createdAt,
        imagePaths: dto.imagePaths,
      );

  MiscellaneousWorkDto _toDto(MiscellaneousWork w) => MiscellaneousWorkDto(
        // Server assigns the canonical id on create — placeholder here.
        id: w.id,
        natureOfWork: w.natureOfWork,
        assignedBy: w.assignedBy,
        workDate: w.workDate,
        address: w.address,
        latitude: w.latitude,
        longitude: w.longitude,
        createdAt: w.createdAt,
        imagePaths: w.imagePaths,
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
