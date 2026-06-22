import 'package:sales_sphere_erp/features/orders/domain/tax_option.dart';

/// Tax lines offered in the order builder's tax picker. The backend accepts
/// a single numeric document `taxRate`; the mobile app surfaces these two
/// choices and sends `tax.rate`. `No Tax` first so it is the default.
const kTaxOptions = <TaxOption>[
  TaxOption(id: 'none', label: 'No Tax', rate: 0),
  TaxOption(id: 'vat13', label: 'VAT 13%', rate: 13),
];

/// Preselected tax for a fresh draft.
const kDefaultTaxOption = TaxOption(id: 'none', label: 'No Tax', rate: 0);

/// Resolves a [TaxOption] from a server document `taxRate` (`null` / `0`
/// → No Tax). Matches a known option by rate when possible so the label
/// reads consistently; otherwise synthesises one.
TaxOption taxOptionForRate(double? rate) {
  final value = rate ?? 0;
  if (value <= 0) return kDefaultTaxOption;
  for (final option in kTaxOptions) {
    if (option.rate == value) return option;
  }
  final label = value == value.roundToDouble()
      ? 'VAT ${value.toInt()}%'
      : 'VAT $value%';
  return TaxOption(id: 'vat$value', label: label, rate: value);
}
