/// Formats a reading/distance: drops the `.0` on whole numbers, keeps one
/// decimal otherwise (readings are doubles on the wire, e.g. `15025.5`).
/// Returns `--` for null.
String formatReading(double? value) {
  if (value == null) return '--';
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}
