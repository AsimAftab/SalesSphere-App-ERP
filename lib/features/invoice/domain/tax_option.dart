import 'package:flutter/foundation.dart';

/// A selectable tax line applied to the whole invoice. Mock-only: the
/// set of options is hard-coded (`No Tax`, `VAT 13%`); swap for a
/// settings/repository read when the backend exposes tax configuration.
///
/// Equality is by [id] so the picker can match the current selection
/// back to its list entry.
@immutable
class TaxOption {
  const TaxOption({
    required this.id,
    required this.label,
    required this.rate,
  });

  final String id;

  /// Display label shown in the tax picker, e.g. `VAT 13%`.
  final String label;

  /// Tax rate as a percentage, e.g. `13` for 13%. `0` means no tax.
  final double rate;

  @override
  bool operator ==(Object other) => other is TaxOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
