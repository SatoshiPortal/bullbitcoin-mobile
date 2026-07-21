import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/features/bullnym/data/bullnym_get_paid_transaction_mapper.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_get_paid_transaction_model.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_fiat_settlement.dart';
import 'package:flutter_test/flutter_test.dart';

// Contract conformance: the canonical version-one fixtures shipped by the
// server (Bullnym) must parse through the REAL mobile model + settlement parser
// without any field name, enum string, null, or array shape being rewritten in
// the test. The fixture file is copied byte-for-byte from the server repo.
void main() {
  test('parses the canonical settlement fixtures through the real model', () {
    final raw = File(
      'test/features/bullnym/fixtures/get-paid-transactions-settlement-v1.json',
    ).readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final page = BullnymGetPaidTransactionPageModel.fromJson(json);
    final domain = page.transactions.map((m) => m.toDomain()).toList();

    // Every fixture transaction is a valid receipt.
    expect(domain.length, 6);
    expect(page.nextCursor, isNull);

    // tx1 — explicit Bitcoin, no details, no override.
    final btc = domain[0].settlement!;
    expect(btc.kind, BullnymSettlementKind.bitcoin);
    expect(btc.overrideReason, isNull);
    expect(btc.fiat, isEmpty);
    expect(btc.bitcoin, isEmpty);

    // tx2 — Bitcoin with a below-minimum conversion override.
    final overridden = domain[1].settlement!;
    expect(overridden.kind, BullnymSettlementKind.bitcoin);
    expect(
      overridden.overrideReason,
      BullnymFiatConversionOverrideReason.belowMinimum,
    );

    // tx3 — fiat, single pending leg with a null amount.
    final fiatPending = domain[2].settlement!;
    expect(fiatPending.kind, BullnymSettlementKind.fiat);
    expect(fiatPending.bitcoin, isEmpty);
    final pendingLeg = fiatPending.fiat.single;
    expect(pendingLeg.status, BullnymSettlementLegStatus.pending);
    expect(pendingLeg.amountMinor, isNull);
    expect(pendingLeg.currency, 'EUR');
    expect(pendingLeg.orderId, '40000000-0000-4000-8000-000000000003');

    // tx4 — fiat, single settled leg carrying the final minor amount.
    final fiatSettled = domain[3].settlement!;
    expect(fiatSettled.kind, BullnymSettlementKind.fiat);
    final settledLeg = fiatSettled.fiat.single;
    expect(settledLeg.status, BullnymSettlementLegStatus.settled);
    expect(settledLeg.amountMinor, 12345);
    expect(settledLeg.currency, 'CAD');

    // tx5 — mixed, one settled Liquid Bitcoin leg and one settled fiat leg.
    final mixed = domain[4].settlement!;
    expect(mixed.kind, BullnymSettlementKind.mixed);
    final btcLeg = mixed.bitcoin.single;
    expect(btcLeg.amountSat, 60000);
    expect(btcLeg.network, 'liquid');
    expect(btcLeg.status, BullnymSettlementLegStatus.settled);
    expect(mixed.fiat.single.amountMinor, 12345);
    expect(mixed.fiat.single.currency, 'CAD');

    // tx6 — server-sent unavailable, carrying no details or override.
    final unavailable = domain[5].settlement!;
    expect(unavailable.kind, BullnymSettlementKind.unavailable);
    expect(unavailable.fiat, isEmpty);
    expect(unavailable.bitcoin, isEmpty);
    expect(unavailable.overrideReason, isNull);
  });
}
