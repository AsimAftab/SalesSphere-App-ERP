import 'package:flutter/foundation.dart';

/// A posted invoice a collection can be recorded against. In v2 mobile
/// the old "invoice" feature was renamed to **orders**, so a confirmed
/// order (`kind: order`) is the posted invoice the accounting side
/// credits — this slim reference is projected from those orders so the
/// collection layer doesn't depend on the full orders domain.
///
/// [id] mirrors the source order's id (the linkage accounting uses to
/// credit the exact invoice); [number] is the human-facing document
/// number (e.g. `ORD-2026-0002`); [amount] is the invoice grand total
/// shown in the outstanding-invoices list; [invoiceDate] is the order's
/// delivery/posting date and drives the oldest-first allocation order.
///
/// Equality is by [id] so a stored selection can be matched back to its
/// list entry inside the picker regardless of instance identity.
@immutable
class CollectionInvoice {
  const CollectionInvoice({
    required this.id,
    required this.number,
    required this.amount,
    required this.invoiceDate,
    this.partyId,
    this.partyName = '',
  });

  final String id;
  final String number;
  final double amount;

  /// When the invoice was posted (the order's delivery date, falling back
  /// to its created date). Oldest invoices are settled first.
  final DateTime invoiceDate;

  /// The invoice's party — drives the collection's auto-filled party so
  /// a collection can't be booked against the wrong customer.
  final String? partyId;
  final String partyName;

  @override
  bool operator ==(Object other) =>
      other is CollectionInvoice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
