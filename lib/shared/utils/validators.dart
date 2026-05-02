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

  /// Required-text validator. Returns `"$label is required"` when the
  /// trimmed value is empty, otherwise null.
  static String? requiredField(String? value, String label) {
    return (value?.trim().isEmpty ?? true) ? '$label is required' : null;
  }

  /// Exactly 10 digits — Nepal mobile-number format used on the parties
  /// add/edit forms.
  static String? phone10(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Phone number is required';
    if (v.length != 10) return 'Phone number must be 10 digits';
    return null;
  }

  /// Exactly 9 digits — PAN/VAT number format used on the parties
  /// add/edit forms.
  static String? panVat(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'PAN/VAT number is required';
    if (v.length != 9) return 'PAN/VAT number must be 9 digits';
    return null;
  }

  /// Email validator that only runs the format check when the field has
  /// content. Use this when the email is optional but still has to look
  /// valid when filled.
  static String? emailOptional(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return email(value);
  }
}
