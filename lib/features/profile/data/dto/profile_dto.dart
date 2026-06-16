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
  }) = _ProfileMembershipDto;

  factory ProfileMembershipDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileMembershipDtoFromJson(json);
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
    String? panNo,
    required String country,
    required String status,
    required String timezone,
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
    String? address,
    String? phone,
    String? panNo,
    double? latitude,
    double? longitude,
    String? googleMapLink,
    @Default([]) List<String> weeklyOffDays,
    @Default(false) bool isHeadOffice,
    required String status,
  }) = _ProfileBranchDto;

  factory ProfileBranchDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileBranchDtoFromJson(json);
}
