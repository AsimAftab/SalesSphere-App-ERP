import 'package:sales_sphere_erp/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileRepository {
  Future<ProfileEntity> getProfile();

  /// Uploads a new avatar image for the current user and returns the
  /// server-hosted URL of the stored image (null if the server omits it).
  Future<String?> updateAvatar(String filePath);
}
