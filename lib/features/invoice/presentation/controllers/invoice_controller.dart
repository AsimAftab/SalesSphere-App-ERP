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

  /// Removes a saved estimate from the in-memory history. Mock-only;
  /// gains a `repo.deleteInvoice(id)` call when a backend lands.
  void deleteEstimate(String id) =>
      ref.read(invoiceHistoryProvider.notifier).removeLocal(id);

  /// Converts an [estimate] into a committed invoice with the chosen
  /// [deliveryDate]. Stamps a fresh `INV-` number + id, prepends the new
  /// invoice to the history and drops the source estimate, then returns
  /// the created invoice. Mock-only.
  Future<Invoice> convertToInvoice(
    Invoice estimate,
    DateTime deliveryDate,
  ) async {
    final now = DateTime.now();
    final history = ref.read(invoiceHistoryProvider).value ?? const <Invoice>[];
    final number = _formatNumber(
      'INV',
      now.year,
      _nextSequence(history, InvoiceKind.invoice),
    );

    final invoice = Invoice(
      id: 'inv_${now.microsecondsSinceEpoch}',
      number: number,
      kind: InvoiceKind.invoice,
      status: InvoiceStatus.pending,
      party: estimate.party,
      deliveryDate: deliveryDate,
      items: List<InvoiceLineItem>.unmodifiable(estimate.items),
      overallDiscountPercent: estimate.overallDiscountPercent,
      tax: estimate.tax,
      createdAt: now,
    );

    ref.read(invoiceHistoryProvider.notifier)
      ..prependLocal(invoice)
      ..removeLocal(estimate.id);
    return invoice;
  }

  Future<Invoice> _create(InvoiceKind kind) async {
    final draft = ref.read(invoiceDraftProvider);
    final now = DateTime.now();
    final prefix = kind == InvoiceKind.invoice ? 'INV' : 'EST';
    final history = ref.read(invoiceHistoryProvider).value ?? const <Invoice>[];
    final number =
        _formatNumber(prefix, now.year, _nextSequence(history, kind));

    final invoice = Invoice(
      id: '${prefix.toLowerCase()}_${now.microsecondsSinceEpoch}',
      number: number,
      kind: kind,
      status: InvoiceStatus.pending,
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

  /// Formats a document number as `PREFIX-YEAR-NNNN`, e.g.
  /// `INV-2026-0001` / `EST-2026-0003`. The sequence is zero-padded to
  /// four digits.
  String _formatNumber(String prefix, int year, int sequence) =>
      '$prefix-$year-${sequence.toString().padLeft(4, '0')}';

  /// Next sequence number for [kind]: one past the highest existing
  /// trailing `-NNNN` segment (so it never collides with the seed
  /// numbers). Starts at 1 when there are none yet.
  int _nextSequence(List<Invoice> history, InvoiceKind kind) {
    var maxSeq = 0;
    for (final invoice in history) {
      if (invoice.kind != kind) continue;
      final seq = int.tryParse(invoice.number.split('-').last);
      if (seq != null && seq > maxSeq) maxSeq = seq;
    }
    return maxSeq + 1;
  }
}
