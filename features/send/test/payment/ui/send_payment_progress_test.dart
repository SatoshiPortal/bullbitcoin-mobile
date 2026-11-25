import 'package:send/src/payment/ui/screens/send_payment_animation_policy.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swaps/order_swaps.dart';
import 'package:swaps/swaps.dart';

void main() {
  const four = ['Lockup', 'Sent', 'Third', 'Last'];
  final ln = Swap.lnSend(
    id: 'ln',
    keyIndex: 0,
    type: SwapType.bitcoinToLightning,
    status: SwapStatus.pending,
    environment: SwapEnvironment.testnet,
    creationTime: DateTime.utc(2026),
    sendWalletId: 'w',
    invoice: 'invoice',
    paymentAddress: 'address',
    paymentAmount: 1000,
  ) as LnSendSwap;
  final chain = Swap.chain(
    id: 'chain',
    keyIndex: 0,
    type: SwapType.bitcoinToLiquid,
    status: SwapStatus.pending,
    environment: SwapEnvironment.testnet,
    creationTime: DateTime.utc(2026),
    sendWalletId: 'w',
    paymentAddress: 'address',
    paymentAmount: 1000,
  ) as ChainSwap;
  BullPaymentProgress progress(Swap? swap) =>
      boltzPaymentProgress(steps: four, swap: swap);

  Swap withStatus(
    Swap swap,
    SwapStatus status, {
    String? sendTxid,
    String? receiveTxid,
    String? refundTxid,
    DateTime? completionTime,
  }) => switch (swap) {
    LnSendSwap() => swap.copyWith(
      status: status,
      sendTxid: sendTxid,
      refundTxid: refundTxid,
      completionTime: completionTime,
    ),
    ChainSwap() => swap.copyWith(
      status: status,
      sendTxid: sendTxid,
      receiveTxid: receiveTxid,
      refundTxid: refundTxid,
    ),
    _ => swap,
  };

  test('submarine statuses follow lockup, invoice and preimage proof', () {
    expect(progress(null).completed, 0);
    expect(progress(ln).completed, 0);
    expect(progress(ln.copyWith(pendingLockupTxid: 'uncertain')).completed, 0);
    expect(progress(ln.copyWith(sendTxid: 'tx')).completed, 1);
    expect(progress(ln.copyWith(status: SwapStatus.paid)).completed, 1);
    expect(
      progress(
        ln.copyWith(
          status: SwapStatus.paid,
          completionTime: DateTime.utc(2026),
        ),
      ).completed,
      2,
    );
    expect(progress(ln.copyWith(status: SwapStatus.canCoop)).completed, 2);
    expect(progress(ln.copyWith(status: SwapStatus.completed)).completed, 3);
    for (final status in [
      SwapStatus.pending,
      SwapStatus.paid,
      SwapStatus.canCoop,
      SwapStatus.completed,
    ]) {
      final p = progress(ln.copyWith(status: status));
      expect(p.currentState, BullPaymentStepState.active, reason: status.name);
      expect(p.failedAt, isNull, reason: status.name);
      expect(p.refund, isNull, reason: status.name);
    }
  });

  test('chain statuses end at the claim broadcast', () {
    expect(progress(chain).completed, 0);
    expect(progress(chain.copyWith(status: SwapStatus.paid)).completed, 1);
    expect(progress(chain.copyWith(sendTxid: 'tx')).completed, 1);
    expect(progress(chain.copyWith(status: SwapStatus.claimable)).completed, 2);
    expect(progress(chain.copyWith(status: SwapStatus.completed)).completed, 2);
    final broadcast = progress(
      chain.copyWith(status: SwapStatus.claimable, receiveTxid: 'claim'),
    );
    expect(broadcast.completed, 3);
    expect(broadcast.currentState, BullPaymentStepState.broadcast);
    final completed = progress(
      chain.copyWith(status: SwapStatus.completed, receiveTxid: 'claim'),
    );
    expect(completed.completed, 3);
    expect(completed.currentState, BullPaymentStepState.broadcast);
    expect(completed.failedAt, isNull);
    expect(completed.refund, isNull);
  });

  test('funds that moved wait for a refund and keep the payment sending', () {
    for (final swap in <Swap>[ln, chain]) {
      for (final status in [
        SwapStatus.refundable,
        SwapStatus.failed,
        SwapStatus.expired,
      ]) {
        final p = progress(withStatus(swap, status, sendTxid: 'tx'));
        expect(p.completed, 1, reason: '${swap.runtimeType} ${status.name}');
        expect(p.failedAt, 2, reason: '${swap.runtimeType} ${status.name}');
        expect(
          p.refund,
          BullPaymentRefund.available,
          reason: '${swap.runtimeType} ${status.name}',
        );
      }
      // A swap Boltz refunds itself still holds our lockup.
      final refundable = progress(withStatus(swap, SwapStatus.refundable));
      expect(refundable.failedAt, 2);
      expect(refundable.refund, BullPaymentRefund.available);
    }
    final invoicePaidThenFailed = progress(
      withStatus(
        ln,
        SwapStatus.failed,
        sendTxid: 'tx',
        completionTime: DateTime.utc(2026),
      ),
    );
    expect(invoicePaidThenFailed.completed, 1);
    final claimableThenExpired = progress(
      withStatus(chain, SwapStatus.expired, sendTxid: 'tx'),
    );
    expect(claimableThenExpired.failedAt, 2);
  });

  test('a broadcast refund ends the payment with the refund done', () {
    for (final swap in <Swap>[ln, chain]) {
      for (final p in [
        progress(
          withStatus(
            swap,
            SwapStatus.refunded,
            sendTxid: 'tx',
            refundTxid: 'refund',
          ),
        ),
        progress(withStatus(swap, SwapStatus.refunded)),
        progress(
          withStatus(
            swap,
            SwapStatus.refundable,
            sendTxid: 'tx',
            refundTxid: 'refund',
          ),
        ),
      ]) {
        expect(p.refund, BullPaymentRefund.done, reason: '${swap.runtimeType}');
        expect(p.completed, 2, reason: '${swap.runtimeType}');
        expect(p.failedAt, 2, reason: '${swap.runtimeType}');
      }
    }
  });

  test('failure before any lockup left is final and refunds nothing', () {
    for (final swap in <Swap>[ln, chain]) {
      for (final status in [SwapStatus.failed, SwapStatus.expired]) {
        final p = progress(withStatus(swap, status));
        expect(p.completed, 1, reason: status.name);
        expect(p.failedAt, 1, reason: status.name);
        expect(p.refund, isNull, reason: status.name);
        expect(
          boltzPaymentPhase(withStatus(swap, status)),
          BullPaymentPhase.failed,
        );
      }
    }
  });

  test('an unknown lockup broadcast is not treated as nothing moved', () {
    final uncertain = ln.copyWith(
      status: SwapStatus.failed,
      pendingLockupTx: 'raw',
      pendingLockupTxid: 'uncertain',
    );
    expect(progress(uncertain).refund, BullPaymentRefund.available);
    expect(boltzPaymentPhase(uncertain), isNull);
  });

  test('Boltz phase needs the proof of the last status', () {
    expect(boltzPaymentPhase(ln), isNull);
    expect(boltzPaymentPhase(chain), isNull);
    expect(
      boltzPaymentPhase(ln.copyWith(status: SwapStatus.completed)),
      BullPaymentPhase.success,
    );
    // Boltz writes completed when the claim is broadcast, not before the
    // destination transaction is known.
    expect(
      boltzPaymentPhase(chain.copyWith(status: SwapStatus.completed)),
      isNull,
    );
    expect(
      boltzPaymentPhase(
        chain.copyWith(status: SwapStatus.completed, receiveTxid: 'claim'),
      ),
      BullPaymentPhase.success,
    );
    for (final swap in <Swap>[ln, chain]) {
      for (final status in [SwapStatus.refundable, SwapStatus.failed]) {
        expect(
          boltzPaymentPhase(withStatus(swap, status, sendTxid: 'tx')),
          isNull,
          reason: status.name,
        );
      }
      expect(
        boltzPaymentPhase(withStatus(swap, SwapStatus.refunded)),
        BullPaymentPhase.failed,
      );
      expect(
        boltzPaymentPhase(
          withStatus(swap, SwapStatus.completed, refundTxid: 'refund'),
        ),
        BullPaymentPhase.failed,
      );
    }
  });

  test('direct send is in one status at a time', () {
    const steps = ['Signing', 'Broadcasted', 'Confirmed'];
    final signing = directPaymentProgress(
      steps: steps,
      broadcast: false,
      failed: false,
    );
    expect(signing.current, 0);
    expect(signing.currentState, BullPaymentStepState.active);

    final broadcast = directPaymentProgress(
      steps: steps,
      broadcast: true,
      failed: false,
    );
    expect(broadcast.current, 1);
    expect(broadcast.currentState, BullPaymentStepState.broadcast);
    // Broadcast is never the full completion: Confirmed is still ahead.
    expect(broadcast.isComplete, isFalse);

    final failed = directPaymentProgress(
      steps: steps,
      broadcast: false,
      failed: true,
    );
    // Stopped before the broadcast status was reached.
    expect(failed.failedAt, 1);
  });

  test('each exchange status has evidence-based progress', () {
    const steps = ['Sending', 'Payin', 'Payout', 'Completed'];
    for (final status in OrderSwapLocalStatus.values) {
      final p = orderPaymentProgress(steps: steps, status: status);
      final expected = switch (status) {
        OrderSwapLocalStatus.payinBroadcast => 1,
        OrderSwapLocalStatus.payoutInProgress => 2,
        OrderSwapLocalStatus.completed => 3,
        OrderSwapLocalStatus.refunded ||
        OrderSwapLocalStatus.failed ||
        OrderSwapLocalStatus.expired => 1,
        _ => 0,
      };
      expect(p.completed, expected, reason: status.name);
      expect(
        p.failedAt != null,
        status == OrderSwapLocalStatus.failed ||
            status == OrderSwapLocalStatus.expired ||
            status == OrderSwapLocalStatus.refunded,
        reason: status.name,
      );
    }
  });

  test('exchange payin broadcast waits for its payout', () {
    const steps = ['Sending', 'Payin', 'Payout', 'Completed'];
    final broadcast = orderPaymentProgress(
      steps: steps,
      status: OrderSwapLocalStatus.payinBroadcast,
      payinTxid: 'tx',
    );
    expect(broadcast.completed, 1);
    expect(broadcast.currentState, BullPaymentStepState.broadcast);
    final review = orderPaymentProgress(
      steps: steps,
      status: OrderSwapLocalStatus.payinBroadcast,
      payinTxid: 'tx',
      underReview: true,
    );
    expect(review.completed, 1);
    expect(review.currentState, BullPaymentStepState.held);
    expect(review.failedAt, isNull);
    final payout = orderPaymentProgress(
      steps: steps,
      status: OrderSwapLocalStatus.payoutInProgress,
      payinTxid: 'tx',
    );
    expect(payout.completed, 2);
    expect(payout.currentState, BullPaymentStepState.active);
  });

  test('an unknown payin broadcast is held, never failed', () {
    final p = orderPaymentProgress(
      steps: const ['Sending', 'Payin', 'Payout', 'Completed'],
      status: OrderSwapLocalStatus.broadcastUnknown,
      payinTxid: 'uncertain',
    );
    expect(p.completed, 0);
    expect(p.currentState, BullPaymentStepState.held);
    expect(p.failedAt, isNull);
  });

  test('failed exchange orders hold, are refunded, or stop by funds moved', () {
    const steps = ['Sending', 'Payin', 'Payout', 'Completed'];
    for (final status in [
      OrderSwapLocalStatus.failed,
      OrderSwapLocalStatus.expired,
    ]) {
      final moved = orderPaymentProgress(
        steps: steps,
        status: status,
        payinTxid: 'tx',
      );
      expect(moved.completed, 1, reason: status.name);
      expect(moved.currentState, BullPaymentStepState.held);
      expect(moved.failedAt, isNull, reason: status.name);
      final none = orderPaymentProgress(steps: steps, status: status);
      expect(none.completed, 1, reason: status.name);
      expect(none.failedAt, 1, reason: status.name);
      expect(none.currentState, BullPaymentStepState.active);
    }
    final refunded = orderPaymentProgress(
      steps: steps,
      status: OrderSwapLocalStatus.refunded,
      payinTxid: 'tx',
    );
    expect(refunded.refund, BullPaymentRefund.done);
    expect(refunded.completed, 2);
    expect(refunded.failedAt, 2);
  });

  test('Payjoin statuses follow the session until the broadcast', () {
    const steps = ['Requested', 'Proposed', 'Broadcasted', 'Confirmed'];
    for (final status in PayjoinStatus.values) {
      final p = payjoinPaymentProgress(steps: steps, status: status);
      expect(p.completed, switch (status) {
        PayjoinStatus.proposed => 1,
        PayjoinStatus.completed || PayjoinStatus.aborted => 2,
        PayjoinStatus.expired => 0,
        _ => 0,
      }, reason: status.name);
      expect(p.currentState, switch (status) {
        PayjoinStatus.completed ||
        PayjoinStatus.aborted => BullPaymentStepState.broadcast,
        PayjoinStatus.expired => BullPaymentStepState.held,
        _ => BullPaymentStepState.active,
      }, reason: status.name);
      expect(p.failedAt, isNull, reason: status.name);
      expect(p.skippedAt, status == PayjoinStatus.aborted ? 1 : null);
    }
  });

  test('a paused Payjoin session is held at the status it reached', () {
    const steps = ['Requested', 'Proposed', 'Broadcasted', 'Confirmed'];
    for (final status in [PayjoinStatus.requested, PayjoinStatus.proposed]) {
      final p = payjoinPaymentProgress(
        steps: steps,
        status: status,
        paused: true,
      );
      expect(p.currentState, BullPaymentStepState.held, reason: status.name);
      expect(p.completed, status == PayjoinStatus.proposed ? 1 : 0);
    }
  });

  test('expired Payjoin is held unless nothing was broadcast', () {
    const steps = ['Requested', 'Proposed', 'Broadcasted', 'Confirmed'];
    final held = payjoinPaymentProgress(
      steps: steps,
      status: PayjoinStatus.expired,
      previousCompleted: 1,
    );
    expect(held.completed, 1);
    expect(held.currentState, BullPaymentStepState.held);
    expect(held.failedAt, isNull);
    final failed = payjoinPaymentProgress(
      steps: steps,
      status: PayjoinStatus.expired,
      expiredWithoutBroadcast: true,
    );
    expect(failed.completed, 1);
    expect(failed.failedAt, 1);
  });

  test('Payjoin succeeds only once its settled transaction is confirmed', () {
    for (final status in [PayjoinStatus.completed, PayjoinStatus.aborted]) {
      expect(payjoinPaymentPhase(status), BullPaymentPhase.sending);
      expect(
        payjoinPaymentPhase(status, confirmed: true),
        BullPaymentPhase.success,
      );
    }
    expect(
      payjoinPaymentPhase(PayjoinStatus.proposed, confirmed: true),
      BullPaymentPhase.sending,
    );
    expect(
      payjoinPaymentPhase(PayjoinStatus.expired),
      BullPaymentPhase.sending,
    );
    expect(
      payjoinPaymentPhase(PayjoinStatus.expired, expiredWithoutBroadcast: true),
      BullPaymentPhase.failed,
    );
  });
}
