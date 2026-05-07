import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';

/// UI-facing user model. Decoupled from wire DTOs and from the drift row
/// type, so backend renames and DB-schema tweaks don't ripple into widgets.
@freezed
abstract class AuthUser with _$AuthUser {
  const factory AuthUser({
    required String id,
    required String email,
    required String fullName,
    @Default(false) bool emailVerified,
    String? systemRole,
  }) = _AuthUser;
}
