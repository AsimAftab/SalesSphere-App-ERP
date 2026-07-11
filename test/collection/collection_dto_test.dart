import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/collection/data/dto/collection_dto.dart';
import 'package:sales_sphere_erp/features/collection/data/repositories/collection_repository_impl.dart';
import 'package:sales_sphere_erp/features/collection/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';
import 'package:sales_sphere_erp/features/collection_plus/data/dto/collection_plus_dto.dart';
import 'package:sales_sphere_erp/features/collection_plus/data/repositories/collection_plus_repository_impl.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_status.dart';

/// A `/collections` row as the server actually returns it.
///
/// Note what is **absent**: no `status`, no `voucherId`, no `allocations`. A
/// plain Collection is a pure CRM record with no ledger, so the server doesn't
/// send them. This shape is the whole reason the DTO had to be split — the old
/// shared DTO required `status`, so every read threw once the server stopped
/// sending it.
Map<String, dynamic> _collectionWire({
  Object? amount = '20000.00',
  String paymentMode = 'CHEQUE',
  Object? chequeStatus = 'PENDING',
  Object? chequeDate = '2026-07-11',
  Object? createdBy = const <String, dynamic>{
    'id': 'usr_1',
    'name': 'Bikram Agrawal',
  },
}) => <String, dynamic>{
  'id': 'col_1',
  'collectionNo': 'RCPT-82-0001',
  'customer': <String, dynamic>{
    'id': 'cus_1',
    'name': 'Himalayan Traders',
    'address': 'Thamel',
    'ownerName': null,
  },
  'amount': amount,
  'receivedDate': '2026-07-11',
  'receivedDateBS': '2082-03-27',
  'paymentMode': paymentMode,
  'bankName': 'Nabil Bank',
  'chequeNumber': 'CHQ-778899',
  'chequeDate': chequeDate,
  'chequeStatus': chequeStatus,
  'description': null,
  'images': <dynamic>[
    <String, dynamic>{'imageNumber': 1, 'imageUrl': 'https://cdn/x.jpg'},
  ],
  'createdBy': createdBy,
  'createdAt': '2026-07-11T09:00:00.000Z',
  'updatedAt': '2026-07-11T09:00:00.000Z',
};

/// A `/collection-plus` row: everything above **plus** the three ledger fields.
Map<String, dynamic> _plusWire({
  String status = 'DRAFT',
  Object? voucherId,
  List<dynamic> allocations = const <dynamic>[],
}) => <String, dynamic>{
  ..._collectionWire(),
  'status': status,
  'voucherId': voucherId,
  'allocations': allocations,
};

void main() {
  group('CollectionDto — the plain, ledger-free shape', () {
    test('parses a row that carries no status / voucherId / allocations', () {
      // The regression this whole split exists to prevent: the server stopped
      // sending `status`, the shared DTO still required it, and every
      // /collections read threw.
      final dto = CollectionDto.fromJson(_collectionWire());
      expect(dto.id, 'col_1');
      expect(dto.collectionNo, 'RCPT-82-0001');
    });

    test('money arrives as a decimal STRING, not a number', () {
      // `amount` goes out as a JSON number and comes back as Decimal.toFixed(2).
      // A naive `as num` cast throws on every read.
      expect(CollectionDto.fromJson(_collectionWire()).amount, 20000.00);
    });

    test('tolerates a raw number too, so a local draft round-trips', () {
      expect(
        CollectionDto.fromJson(_collectionWire(amount: 20000)).amount,
        20000.00,
      );
    });

    test('receivedDate and chequeDate are calendar days, not timestamps', () {
      final dto = CollectionDto.fromJson(_collectionWire());
      expect(dto.receivedDate, DateTime(2026, 7, 11));
      expect(dto.chequeDate, DateTime(2026, 7, 11));
    });

    test('createdAt is a full ISO timestamp — a different codec', () {
      final dto = CollectionDto.fromJson(_collectionWire());
      expect(dto.createdAt.toUtc(), DateTime.utc(2026, 7, 11, 9));
    });

    test('createdBy is an {id, name} object — id filters, name renders', () {
      final dto = CollectionDto.fromJson(_collectionWire());
      expect(dto.createdBy?.id, 'usr_1');
      expect(dto.createdBy?.name, 'Bikram Agrawal');
    });

    test('createdBy is null on rows migrated from the old Payment table', () {
      expect(
        CollectionDto.fromJson(_collectionWire(createdBy: null)).createdBy,
        isNull,
      );
    });

    test('cheque fields are null when the mode is not CHEQUE', () {
      final dto = CollectionDto.fromJson(
        _collectionWire(
          paymentMode: 'CASH',
          chequeStatus: null,
          chequeDate: null,
        ),
      );
      expect(dto.chequeStatus, isNull);
      expect(dto.chequeDate, isNull);
    });
  });

  group('CollectionPlusDto — the ledger-backed shape', () {
    test('carries status, voucherId and the server-computed split', () {
      final dto = CollectionPlusDto.fromJson(
        _plusWire(
          status: 'POSTED',
          voucherId: 'vch_9',
          allocations: <dynamic>[
            <String, dynamic>{
              'invoiceId': 'inv_a',
              'invoiceNumber': 'INV-A',
              'amount': '20000.00',
            },
            <String, dynamic>{
              'invoiceId': 'inv_b',
              'invoiceNumber': 'INV-B',
              'amount': '10000.50',
            },
          ],
        ),
      );
      expect(dto.status, 'POSTED');
      expect(dto.voucherId, 'vch_9');
      expect(dto.allocations, hasLength(2));
      expect(dto.allocations[1].amount, 10000.50);
    });

    test('is a CollectionDto, so the shared drift cache accepts it', () {
      // The DAO takes List<CollectionDto> and reads the ledger fields only for
      // Plus rows. That only works because Plus *is* a Collection.
      expect(CollectionPlusDto.fromJson(_plusWire()), isA<CollectionDto>());
    });

    test('a queued row has no allocations — the server hasn\'t split it yet',
        () {
      expect(CollectionPlusDto.fromJson(_plusWire()).allocations, isEmpty);
    });
  });

  group('write bodies', () {
    test('create sends amount as a NUMBER and dates as yyyy-MM-dd', () {
      final json = CollectionDto.fromJson(_collectionWire()).toCreateJson();
      expect(json['amount'], isA<num>());
      expect(json['receivedDate'], '2026-07-11');
      expect(json['chequeDate'], '2026-07-11');
    });

    test('a plain Collection never sends invoiceIds', () {
      // It's booked against the party, not an invoice — there is nothing to
      // allocate.
      final json = CollectionDto.fromJson(_collectionWire()).toCreateJson();
      expect(json, isNot(contains('invoiceIds')));
    });

    test('Collection Plus sends the selection, never a split', () {
      final dto = CollectionPlusDto.fromJson(_plusWire());
      expect(
        dto.toCreateJson(invoiceIds: <String>['inv_a'])['invoiceIds'],
        <String>['inv_a'],
      );
      // The client's own allocations are never serialised — the server owns the
      // split and recomputes it against live balances.
      expect(dto.toCreateJson(), isNot(contains('allocations')));
    });

    test('update never sends customerId — a receipt cannot be reassigned', () {
      expect(
        CollectionDto.fromJson(_collectionWire()).toUpdateJson(),
        isNot(contains('customerId')),
      );
    });

    test('update always resends the whole payment block, nulls included', () {
      // PATCH is payment-block-atomic server-side: send `paymentMode` and the
      // bank/cheque fields are all renormalised (cleared if the new mode
      // doesn't own them). Omitting a key would leave a stale value behind.
      final json = CollectionDto.fromJson(_collectionWire()).toUpdateJson();
      for (final key in <String>[
        'paymentMode',
        'bankName',
        'chequeNumber',
        'chequeDate',
        'chequeStatus',
        'description',
      ]) {
        expect(json, contains(key), reason: '$key must be sent on every PATCH');
      }
      expect(json['description'], isNull);
    });

    test('neither write body ever sends `status`', () {
      // It's server-owned on Plus and doesn't exist at all on Collection.
      final plus = CollectionPlusDto.fromJson(_plusWire());
      expect(plus.toCreateJson(), isNot(contains('status')));
      expect(plus.toUpdateJson(), isNot(contains('status')));
    });
  });

  group('wire codecs', () {
    test('payment modes round-trip', () {
      for (final m in PaymentMode.values) {
        expect(paymentModeFromWire(paymentModeToWire(m)), m);
      }
      expect(paymentModeToWire(PaymentMode.bankTransfer), 'BANK_TRANSFER');
      expect(paymentModeToWire(PaymentMode.qrPay), 'QR_PAY');
    });

    test('cheque statuses round-trip', () {
      for (final s in ChequeStatus.values) {
        expect(chequeStatusFromWire(chequeStatusToWire(s)), s);
      }
    });

    test('collection statuses round-trip (Collection Plus only)', () {
      for (final s in CollectionStatus.values) {
        expect(collectionStatusFromWire(collectionStatusToWire(s)), s);
      }
    });

    test('an unknown wire value throws rather than defaulting silently', () {
      // A silent default would mis-render money. Fail loudly instead.
      expect(() => paymentModeFromWire('CRYPTO'), throwsFormatException);
      expect(() => chequeStatusFromWire('STOPPED'), throwsFormatException);
      expect(() => collectionStatusFromWire('VOID'), throwsFormatException);
    });
  });
}
