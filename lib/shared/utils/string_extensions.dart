/// Common String helpers shared across features.
extension StringNullIfEmpty on String {
  /// Returns `null` when the string is empty, otherwise returns the string
  /// itself. Handy when packaging optional form-field values into a model
  /// where empty input should serialise as a missing field.
  String? nullIfEmpty() => isEmpty ? null : this;
}
