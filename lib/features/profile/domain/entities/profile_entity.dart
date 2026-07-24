import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_entity.freezed.dart';

@freezed
abstract class ProfileEntity with _$ProfileEntity {
  const factory ProfileEntity({
    required ProfileUserEntity user,
    ProfileMembershipEntity? activeMembership,
    @Default([]) List<ProfileMembershipEntity> memberships,
  }) = _ProfileEntity;
}

@freezed
abstract class ProfileUserEntity with _$ProfileUserEntity {
  const factory ProfileUserEntity({
    required String id,
    required String email,
    required String name,
    required bool emailVerified,
    String? systemRole,
    DateTime? createdAt,
  }) = _ProfileUserEntity;
}

@freezed
abstract class ProfileMembershipEntity with _$ProfileMembershipEntity {
  const factory ProfileMembershipEntity({
    required String id,
    required String status,
    required bool mobileLoginAllowed,
    required ProfileRoleEntity role,
    required ProfileOrganizationEntity organization,
    String? address,
    String? phone,
    DateTime? dateOfBirth,
    String? gender,
    String? citizenshipNumber,
    String? panNumber,
    DateTime? dateJoined,
    String? avatarUrl,
    // Assigned branch: null branchId = org-wide membership (e.g. OrgAdmin).
    String? branchId,
    ProfileAssignedBranchEntity? branch,
  }) = _ProfileMembershipEntity;
}

@freezed
abstract class ProfileAssignedBranchEntity with _$ProfileAssignedBranchEntity {
  const factory ProfileAssignedBranchEntity({
    required String id,
    required String name,
    required bool isHeadOffice, String? code,
  }) = _ProfileAssignedBranchEntity;
}

@freezed
abstract class ProfileRoleEntity with _$ProfileRoleEntity {
  const factory ProfileRoleEntity({
    required String id,
    required String name,
    required List<String> permissions,
    required bool isSystem,
  }) = _ProfileRoleEntity;
}

@freezed
abstract class ProfileOrganizationEntity with _$ProfileOrganizationEntity {
  const factory ProfileOrganizationEntity({
    required String id,
    required String name,
    required String country, required String status, required String timezone, required List<String> weeklyOffDays, required bool enableGeoFencingAttendance, required List<ProfileBranchEntity> branches, String? panNo,
    String? checkInTime,
    String? checkOutTime,
    String? halfDayCheckOutTime,
  }) = _ProfileOrganizationEntity;
}

@freezed
abstract class ProfileBranchEntity with _$ProfileBranchEntity {
  const factory ProfileBranchEntity({
    required String id,
    required String name,
    required String code,
    required List<String> weeklyOffDays, required bool isHeadOffice, required String status, String? address,
    String? phone,
    String? panNo,
    double? latitude,
    double? longitude,
    String? googleMapLink,
  }) = _ProfileBranchEntity;
}
