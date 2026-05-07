import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user_dto.freezed.dart';
part 'auth_user_dto.g.dart';

@freezed
abstract class AuthUserDto with _$AuthUserDto {
  const factory AuthUserDto({
    required String id,
    required String email,
    required String name,
    @Default(false) bool emailVerified,
    String? systemRole,
    DateTime? createdAt,
  }) = _AuthUserDto;

  factory AuthUserDto.fromJson(Map<String, dynamic> json) =>
      _$AuthUserDtoFromJson(json);
}
