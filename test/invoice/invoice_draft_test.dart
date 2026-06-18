import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product.dart';
import 'package:sales_sphere_erp/features/invoice/data/invoice_mock_data.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice_line_item.dart';
import 'package:sales_sphere_erp/features/invoice/domain/tax_option.dart';
import 'package:sales_sphere_erp/features/invoice/presentation/controllers/invoice_controller.dart';
import 'package:sales_sphere_erp/features/invoice/presentation/providers/invoice_providers.dart';

Product _product(String id, double price) => Product(
      id: id,
      name: 'Product $id',
      sku: id.toUpperCase(),
      categoryId: 'cat',
      price: price,
      stock: 100,
    );

void main() {
  group('InvoiceLineItem', () {
    test('subtotal is qty x base price; discount is derived from listed', () {
      const line = InvoiceLineItem(
        productId: 'p1',
        name: 'P1',
        listedPrice: 1000,
        quantity: 3,
        basePrice: 900,
        availableStock: 100,
      );
      expect(line.subtotal, 2700); // 3 * 900
      expect(line.discountPercent, closeTo(10, 1e-9)); // (1 - 900/1000) * 100
      expect(line.savings, 300); // (1000 - 900) * 3
    });

    test('a markup (base above listed) shows zero discount, zero savings', () {
      const line = InvoiceLineItem(
        productId: 'p1',
        name: 'P1',
        listedPrice: 1000,
        quantity: 1,
        basePrice: 1200,
        availableStock: 100,
      );
      expect(line.discountPercent, 0);
      expect(line.savings, 0);
    });
  });

  group('InvoiceDraft', () {
    test('editing the discount sets the implied base price', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Pin the auto-dispose draft so it survives across reads in the test.
      container.listen(invoiceDraftProvider, (_, __) {});
      container.read(invoiceDraftProvider.notifier)
        ..addProducts(<Product>[_product('p1', 1000)])
        ..updateDiscountPercent('p1', 20);

      final line = container.read(invoiceDraftProvider).items.single;
      expect(line.basePrice, 800); // 1000 * (1 - 0.20)
      expect(line.discountPercent, closeTo(20, 1e-9));
    });

    test('overall discount and VAT compound on the items subtotal', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Pin the auto-dispose draft so it survives across reads in the test.
      container.listen(invoiceDraftProvider, (_, __) {});
      container.read(invoiceDraftProvider.notifier)
        ..addProducts(<Product>[_product('p1', 100), _product('p2', 50)])
        ..updateQuantity('p1', 2) // 2 * 100 = 200
        ..updateQuantity('p2', 4) // 4 * 50  = 200
        ..updateBasePrice('p1', 90) // line1 subtotal = 2 * 90 = 180
        ..setOverallDiscountPercent(5)
        ..setTax(const TaxOption(id: 'vat13', label: 'VAT 13%', rate: 13));

      final draft = container.read(invoiceDraftProvider);
      expect(draft.itemsSubtotal, 380); // 180 + 200
      expect(draft.overallDiscountAmount, 19); // 5% of 380
      expect(draft.taxableBase, 361);
      expect(draft.taxAmount, closeTo(46.93, 0.0001));
      expect(draft.grandTotal, closeTo(407.93, 0.0001));
    });

    test('addFromCart caps quantity to stock; updateQuantity stays capped', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(invoiceDraftProvider, (_, __) {});
      container.read(invoiceDraftProvider.notifier)
        ..addFromCart(<String, int>{'p1': 10}, <Product>[
          const Product(
            id: 'p1',
            name: 'P1',
            sku: 'P1',
            categoryId: 'c',
            price: 100,
            stock: 4,
          ),
        ])
        ..updateQuantity('p1', 99);

      final line = container.read(invoiceDraftProvider).items.single;
      expect(line.availableStock, 4);
      expect(line.quantity, 4); // capped to stock
    });

    test('addProducts does not duplicate an already-added product', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Pin the auto-dispose draft so it survives across reads in the test.
      container.listen(invoiceDraftProvider, (_, __) {});
      container.read(invoiceDraftProvider.notifier)
        ..addProducts(<Product>[_product('p1', 100)])
        ..updateQuantity('p1', 5)
        ..addProducts(<Product>[_product('p1', 100)]); // re-add

      final draft = container.read(invoiceDraftProvider);
      expect(draft.items, hasLength(1));
      expect(draft.items.single.quantity, 5);
    });
  });

  group('InvoiceController create flow', () {
    test('createInvoice appends to history and resets the draft', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Pin the auto-dispose draft so it survives across reads in the test.
      container.listen(invoiceDraftProvider, (_, __) {});

      await container.read(invoiceHistoryProvider.future);
      container
          .read(invoiceDraftProvider.notifier)
          .addProducts(<Product>[_product('p1', 100)]);

      final created = await container
          .read(invoiceControllerProvider.notifier)
          .createInvoice();

      expect(created.kind, InvoiceKind.invoice);
      expect(created.number, 'INV-1003'); // one past seeded INV-1002

      final history = container.read(invoiceHistoryProvider).requireValue;
      expect(history.first.id, created.id);

      final draft = container.read(invoiceDraftProvider);
      expect(draft.isEmpty, isTrue);
      expect(draft.tax, kDefaultTaxOption);
    });
  });
}
