import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/auth/domain/usecases/change_password_usecase.dart';

part 'change_password_controller.freezed.dart';
part 'change_password_controller.g.dart';

/// Outcome of a change-password submission. The `message` is shown to the
/// user either way — the backend's confirmation on success, or the mapped
/// error copy on failure.
typedef ChangePasswordResult = ({bool ok, String message});

@freezed
abstract class ChangePasswordState with _$ChangePasswordState {
  const factory ChangePasswordState({
    @Default(true) bool obscureCurrent,
    @Default(true) bool obscureNew,
    @Default(true) bool obscureConfirm,
    @Default('') String newPassword,
    @Default(false) bool isLoading,
  }) = _ChangePasswordState;

  const ChangePasswordState._();

  bool get hasMinLength => newPassword.length >= 8;
  bool get hasUppercase => newPassword.contains(RegExp(r'[A-Z]'));
  bool get hasLowercase => newPassword.contains(RegExp(r'[a-z]'));
  bool get hasNumber => newPassword.contains(RegExp(r'[0-9]'));
  bool get hasSpecialChar => newPassword.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

  bool get isValid =>
      hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSpecialChar;
}

@riverpod
class ChangePasswordController extends _$ChangePasswordController {
  late ChangePasswordUseCase _changePassword;

  @override
  ChangePasswordState build() {
    _changePassword = ref.read(changePasswordUseCaseProvider);
    return const ChangePasswordState();
  }

  void toggleObscureCurrent() {
    state = state.copyWith(obscureCurrent: !state.obscureCurrent);
  }

  void toggleObscureNew() {
    state = state.copyWith(obscureNew: !state.obscureNew);
  }

  void toggleObscureConfirm() {
    state = state.copyWith(obscureConfirm: !state.obscureConfirm);
  }

  void setNewPassword(String password) {
    state = state.copyWith(newPassword: password);
  }

  /// Sends the change-password request. The page has already enforced the
  /// local requirement checks and the new/confirm match before calling this.
  /// Returns a [ChangePasswordResult] the page surfaces as a snackbar.
  Future<ChangePasswordResult> submit({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final message = await _changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      return (ok: true, message: message);
    } on ApiException catch (e) {
      return (ok: false, message: e.message);
    } catch (_) {
      return (ok: false, message: 'Something went wrong. Please try again.');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}
