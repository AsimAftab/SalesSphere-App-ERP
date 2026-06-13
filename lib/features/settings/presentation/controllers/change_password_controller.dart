import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'change_password_controller.freezed.dart';
part 'change_password_controller.g.dart';

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
  @override
  ChangePasswordState build() {
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

  Future<void> submit() async {
    state = state.copyWith(isLoading: true);
    // TODO: implement actual API call here
    await Future<void>.delayed(const Duration(seconds: 1));
    state = state.copyWith(isLoading: false);
  }
}
