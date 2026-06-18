import 'package:flutter/foundation.dart';

import 'package:sales_sphere_erp/features/invoice/domain/invoice_line_item.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice_party.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice_totals.dart';
import 'package:sales_sphere_erp/features/invoice/domain/tax_option.dart';

/// Immutable snapshot of the invoice builder's working state. Held by
/// the `InvoiceDraft` notifier and rebuilt on every edit; the UI reads
/// the [InvoiceTotals] getters for the live pricing breakdown.
@immutable
class InvoiceDraftData with InvoiceTotals {
  const InvoiceDraftData({
    required this.tax,
    this.party,
    this.deliveryDate,
    this.items = const <InvoiceLineItem>[],
    this.overallDiscountPercent = 0,
  });

  /// A fresh, empty draft with [defaultTax] preselected.
  factory InvoiceDraftData.initial(TaxOption defaultTax) =>
      InvoiceDraftData(tax: defaultTax);

  final InvoiceParty? party;
  final DateTime? deliveryDate;
  @override
  final List<InvoiceLineItem> items;
  @override
  final double overallDiscountPercent;
  @override
  final TaxOption tax;

  bool get isEmpty => items.isEmpty;

  InvoiceDraftData copyWith({
    InvoiceParty? party,
    DateTime? deliveryDate,
    List<InvoiceLineItem>? items,
    double? overallDiscountPercent,
    TaxOption? tax,
    bool clearParty = false,
    bool clearDeliveryDate = false,
  }) {
    return InvoiceDraftData(
      party: clearParty ? null : (party ?? this.party),
      deliveryDate:
          clearDeliveryDate ? null : (deliveryDate ?? this.deliveryDate),
      items: items ?? this.items,
      overallDiscountPercent:
          overallDiscountPercent ?? this.overallDiscountPercent,
      tax: tax ?? this.tax,
    );
  }
}
