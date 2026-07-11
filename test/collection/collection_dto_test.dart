import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/collection/data/dto/collection_dto.dart';
import 'package:sales_sphere_erp/features/collection/data/repositories/collection_repository_impl.dart';
import 'package:sales_sphere_erp/features/collection/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';

/// A full server row as `/collections/{id}` actually returns it — string money,
/// `yyyy-MM-dd` calendar days, ISO timestamps, SCREAMING_SNAKE enums.
Map<String, dynamic> _wire({
  Object? amount = '20000.00',
  String paymentMode = 'CHEQUE',
  Object? chequeStatus = 'PENDING',
  Object? chequeDate = '2026-07-11',
  Object? createdBy = const <String, dynamic>{
    'id': 'usr_1',
    'name': 'Bikram Agrawal',
  },
  List<dynamic> allocations = const <dynamic>[],
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
  'status': 'DRAFT',
  'voucherId': null,
  'createdBy': createdBy,
  'createdAt': '2026-07-11T09:00:00.000Z',
  'updatedAt': '2026-07-11T09:00:00.000Z',
  'allocations': allocations,
};

void main() {
  group('CollectionDto.fromJson', () {
    test('money arrives as a decimal STRING, not a number', () {
      // The single easiest thing to get wrong: `amount` goes out as a JSON
      // number and comes back as `Decimal.toFixed(2)`. A naive `as num` cast
      // throws on every read.
      final dto = CollectionDto.fromJson(_wire());
      expect(dto.amount, 20000.00);
    });

    test('tolerates a raw number too, so a local draft round-trips', () {
      final dto = CollectionDto.fromJson(_wire(amount: 20000));
      expect(dto.amount, 20000.00);
    });

    test('receivedDate is a calendar day, not a timestamp', () {
      // Parsed to local midnight so date formatting can't shift it across a
      // timezone boundary and render the wrong day.
      final dto = CollectionDto.fromJson(_wire());
      expect(dto.receivedDate, DateTime(2026, 7, 11));
      expect(dto.chequeDate, DateTime(2026, 7, 11));
    });

    test('createdAt is a full ISO timestamp — a different codec', () {
      final dto = CollectionDto.fromJson(_wire());
      expect(dto.createdAt.toUtc(), DateTime.utc(2026, 7, 11, 9));
    });

    test('createdBy is an {id, name} object — id filters, name renders', () {
      // The mock compared a picked user id against a display name, so the
      // "Created By" filter could never match. Two fields, not one.
      final dto = CollectionDto.fromJson(_wire());
      expect(dto.createdBy?.id, 'usr_1');
      expect(dto.createdBy?.name, 'Bikram Agrawal');
    });

    test('createdBy is null on rows migrated from the old Payment table', () {
      final dto = CollectionDto.fromJson(_wire(createdBy: null));
      expect(dto.createdBy, isNull);
    });

    test('cheque fields are null when the mode is not CHEQUE', () {
      final dto = CollectionDto.fromJson(
        _wire(paymentMode: 'CASH', chequeStatus: null, chequeDate: null),
      );
      expect(dto.chequeStatus, isNull);
      expect(dto.chequeDate, isNull);
    });

    test('a plain collection has no allocations', () {
      expect(CollectionDto.fromJson(_wire()).allocations, isEmpty);
    });

    test('a Collection Plus row carries the server-computed split', () {
      final dto = CollectionDto.fromJson(
        _wire(
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
      expect(dto.allocations, hasLength(2));
      expect(dto.allocations[0].invoiceNumber, 'INV-A');
      expect(dto.allocations[1].amount, 10000.50);
    });
  });

  group('CollectionDto write bodies', () {
    test('create sends amount as a NUMBER and the date as yyyy-MM-dd', () {
      final json = CollectionDto.fromJson(_wire()).toCreateJson();
      expect(json['amount'], isA<num>());
      expect(json['receivedDate'], '2026-07-11');
      expect(json['chequeDate'], '2026-07-11');
    });

    test('create omits clientRequestId unless one was supplied', () {
      expect(
        CollectionDto.fromJson(_wire()).toCreateJson(),
        isNot(contains('clientRequestId')),
      );
    });

    test('update never sends customerId — a receipt cannot be reassigned', () {
      final json = CollectionDto.fromJson(_wire()).toUpdateJson();
      expect(json, isNot(contains('customerId')));
    });

    test('update always resends the whole payment block, nulls included', () {
      // PATCH is payment-block-atomic server-side: send `paymentMode` and the
      // bank/cheque fields are all renormalised (cleared if the new mode
      // doesn't own them). Omitting a key would leave a stale value behind.
      final json = CollectionDto.fromJson(_wire()).toUpdateJson();
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

    test('invoiceIds ride along only for the Collection Plus endpoints', () {
      final dto = CollectionDto.fromJson(_wire());
      expect(dto.toCreateJson(), isNot(contains('invoiceIds')));
      expect(
        dto.toCreateJson(invoiceIds: <String>['inv_a'])['invoiceIds'],
        <String>['inv_a'],
      );
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

    test('collection statuses round-trip', () {
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
