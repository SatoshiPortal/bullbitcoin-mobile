import 'package:bb_mobile/features/bullnym/domain/bullnym_fiat_settlement.dart';
import 'package:flutter_test/flutter_test.dart';

// Strict fail-closed parse matrix for the merchant settlement projection.
//
// tryParse consumes the AUTHORITATIVE top-level `settlement_kind`; it never
// derives Bitcoin from field presence, and any inconsistency fails closed to
// `unavailable` (or, for an absent classification, to the null no-data path).

const _orderId = '40000000-0000-4000-8000-000000000001';
const _orderId2 = '40000000-0000-4000-8000-000000000002';

Map<String, dynamic> _tx({
  Object? settlementKind = 'bitcoin',
  Object? details,
  Object? override,
  bool includeKind = true,
}) {
  return {
    'transaction_id': '10000000-0000-4000-8000-000000000001',
    'amount_sat': 2100,
    if (includeKind) 'settlement_kind': settlementKind,
    'settlement_details': ?details,
    'fiat_conversion': ?override,
  };
}

Map<String, dynamic> _fiatLeg({
  Object? amountMinor,
  Object? currency = 'CAD',
  Object? orderId = _orderId,
  Object? status = 'settled',
}) => {
  'amount_minor': amountMinor,
  'currency': currency,
  'order_id': orderId,
  'status': status,
};

Map<String, dynamic> _btcLeg({
  Object? amountSat = 60000,
  Object? network = 'liquid',
  Object? status = 'settled',
}) => {'amount_sat': amountSat, 'network': network, 'status': status};

void main() {
  group('BullnymGetPaidSettlement.tryParse — no-data path', () {
    test('absent settlement_kind returns null (never Bitcoin)', () {
      expect(
        BullnymGetPaidSettlement.tryParse(_tx(includeKind: false)),
        isNull,
      );
    });
  });

  group('valid projections', () {
    test('explicit bitcoin with no details or override', () {
      final s = BullnymGetPaidSettlement.tryParse(_tx())!;
      expect(s.kind, BullnymSettlementKind.bitcoin);
      expect(s.overrideReason, isNull);
      expect(s.fiat, isEmpty);
      expect(s.bitcoin, isEmpty);
    });

    test('bitcoin with a known conversion override', () {
      final s = BullnymGetPaidSettlement.tryParse(
        _tx(override: {'status': 'overridden', 'reason': 'invalid_split'}),
      )!;
      expect(s.kind, BullnymSettlementKind.bitcoin);
      expect(
        s.overrideReason,
        BullnymFiatConversionOverrideReason.invalidSplit,
      );
    });

    test(
      'bitcoin with an unknown override reason stays a bitcoin override',
      () {
        final s = BullnymGetPaidSettlement.tryParse(
          _tx(override: {'status': 'overridden', 'reason': 'brand_new'}),
        )!;
        expect(s.kind, BullnymSettlementKind.bitcoin);
        expect(s.overrideReason, BullnymFiatConversionOverrideReason.unknown);
      },
    );

    test('fiat with a single settled leg', () {
      final s = BullnymGetPaidSettlement.tryParse(
        _tx(
          settlementKind: 'fiat',
          details: {
            'kind': 'fiat',
            'fiat': [_fiatLeg(amountMinor: 12345)],
          },
        ),
      )!;
      expect(s.kind, BullnymSettlementKind.fiat);
      expect(s.fiat.single.amountMinor, 12345);
      expect(s.fiat.single.status, BullnymSettlementLegStatus.settled);
    });

    test('fiat with multiple valid legs (settled + pending)', () {
      final s = BullnymGetPaidSettlement.tryParse(
        _tx(
          settlementKind: 'fiat',
          details: {
            'kind': 'fiat',
            'fiat': [
              _fiatLeg(amountMinor: 12345),
              _fiatLeg(
                amountMinor: null,
                currency: 'EUR',
                orderId: _orderId2,
                status: 'pending',
              ),
            ],
          },
        ),
      )!;
      expect(s.kind, BullnymSettlementKind.fiat);
      expect(s.fiat.length, 2);
      expect(s.fiat[1].amountMinor, isNull);
      expect(s.fiat[1].status, BullnymSettlementLegStatus.pending);
    });

    test('mixed with a problem-status Bitcoin leg and a fiat leg', () {
      final s = BullnymGetPaidSettlement.tryParse(
        _tx(
          settlementKind: 'mixed',
          details: {
            'kind': 'mixed',
            'bitcoin': [_btcLeg(status: 'problem')],
            'fiat': [_fiatLeg(amountMinor: 12345)],
          },
        ),
      )!;
      expect(s.kind, BullnymSettlementKind.mixed);
      expect(s.bitcoin.single.status, BullnymSettlementLegStatus.problem);
      expect(s.fiat.single.status, BullnymSettlementLegStatus.settled);
    });
  });

  group('fail-closed to unavailable', () {
    void expectUnavailable(String reason, Map<String, dynamic> json) {
      expect(
        BullnymGetPaidSettlement.tryParse(json)?.kind,
        BullnymSettlementKind.unavailable,
        reason: reason,
      );
    }

    test('unknown settlement_kind', () {
      expectUnavailable('unknown kind', _tx(settlementKind: 'quantum_split'));
    });

    test('non-string settlement_kind', () {
      expectUnavailable('non-string kind', _tx(settlementKind: 7));
    });

    test('server-sent unavailable', () {
      expectUnavailable('unavailable', _tx(settlementKind: 'unavailable'));
    });

    test('unavailable that inconsistently carries details', () {
      expectUnavailable(
        'unavailable + details',
        _tx(
          settlementKind: 'unavailable',
          details: {
            'kind': 'fiat',
            'fiat': [_fiatLeg(amountMinor: 12345)],
          },
        ),
      );
    });

    test('bitcoin kind carrying settlement details', () {
      expectUnavailable(
        'bitcoin + details',
        _tx(
          settlementKind: 'bitcoin',
          details: {
            'kind': 'fiat',
            'fiat': [_fiatLeg(amountMinor: 12345)],
          },
        ),
      );
    });

    test('malformed override envelope', () {
      expectUnavailable(
        'override not overridden',
        _tx(override: {'status': 'applied'}),
      );
    });

    test('fiat kind carrying a conversion override', () {
      expectUnavailable(
        'fiat + override',
        _tx(
          settlementKind: 'fiat',
          details: {
            'kind': 'fiat',
            'fiat': [_fiatLeg(amountMinor: 12345)],
          },
          override: {'status': 'overridden', 'reason': 'below_minimum'},
        ),
      );
    });

    test('details.kind mismatched with settlement_kind', () {
      expectUnavailable(
        'kind mismatch',
        _tx(
          settlementKind: 'fiat',
          details: {
            'kind': 'mixed',
            'bitcoin': [_btcLeg()],
            'fiat': [_fiatLeg(amountMinor: 12345)],
          },
        ),
      );
    });

    test('fiat with an empty leg array', () {
      expectUnavailable(
        'empty fiat',
        _tx(settlementKind: 'fiat', details: {'kind': 'fiat', 'fiat': []}),
      );
    });

    test('fiat carrying a bitcoin array', () {
      expectUnavailable(
        'fiat + bitcoin array',
        _tx(
          settlementKind: 'fiat',
          details: {
            'kind': 'fiat',
            'fiat': [_fiatLeg(amountMinor: 12345)],
            'bitcoin': [_btcLeg()],
          },
        ),
      );
    });

    test('mixed missing the bitcoin leg', () {
      expectUnavailable(
        'mixed no bitcoin',
        _tx(
          settlementKind: 'mixed',
          details: {
            'kind': 'mixed',
            'fiat': [_fiatLeg(amountMinor: 12345)],
          },
        ),
      );
    });

    test('mixed missing the fiat leg', () {
      expectUnavailable(
        'mixed no fiat',
        _tx(
          settlementKind: 'mixed',
          details: {
            'kind': 'mixed',
            'bitcoin': [_btcLeg()],
          },
        ),
      );
    });

    test('settled fiat leg with a zero amount', () {
      expectUnavailable(
        'zero settled amount',
        _tx(
          settlementKind: 'fiat',
          details: {
            'kind': 'fiat',
            'fiat': [_fiatLeg(amountMinor: 0)],
          },
        ),
      );
    });

    test('settled fiat leg with a negative amount', () {
      expectUnavailable(
        'negative settled amount',
        _tx(
          settlementKind: 'fiat',
          details: {
            'kind': 'fiat',
            'fiat': [_fiatLeg(amountMinor: -5)],
          },
        ),
      );
    });

    test('pending fiat leg carrying a non-null amount', () {
      expectUnavailable(
        'pending with amount',
        _tx(
          settlementKind: 'fiat',
          details: {
            'kind': 'fiat',
            'fiat': [_fiatLeg(amountMinor: 100, status: 'pending')],
          },
        ),
      );
    });

    test('settled fiat leg missing the amount', () {
      expectUnavailable(
        'settled without amount',
        _tx(
          settlementKind: 'fiat',
          details: {
            'kind': 'fiat',
            'fiat': [_fiatLeg(amountMinor: null)],
          },
        ),
      );
    });

    test('fiat leg with a nil UUID order id', () {
      expectUnavailable(
        'nil order id',
        _tx(
          settlementKind: 'fiat',
          details: {
            'kind': 'fiat',
            'fiat': [
              _fiatLeg(
                amountMinor: 12345,
                orderId: '00000000-0000-0000-0000-000000000000',
              ),
            ],
          },
        ),
      );
    });

    test('fiat leg with a malformed order id', () {
      expectUnavailable(
        'malformed order id',
        _tx(
          settlementKind: 'fiat',
          details: {
            'kind': 'fiat',
            'fiat': [_fiatLeg(amountMinor: 12345, orderId: 'not-a-uuid')],
          },
        ),
      );
    });

    test('fiat leg with an unsupported currency', () {
      expectUnavailable(
        'unsupported currency',
        _tx(
          settlementKind: 'fiat',
          details: {
            'kind': 'fiat',
            'fiat': [_fiatLeg(amountMinor: 12345, currency: 'GBP')],
          },
        ),
      );
    });

    test('fiat leg with a lowercase currency', () {
      expectUnavailable(
        'lowercase currency',
        _tx(
          settlementKind: 'fiat',
          details: {
            'kind': 'fiat',
            'fiat': [_fiatLeg(amountMinor: 12345, currency: 'cad')],
          },
        ),
      );
    });

    test('fiat leg with a missing currency', () {
      expectUnavailable(
        'missing currency',
        _tx(
          settlementKind: 'fiat',
          details: {
            'kind': 'fiat',
            'fiat': [
              {
                'amount_minor': 12345,
                'order_id': _orderId,
                'status': 'settled',
              },
            ],
          },
        ),
      );
    });

    test('fiat leg with an unknown status', () {
      expectUnavailable(
        'unknown fiat status',
        _tx(
          settlementKind: 'fiat',
          details: {
            'kind': 'fiat',
            'fiat': [_fiatLeg(amountMinor: 12345, status: 'reversed')],
          },
        ),
      );
    });

    test('bitcoin leg with a non-liquid network', () {
      expectUnavailable(
        'non-liquid network',
        _tx(
          settlementKind: 'mixed',
          details: {
            'kind': 'mixed',
            'bitcoin': [_btcLeg(network: 'bitcoin')],
            'fiat': [_fiatLeg(amountMinor: 12345)],
          },
        ),
      );
    });

    test('bitcoin leg with a zero amount', () {
      expectUnavailable(
        'zero bitcoin amount',
        _tx(
          settlementKind: 'mixed',
          details: {
            'kind': 'mixed',
            'bitcoin': [_btcLeg(amountSat: 0)],
            'fiat': [_fiatLeg(amountMinor: 12345)],
          },
        ),
      );
    });

    test('bitcoin leg with an unavailable status (fiat-only status)', () {
      expectUnavailable(
        'bitcoin unavailable status',
        _tx(
          settlementKind: 'mixed',
          details: {
            'kind': 'mixed',
            'bitcoin': [_btcLeg(status: 'unavailable')],
            'fiat': [_fiatLeg(amountMinor: 12345)],
          },
        ),
      );
    });

    test('settlement_details that is not an object', () {
      expectUnavailable(
        'details not object',
        _tx(settlementKind: 'fiat', details: 'not-an-object'),
      );
    });

    test('fiat leg array that is not a list', () {
      expectUnavailable(
        'fiat not a list',
        _tx(settlementKind: 'fiat', details: {'kind': 'fiat', 'fiat': 'nope'}),
      );
    });
  });
}
