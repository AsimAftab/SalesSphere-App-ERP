import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product.dart';
import 'package:sales_sphere_erp/features/invoice/data/invoice_mock_data.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice_draft_data.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice_line_item.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice_party.dart';
import 'package:sales_sphere_erp/features/invoice/domain/tax_option.dart';

part 'invoice_providers.g.dart';

/// Parties offered in the searchable "Select party" sheet. Synchronous —
/// no API/drift yet (mock-only). Swap for a repository read when the
/// invoice feature is wired to the backend.
@riverpod
List<InvoiceParty> invoiceParties(Ref ref) => kMockInvoiceParties;

/// Tax lines offered in the invoice's tax picker.
@riverpod
List<TaxOption> taxOptions(Ref ref) => kTaxOptions;

/// The live invoice-builder draft. `keepAlive` so it survives navigation
/// reliably (the Add-Item catalog round-trip, the History push). It is
/// reset to empty after a successful create, and when the user leaves the
/// `/invoice` zone for another tab (handled by the router redirect in
/// `app_router.dart`).
@Riverpod(keepAlive: true)
class InvoiceDraft extends _$InvoiceDraft {
  @override
  InvoiceDraftData build() => InvoiceDraftData.initial(kDefaultTaxOption);

  void selectParty(InvoiceParty party) =>
      state = state.copyWith(party: party);

  void clearParty() => state = state.copyWith(clearParty: true);

  void setDeliveryDate(DateTime date) =>
      state = state.copyWith(deliveryDate: date);

  /// Merge picked products into the draft at quantity 1. Products already
  /// present are left untouched so any edits are preserved; only new ids
  /// become fresh lines.
  void addProducts(List<Product> products) {
    final existing = <String>{for (final line in state.items) line.productId};
    final additions = products
        .where((p) => !existing.contains(p.id))
        .map(InvoiceLineItem.fromProduct)
        .toList(growable: false);
    if (additions.isEmpty) return;
    state =
        state.copyWith(items: <InvoiceLineItem>[...state.items, ...additions]);
  }

  /// Merge a catalog cart (productId → quantity) into the draft. New
  /// products become lines at the cart quantity (capped to stock);
  /// products already on the invoice are left untouched (edit their
  /// quantity on the line instead).
  void addFromCart(Map<String, int> cart, List<Product> products) {
    final existing = <String>{for (final line in state.items) line.productId};
    final additions = <InvoiceLineItem>[];
    for (final entry in cart.entries) {
      if (existing.contains(entry.key)) continue;
      Product? product;
      for (final p in products) {
        if (p.id == entry.key) {
          product = p;
          break;
        }
      }
      if (product == null || product.stock <= 0) continue;
      additions.add(
        InvoiceLineItem.fromProduct(product, quantity: entry.value),
      );
    }
    if (additions.isEmpty) return;
    state =
        state.copyWith(items: <InvoiceLineItem>[...state.items, ...additions]);
  }

  void removeItem(String productId) => state = state.copyWith(
        items: state.items
            .where((line) => line.productId != productId)
            .toList(growable: false),
      );

  void updateQuantity(String productId, int quantity) => _patch(productId, (line) {
        final max = line.availableStock < 1 ? 1 : line.availableStock;
        final clamped = quantity < 1 ? 1 : (quantity > max ? max : quantity);
        return line.copyWith(quantity: clamped);
      });

  void updateBasePrice(String productId, double basePrice) => _patch(
        productId,
        (line) => line.copyWith(basePrice: basePrice < 0 ? 0 : basePrice),
      );

  /// Sets the base price implied by a discount off the listed price —
  /// the inverse of [InvoiceLineItem.discountPercent]. Keeps base price
  /// and discount as two views of the same value.
  void updateDiscountPercent(String productId, double discountPercent) =>
      _patch(productId, (line) {
        final pct = discountPercent.clamp(0, 100);
        return line.copyWith(basePrice: line.listedPrice * (1 - pct / 100));
      });

  void setOverallDiscountPercent(double percent) =>
      state = state.copyWith(overallDiscountPercent: percent.clamp(0, 100));

  void setTax(TaxOption tax) => state = state.copyWith(tax: tax);

  void reset() => state = InvoiceDraftData.initial(kDefaultTaxOption);

  void _patch(
    String productId,
    InvoiceLineItem Function(InvoiceLineItem) update,
  ) {
    final index =
        state.items.indexWhere((line) => line.productId == productId);
    if (index == -1) return;
    final next = <InvoiceLineItem>[...state.items];
    next[index] = update(next[index]);
    state = state.copyWith(items: next);
  }
}

/// In-memory list of saved invoices + estimates, seeded from the mock
/// corpus. The history screen watches this; the controller prepends new
/// records after a successful create.
///
/// Async so the history screen has a real loading window to paint a
/// skeleton against (mirrors `ExpenseClaimsList`). `keepAlive` so created
/// records persist after leaving the page — swap `build` for a
/// `repo.getInvoices()` call when a backend lands.
@Riverpod(keepAlive: true)
class InvoiceHistory extends _$InvoiceHistory {
  @override
  Future<List<Invoice>> build() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return List<Invoice>.from(kMockInvoiceHistory);
  }

  /// Insert [invoice] at the head of the list. Called by the controller
  /// after a successful create.
  void prependLocal(Invoice invoice) {
    final current = state.value ?? const <Invoice>[];
    if (current.any((i) => i.id == invoice.id)) return;
    state = AsyncValue<List<Invoice>>.data(<Invoice>[invoice, ...current]);
  }

  /// Pull-to-refresh. Mock-only: simulates a round-trip and re-emits the
  /// current list (locally-created rows are preserved).
  Future<void> refresh() async {
    final current = state.value ?? const <Invoice>[];
    await Future<void>.delayed(const Duration(milliseconds: 600));
    state = AsyncValue<List<Invoice>>.data(<Invoice>[...current]);
  }
}
