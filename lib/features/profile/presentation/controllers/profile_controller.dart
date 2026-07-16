import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sales_sphere_erp/features/profile/domain/entities/profile_entity.dart';
import 'package:sales_sphere_erp/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:sales_sphere_erp/features/profile/domain/usecases/update_avatar_usecase.dart';

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

  /// Uploads a new avatar and patches the cached profile in place with the
  /// returned server URL — no full refetch, so the page never flashes back to
  /// its loading spinner. Rethrows on failure so the caller can surface it.
  Future<void> updateAvatar(String filePath) async {
    final newUrl =
        await ref.read(updateAvatarUseCaseProvider).call(filePath);
    final profile = state.value;
    final membership = profile?.activeMembership;
    if (profile == null || membership == null || newUrl == null) return;
    state = AsyncData(
      profile.copyWith(
        activeMembership: membership.copyWith(avatarUrl: newUrl),
        memberships: profile.memberships
            .map(
              (m) => m.id == membership.id ? m.copyWith(avatarUrl: newUrl) : m,
            )
            .toList(),
      ),
    );
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, ProfileEntity?>(
  ProfileController.new,
);
