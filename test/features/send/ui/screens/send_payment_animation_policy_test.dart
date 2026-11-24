import 'package:bb_mobile/features/send/ui/screens/send_payment_animation_policy.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swaps/order_swaps.dart';
import 'package:swaps/swaps.dart';

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

  test('Boltz needs settlement proof and refundable stays pending', () {
    for (final status in SwapStatus.values) {
      for (final proven in [false, true]) {
        final expected = switch (status) {
          SwapStatus.completed when proven => BullPaymentPhase.success,
          SwapStatus.refunded => BullPaymentPhase.failed,
          _ => null,
        };
        expect(
          boltzPaymentPhase(status, refunded: false, completedProven: proven),
          expected,
          reason: '${status.name}, proven=$proven',
        );
        expect(
          boltzPaymentPhase(status, refunded: true, completedProven: proven),
          BullPaymentPhase.failed,
          reason: status.name,
        );
      }
    }
  });

  test('direct success excludes old txids, swaps, and Payjoin', () {
    bool result({
      bool swap = false,
      String? old,
      String? tx,
      bool pj = false,
    }) => directPaymentSucceeded(
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
}
