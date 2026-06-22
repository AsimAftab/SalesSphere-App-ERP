import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/catalog/domain/product.dart';
import 'package:sales_sphere_erp/features/orders/data/tax_options.dart';
import 'package:sales_sphere_erp/features/orders/domain/order.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_draft_data.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_line_item.dart';
import 'package:sales_sphere_erp/features/orders/domain/order_organization.dart';
import 'package:sales_sphere_erp/features/orders/domain/repositories/order_repository.dart';
import 'package:sales_sphere_erp/features/orders/domain/tax_option.dart';
import 'package:sales_sphere_erp/features/orders/presentation/controllers/order_controller.dart';
import 'package:sales_sphere_erp/features/orders/presentation/providers/order_providers.dart';

Product _product(String id, double price) => Product(
      id: id,
      name: 'Product $id',
      sku: id.toUpperCase(),
      categoryId: 'cat',
      price: price,
      stock: 100,
    );

void main() {
  group('OrderLineItem', () {
    test('subtotal is qty x base price; discount is derived from listed', () {
      const line = OrderLineItem(
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
      const line = OrderLineItem(
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

  group('OrderDraft', () {
    test('editing the discount sets the implied base price', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Pin the auto-dispose draft so it survives across reads in the test.
      container.listen(orderDraftProvider, (_, __) {});
      container.read(orderDraftProvider.notifier)
        ..addProducts(<Product>[_product('p1', 1000)])
        ..updateDiscountPercent('p1', 20);

      final line = container.read(orderDraftProvider).items.single;
      expect(line.basePrice, 800); // 1000 * (1 - 0.20)
      expect(line.discountPercent, closeTo(20, 1e-9));
    });

    test('overall discount and VAT compound on the items subtotal', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Pin the auto-dispose draft so it survives across reads in the test.
      container.listen(orderDraftProvider, (_, __) {});
      container.read(orderDraftProvider.notifier)
        ..addProducts(<Product>[_product('p1', 100), _product('p2', 50)])
        ..updateQuantity('p1', 2) // 2 * 100 = 200
        ..updateQuantity('p2', 4) // 4 * 50  = 200
        ..updateBasePrice('p1', 90) // line1 subtotal = 2 * 90 = 180
        ..setOverallDiscountPercent(5)
        ..setTax(const TaxOption(id: 'vat13', label: 'VAT 13%', rate: 13));

      final draft = container.read(orderDraftProvider);
      expect(draft.itemsSubtotal, 380); // 180 + 200
      expect(draft.overallDiscountAmount, 19); // 5% of 380
      expect(draft.taxableBase, 361);
      expect(draft.taxAmount, closeTo(46.93, 0.0001));
      expect(draft.grandTotal, closeTo(407.93, 0.0001));
    });

    test('addFromCart caps quantity to stock; updateQuantity stays capped', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(orderDraftProvider, (_, __) {});
      container.read(orderDraftProvider.notifier)
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

      final line = container.read(orderDraftProvider).items.single;
      expect(line.availableStock, 4);
      expect(line.quantity, 4); // capped to stock
    });

    test('addProducts does not duplicate an already-added product', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Pin the auto-dispose draft so it survives across reads in the test.
      container.listen(orderDraftProvider, (_, __) {});
      container.read(orderDraftProvider.notifier)
        ..addProducts(<Product>[_product('p1', 100)])
        ..updateQuantity('p1', 5)
        ..addProducts(<Product>[_product('p1', 100)]); // re-add

      final draft = container.read(orderDraftProvider);
      expect(draft.items, hasLength(1));
      expect(draft.items.single.quantity, 5);
    });
  });

  group('OrderController create flow', () {
    test('createOrder appends to history and resets the draft', () async {
      final fake = _FakeOrderRepository();
      final container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);
      // Pin the auto-dispose draft so it survives across reads in the test.
      container.listen(orderDraftProvider, (_, __) {});

      // Hydrate history from the (empty) fake backend first.
      await container.read(orderHistoryProvider.future);
      container
          .read(orderDraftProvider.notifier)
          .addProducts(<Product>[_product('p1', 100)]);

      final created = await container
          .read(orderControllerProvider.notifier)
          .createOrder();

      expect(created.kind, OrderKind.order);
      // The server issues the number; the controller just surfaces it.
      expect(created.number, 'INV-82-0001');

      final history = container.read(orderHistoryProvider).requireValue;
      expect(history.first.id, created.id);

      final draft = container.read(orderDraftProvider);
      expect(draft.isEmpty, isTrue);
      expect(draft.tax, kDefaultTaxOption);
    });
  });
}

/// Minimal in-memory [OrderRepository] for the controller test — stands in
/// for the network so the create flow can be exercised without Dio.
class _FakeOrderRepository implements OrderRepository {
  @override
  Future<List<Order>> getHistory() async => const <Order>[];

  @override
  Future<Order> createOrder(OrderDraftData draft) async => _order(
    OrderKind.order,
    'INV-82-0001',
    draft,
  );

  @override
  Future<Order> createEstimate(OrderDraftData draft) async => _order(
    OrderKind.estimate,
    'EST-82-0001',
    draft,
  );

  @override
  Future<Order> convertToOrder(Order estimate, DateTime deliveryDate) async =>
      Order(
        id: 'srv_conv',
        number: 'INV-82-0002',
        kind: OrderKind.order,
        status: OrderStatus.pending,
        party: estimate.party,
        deliveryDate: deliveryDate,
        items: estimate.items,
        overallDiscountPercent: estimate.overallDiscountPercent,
        tax: estimate.tax,
        createdAt: DateTime(2026, 6, 22),
      );

  @override
  Future<void> deleteEstimate(String id) async {}

  @override
  Future<OrderOrganization> getPrintProfile() async => const OrderOrganization(
    name: 'Test Org',
    panVat: '',
    phone: '',
    address: '',
  );

  Order _order(OrderKind kind, String number, OrderDraftData draft) => Order(
    id: 'srv_${kind.name}',
    number: number,
    kind: kind,
    status: OrderStatus.pending,
    party: draft.party,
    deliveryDate: draft.deliveryDate,
    items: draft.items,
    overallDiscountPercent: draft.overallDiscountPercent,
    tax: draft.tax,
    createdAt: DateTime(2026, 6, 22),
  );
}
