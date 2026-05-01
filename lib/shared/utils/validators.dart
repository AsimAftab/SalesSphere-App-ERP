/// Reusable form-field validators.
///
/// Each method matches the `String? Function(String?)` signature used by
/// `TextFormField.validator` / `PrimaryTextField.validator`.
class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email required';
    if (!_emailRegex.hasMatch(v)) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) return 'Password required';
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    return null;
  }

  // Forgiving on input formatting (spaces, dashes, parentheses), but the
  // remaining digits-only payload must look like an E.164-ish number:
  // optional leading '+', then 7–15 digits.
  static final RegExp _phoneRegex = RegExp(r'^\+?\d{7,15}$');

  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Phone number required';
    final stripped = v.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!_phoneRegex.hasMatch(stripped)) {
      return 'Enter a valid phone number';
    }
    return null;
  }
}
