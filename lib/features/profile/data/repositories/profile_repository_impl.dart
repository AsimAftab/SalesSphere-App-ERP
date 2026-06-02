import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sales_sphere_erp/features/profile/data/dto/profile_dto.dart';
import 'package:sales_sphere_erp/features/profile/data/profile_api.dart';
import 'package:sales_sphere_erp/features/profile/domain/entities/profile_entity.dart';
import 'package:sales_sphere_erp/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._api);

  final ProfileApi _api;

  @override
  Future<ProfileEntity> getProfile() async {
    final dto = await _api.me();
    return _mapToEntity(dto);
  }

  ProfileEntity _mapToEntity(ProfileResponseDto dto) {
    return ProfileEntity(
      user: ProfileUserEntity(
        id: dto.user.id,
        email: dto.user.email,
        name: dto.user.name,
        emailVerified: dto.user.emailVerified,
        systemRole: dto.user.systemRole,
        createdAt: dto.user.createdAt,
      ),
      activeMembership: dto.activeMembership != null
          ? _mapMembership(dto.activeMembership!)
          : null,
      memberships: dto.memberships.map(_mapMembership).toList(),
    );
  }

  ProfileMembershipEntity _mapMembership(ProfileMembershipDto dto) {
    return ProfileMembershipEntity(
      id: dto.id,
      status: dto.status,
      mobileLoginAllowed: dto.mobileLoginAllowed,
      role: ProfileRoleEntity(
        id: dto.role.id,
        name: dto.role.name,
        permissions: dto.role.permissions,
        isSystem: dto.role.isSystem,
      ),
      organization: ProfileOrganizationEntity(
        id: dto.organization.id,
        name: dto.organization.name,
        panNo: dto.organization.panNo,
        country: dto.organization.country,
        status: dto.organization.status,
        timezone: dto.organization.timezone,
        weeklyOffDays: dto.organization.weeklyOffDays,
        checkInTime: dto.organization.checkInTime,
        checkOutTime: dto.organization.checkOutTime,
        halfDayCheckOutTime: dto.organization.halfDayCheckOutTime,
        enableGeoFencingAttendance: dto.organization.enableGeoFencingAttendance,
        branches: dto.organization.branches.map((b) => ProfileBranchEntity(
          id: b.id,
          name: b.name,
          code: b.code,
          address: b.address,
          phone: b.phone,
          panNo: b.panNo,
          latitude: b.latitude,
          longitude: b.longitude,
          googleMapLink: b.googleMapLink,
          weeklyOffDays: b.weeklyOffDays,
          isHeadOffice: b.isHeadOffice,
          status: b.status,
        )).toList(),
      ),
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(profileApiProvider));
});
