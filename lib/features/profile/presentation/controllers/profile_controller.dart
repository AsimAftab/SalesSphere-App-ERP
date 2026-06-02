import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sales_sphere_erp/features/profile/domain/entities/profile_entity.dart';
import 'package:sales_sphere_erp/features/profile/domain/usecases/get_profile_usecase.dart';

class ProfileController extends AsyncNotifier<ProfileEntity?> {
  @override
  Future<ProfileEntity?> build() async {
    return _fetchProfile();
  }

  Future<ProfileEntity?> _fetchProfile() async {
    try {
      final getProfile = ref.read(getProfileUseCaseProvider);
      return await getProfile();
    } on Object catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<void> refreshProfile() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchProfile().then((v) => v!));
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, ProfileEntity?>(
  ProfileController.new,
);
