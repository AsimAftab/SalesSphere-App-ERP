import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sales_sphere_erp/features/profile/domain/entities/profile_entity.dart';
import 'package:sales_sphere_erp/features/profile/domain/repositories/profile_repository.dart';
import 'package:sales_sphere_erp/features/profile/data/repositories/profile_repository_impl.dart';

class GetProfileUseCase {
  GetProfileUseCase(this._repository);

  final ProfileRepository _repository;

  Future<ProfileEntity> call() => _repository.getProfile();
}

final getProfileUseCaseProvider = Provider<GetProfileUseCase>((ref) {
  return GetProfileUseCase(ref.watch(profileRepositoryProvider));
});
