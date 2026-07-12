import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/targets/data/dto/my_target_dto.dart';

void main() {
  group('MyTargetDto.fromJson', () {
    test('parses a verbatim /targets/me row (decimal-string values)', () {
      // Copied off the server — see TARGETS-MOBILE-PROMPT.md §1.
      final json = <String, dynamic>{
        'id': 'cmrhx1aoq00034o1l0vqd99ch',
        'rule': 'No. of Orders',
        'metric': 'ORDER_COUNT',
        'interval': 'DAILY',
        'targetValue': '99.00',
        'actualValue': '1.00',
        'status': 'ACTIVE',
        'isCurrency': false,
        'periodStart': '2026-07-12',
        'periodEnd': '2026-07-12',
        'periodLabel': 'Jul 12, 2026',
        'periodStatus': 'IN_PROGRESS',
      };

      final dto = MyTargetDto.fromJson(json);

      expect(dto.id, 'cmrhx1aoq00034o1l0vqd99ch');
      expect(dto.rule, 'No. of Orders');
      // Wire enums stay raw strings on the DTO — the repository maps them.
      expect(dto.metric, 'ORDER_COUNT');
      expect(dto.interval, 'DAILY');
      expect(dto.status, 'ACTIVE');
      expect(dto.periodStatus, 'IN_PROGRESS');
      // The decimal STRING "99.00" must parse, not throw (`as num` did).
      expect(dto.targetValue, 99.0);
      expect(dto.actualValue, 1.0);
      expect(dto.isCurrency, isFalse);
      expect(dto.periodStart, DateTime(2026, 7, 12));
      expect(dto.periodEnd, DateTime(2026, 7, 12));
      expect(dto.periodLabel, 'Jul 12, 2026');
    });

    test('counts arrive as decimal strings too ("10.00" for ten orders)', () {
      final dto = MyTargetDto.fromJson(<String, dynamic>{
        'id': 'x',
        'rule': 'No. of Orders',
        'metric': 'ORDER_COUNT',
        'interval': 'MONTHLY',
        'targetValue': '10.00',
        'actualValue': '0.00',
        'status': 'ACTIVE',
        'isCurrency': false,
        'periodStart': '2026-07-01',
        'periodEnd': '2026-07-31',
        'periodLabel': 'July 2026',
        'periodStatus': 'IN_PROGRESS',
      });

      expect(dto.targetValue, 10.0);
      expect(dto.actualValue, 0.0);
    });

    test('tolerates raw numbers (drift round-trip of locally-held data)', () {
      final dto = MyTargetDto.fromJson(<String, dynamic>{
        'id': 'x',
        'rule': 'Value of Orders',
        'metric': 'ORDER_VALUE',
        'interval': 'DAILY',
        'targetValue': 450000,
        'actualValue': 480000.5,
        'status': 'COMPLETED',
        'isCurrency': true,
        'periodStart': '2026-07-12',
        'periodEnd': '2026-07-12',
        'periodLabel': 'Jul 12, 2026',
        'periodStatus': 'CLOSED',
      });

      expect(dto.targetValue, 450000.0);
      expect(dto.actualValue, 480000.5);
      expect(dto.isCurrency, isTrue);
    });

    test('throws on a missing required field rather than defaulting', () {
      expect(
        () => MyTargetDto.fromJson(<String, dynamic>{'id': 'x'}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
