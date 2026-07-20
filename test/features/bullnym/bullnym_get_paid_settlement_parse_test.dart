import 'package:bb_mobile/features/bullnym/domain/bullnym_fiat_settlement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BullnymGetPaidSettlement.tryParse (tolerant)', () {
    test('returns null when neither settlement field is present', () {
      expect(BullnymGetPaidSettlement.tryParse({'amount_sat': 1000}), isNull);
    });

    test('parses a fiat settlement with a settled order', () {
      final s = BullnymGetPaidSettlement.tryParse({
        'settlement_details': {
          'kind': 'fiat',
          'fiat': [
            {
              'amount_minor': 12345,
              'currency': 'CAD',
              'order_id': 'ord-1',
              'status': 'settled',
            },
          ],
        },
      })!;
      expect(s.kind, BullnymSettlementKind.fiat);
      expect(s.fiat.single.amountMinor, 12345);
      expect(s.fiat.single.currency, 'CAD');
      expect(s.fiat.single.orderId, 'ord-1');
      expect(s.fiat.single.status, BullnymSettlementLegStatus.settled);
    });

    test('parses a mixed settlement with both legs', () {
      final s = BullnymGetPaidSettlement.tryParse({
        'settlement_details': {
          'kind': 'mixed',
          'bitcoin': [
            {'amount_sat': 2000, 'network': 'liquid', 'status': 'settled'},
          ],
          'fiat': [
            {'currency': 'EUR', 'order_id': 'ord-2', 'status': 'pending'},
          ],
        },
      })!;
      expect(s.kind, BullnymSettlementKind.mixed);
      expect(s.bitcoin.single.amountSat, 2000);
      expect(s.fiat.single.amountMinor, isNull); // pending → no amount
      expect(s.fiat.single.status, BullnymSettlementLegStatus.pending);
    });

    test('an override is classified as kept-in-bitcoin with a reason', () {
      final s = BullnymGetPaidSettlement.tryParse({
        'fiat_conversion': {'status': 'overridden', 'reason': 'below_minimum'},
      })!;
      expect(s.kind, BullnymSettlementKind.bitcoin);
      expect(
        s.overrideReason,
        BullnymFiatConversionOverrideReason.belowMinimum,
      );
    });

    test('an unknown override reason maps to unknown, still an override', () {
      final s = BullnymGetPaidSettlement.tryParse({
        'fiat_conversion': {'status': 'overridden', 'reason': 'brand_new'},
      })!;
      expect(s.kind, BullnymSettlementKind.bitcoin);
      expect(s.overrideReason, BullnymFiatConversionOverrideReason.unknown);
    });

    test('an unknown settlement kind yields unavailable (never bitcoin)', () {
      final s = BullnymGetPaidSettlement.tryParse({
        'settlement_details': {'kind': 'quantum_split'},
      })!;
      expect(s.kind, BullnymSettlementKind.unavailable);
    });

    test('a malformed settlement_details yields unavailable', () {
      final s = BullnymGetPaidSettlement.tryParse({
        'settlement_details': 'not-an-object',
      })!;
      expect(s.kind, BullnymSettlementKind.unavailable);
    });
  });
}
