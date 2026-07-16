import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sales_sphere_erp/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:sales_sphere_erp/features/profile/domain/repositories/profile_repository.dart';

class UpdateAvatarUseCase {
  UpdateAvatarUseCase(this._repository);

  final ProfileRepository _repository;

  /// Uploads the picked image and returns the new server avatar URL.
  Future<String?> call(String filePath) => _repository.updateAvatar(filePath);
}

final updateAvatarUseCaseProvider = Provider<UpdateAvatarUseCase>((ref) {
  return UpdateAvatarUseCase(ref.watch(profileRepositoryProvider));
});
