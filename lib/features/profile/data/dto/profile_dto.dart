import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_dto.freezed.dart';
part 'profile_dto.g.dart';

@freezed
abstract class ProfileResponseDto with _$ProfileResponseDto {
  const factory ProfileResponseDto({
    required ProfileUserDto user,
    ProfileMembershipDto? activeMembership,
    @Default([]) List<ProfileMembershipDto> memberships,
  }) = _ProfileResponseDto;

  factory ProfileResponseDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileResponseDtoFromJson(json);
}

@freezed
abstract class ProfileUserDto with _$ProfileUserDto {
  const factory ProfileUserDto({
    required String id,
    required String email,
    required String name,
    @Default(false) bool emailVerified,
    String? systemRole,
    DateTime? createdAt,
  }) = _ProfileUserDto;

  factory ProfileUserDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileUserDtoFromJson(json);
}

@freezed
abstract class ProfileMembershipDto with _$ProfileMembershipDto {
  const factory ProfileMembershipDto({
    required String id,
    required String status,
    required ProfileRoleDto role,
    required ProfileOrganizationDto organization,
    @Default(false) bool mobileLoginAllowed,
    // Personal details live on the membership (an employee profile is scoped
    // to an org), not on the shared `user`. The backend sends these inside
    // `activeMembership`; they were previously undeclared and silently dropped.
    String? address,
    String? phone,
    DateTime? dateOfBirth,
    String? gender,
    String? citizenshipNumber,
    String? panNumber,
    DateTime? dateJoined,
    String? avatarUrl,
    // The employee's assigned branch. Null branchId = org-wide membership
    // (e.g. OrgAdmin). `branch` is a slim summary — the backend sends
    // {id, name, isHeadOffice} today; `code` arrives with the pending
    // backend spec, hence nullable (unlike ProfileBranchDto.code).
    String? branchId,
    ProfileAssignedBranchDto? branch,
  }) = _ProfileMembershipDto;

  factory ProfileMembershipDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileMembershipDtoFromJson(json);
}

@freezed
abstract class ProfileAssignedBranchDto with _$ProfileAssignedBranchDto {
  const factory ProfileAssignedBranchDto({
    required String id,
    required String name,
    String? code,
    @Default(false) bool isHeadOffice,
  }) = _ProfileAssignedBranchDto;

  factory ProfileAssignedBranchDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileAssignedBranchDtoFromJson(json);
}

@freezed
abstract class ProfileRoleDto with _$ProfileRoleDto {
  const factory ProfileRoleDto({
    required String id,
    required String name,
    @Default([]) List<String> permissions,
    @Default(false) bool isSystem,
  }) = _ProfileRoleDto;

  factory ProfileRoleDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileRoleDtoFromJson(json);
}

@freezed
abstract class ProfileOrganizationDto with _$ProfileOrganizationDto {
  const factory ProfileOrganizationDto({
    required String id,
    required String name,
    required String country, required String status, required String timezone, String? panNo,
    @Default([]) List<String> weeklyOffDays,
    String? checkInTime,
    String? checkOutTime,
    String? halfDayCheckOutTime,
    @Default(false) bool enableGeoFencingAttendance,
    @Default([]) List<ProfileBranchDto> branches,
  }) = _ProfileOrganizationDto;

  factory ProfileOrganizationDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileOrganizationDtoFromJson(json);
}

@freezed
abstract class ProfileBranchDto with _$ProfileBranchDto {
  const factory ProfileBranchDto({
    required String id,
    required String name,
    required String code,
    required String status, String? address,
    String? phone,
    String? panNo,
    double? latitude,
    double? longitude,
    String? googleMapLink,
    @Default([]) List<String> weeklyOffDays,
    @Default(false) bool isHeadOffice,
  }) = _ProfileBranchDto;

  factory ProfileBranchDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileBranchDtoFromJson(json);
}
