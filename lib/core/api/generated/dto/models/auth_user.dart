// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';
part 'auth_user.g.dart';

@Freezed()
class AuthUser with _$AuthUser {
  const factory AuthUser({
    required String id,
    required String email,
    required String fullName,
    String? phone,
    String? organizationId,
    String? roleId,
    String? avatarUrl,
  }) = _AuthUser;
  
  factory AuthUser.fromJson(Map<String, Object?> json) => _$AuthUserFromJson(json);
}
