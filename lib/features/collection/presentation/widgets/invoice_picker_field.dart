import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/features/collection/domain/collection_invoice.dart';
import 'package:sales_sphere_erp/shared/widgets/party_picker.dart';

/// `Rs 98,000` style formatter for the invoice total shown in the
/// picker subtitle.
final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

/// Invoice selection field built on the shared [PartyPickerField] — the
/// same searchable bottom-sheet the party picker uses, so they read as
/// the same family. Lists the posted invoices a collection can be booked
/// against (title = document number, subtitle = party · total).
///
/// The picker carries no `validator`, so required-ness is enforced by
/// the form on submit (the add/edit pages guard on a null invoice).
class InvoicePickerField extends StatelessWidget {
  const InvoicePickerField({
    required this.value,
    required this.onChanged,
    required this.invoices,
    this.enabled = true,
    super.key,
  });

  final CollectionInvoice? value;
  final ValueChanged<CollectionInvoice?> onChanged;
  final List<CollectionInvoice> invoices;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return PartyPickerField<CollectionInvoice>(
      value: value,
      onChanged: onChanged,
      items: invoices,
      enabled: enabled,
      titleOf: (i) => i.number,
      subtitleOf: (i) => i.partyName.isEmpty
          ? _currency.format(i.amount)
          : '${i.partyName} · ${_currency.format(i.amount)}',
      searchTextOf: (i) => '${i.number} ${i.partyName}',
      label: 'Invoice',
      hintText: 'Select the invoice being settled',
      prefixIcon: Icons.receipt_long_outlined,
      rowIcon: Icons.receipt_long_outlined,
      sheetTitle: 'Select invoice',
      searchHint: 'Search invoices',
      emptyText: 'No posted invoices found.',
      noMatchText: 'No invoices match your search.',
    );
  }
}
