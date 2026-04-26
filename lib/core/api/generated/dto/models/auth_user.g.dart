// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthUser _$AuthUserFromJson(Map<String, dynamic> json) => _AuthUser(
  id: json['id'] as String,
  email: json['email'] as String,
  fullName: json['fullName'] as String,
  phone: json['phone'] as String?,
  organizationId: json['organizationId'] as String?,
  roleId: json['roleId'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
);

Map<String, dynamic> _$AuthUserToJson(_AuthUser instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'fullName': instance.fullName,
  'phone': instance.phone,
  'organizationId': instance.organizationId,
  'roleId': instance.roleId,
  'avatarUrl': instance.avatarUrl,
};
