import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/invoice/domain/invoice.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice_line_item.dart';
import 'package:sales_sphere_erp/features/invoice/presentation/providers/invoice_providers.dart';

part 'invoice_controller.g.dart';

/// Routes invoice / estimate create actions from the builder into the
/// in-memory store. Reads stay on [invoiceHistoryProvider].
///
/// Mock-only: there's no repository / network yet, so `_create` snapshots
/// the current draft, stamps an id + number + `createdAt`, prepends it to
/// the history list, then resets the draft. When a backend lands this
/// gains a repository dependency and the body becomes a
/// `repo.createInvoice(draft)` call.
@riverpod
class InvoiceController extends _$InvoiceController {
  @override
  void build() {}

  Future<Invoice> createInvoice() => _create(InvoiceKind.invoice);

  Future<Invoice> createEstimate() => _create(InvoiceKind.estimate);

  Future<Invoice> _create(InvoiceKind kind) async {
    final draft = ref.read(invoiceDraftProvider);
    final now = DateTime.now();
    final prefix = kind == InvoiceKind.invoice ? 'INV' : 'EST';
    final history = ref.read(invoiceHistoryProvider).value ?? const <Invoice>[];
    final number = '$prefix-${_nextSequence(history, kind, prefix)}';

    final invoice = Invoice(
      id: '${prefix.toLowerCase()}_${now.microsecondsSinceEpoch}',
      number: number,
      kind: kind,
      party: draft.party,
      deliveryDate: draft.deliveryDate,
      items: List<InvoiceLineItem>.unmodifiable(draft.items),
      overallDiscountPercent: draft.overallDiscountPercent,
      tax: draft.tax,
      createdAt: now,
    );

    ref.read(invoiceHistoryProvider.notifier).prependLocal(invoice);
    ref.read(invoiceDraftProvider.notifier).reset();
    return invoice;
  }

  /// Next document number for [kind]: one past the highest existing
  /// `PREFIX-<n>` suffix (so it never collides with the seed numbers).
  /// Falls back to 1001 when there are none yet.
  int _nextSequence(List<Invoice> history, InvoiceKind kind, String prefix) {
    var maxSuffix = 1000;
    for (final invoice in history) {
      if (invoice.kind != kind) continue;
      final suffix = int.tryParse(invoice.number.replaceFirst('$prefix-', ''));
      if (suffix != null && suffix > maxSuffix) maxSuffix = suffix;
    }
    return maxSuffix + 1;
  }
}
