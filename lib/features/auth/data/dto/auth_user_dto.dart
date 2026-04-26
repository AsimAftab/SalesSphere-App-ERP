import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user_dto.freezed.dart';
part 'auth_user_dto.g.dart';

@freezed
abstract class AuthUserDto with _$AuthUserDto {
  const factory AuthUserDto({
    required String id,
    required String email,
    required String fullName,
    String? phone,
    String? organizationId,
    String? roleId,
    String? avatarUrl,
  }) = _AuthUserDto;

  factory AuthUserDto.fromJson(Map<String, dynamic> json) =>
      _$AuthUserDtoFromJson(json);
}
