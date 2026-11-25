import 'package:send/src/payment/ui/screens/send_payment_animation_policy.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swaps/order_swaps.dart';

void main() {
  test('funded failed and expired orders remain provisional', () {
    for (final status in OrderSwapLocalStatus.values) {
      for (final funded in [false, true]) {
        final expected = switch (status) {
          OrderSwapLocalStatus.completed => BullPaymentPhase.success,
          OrderSwapLocalStatus.refunded => BullPaymentPhase.failed,
          OrderSwapLocalStatus.failed ||
          OrderSwapLocalStatus.expired when !funded => BullPaymentPhase.failed,
          _ => null,
        };
        expect(
          orderPaymentPhase(status, hasFundsMoved: funded),
          expected,
          reason: '${status.name}, funded=$funded',
        );
      }
    }
  });

  test('direct broadcast excludes old txids, swaps, and Payjoin', () {
    bool result({
      bool swap = false,
      String? old,
      String? tx,
      bool pj = false,
    }) => directPaymentBroadcast(
      expectsSwap: swap,
      previousTxId: old,
      transactionId: tx,
      hasPayjoin: pj,
    );
    expect(result(tx: 'new'), isTrue);
    expect(result(), isFalse);
    expect(result(old: 'old', tx: 'old'), isFalse);
    expect(result(swap: true, tx: 'new'), isFalse);
    expect(result(pj: true, tx: 'new'), isFalse);
  });

  test('direct success needs the confirmation of its own transaction', () {
    bool result({
      bool broadcast = true,
      String? tx = 'new',
      String? observed,
      bool confirmed = false,
    }) => directPaymentSucceeded(
      broadcast: broadcast,
      transactionId: tx,
      observedTransactionId: observed,
      observedConfirmed: confirmed,
    );
    // A txid alone proves the broadcast, never the confirmation.
    expect(result(), isFalse);
    expect(result(observed: 'new'), isFalse);
    expect(result(observed: 'new', confirmed: true), isTrue);
    // Another transaction confirming says nothing about this payment.
    expect(result(observed: 'other', confirmed: true), isFalse);
    expect(result(broadcast: false, observed: 'new', confirmed: true), isFalse);
  });
}
