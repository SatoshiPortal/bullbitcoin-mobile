import 'package:flutter_test/flutter_test.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:swap_feature/src/ui/swap_router.dart';
import 'package:swap_feature/src/ui/swap_transition_policy.dart';
import 'package:swaps/order_swaps.dart';
import 'package:swaps/swaps.dart';
import 'package:transactions/transactions.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;

void main() {
  final swap = Swap.chain(
    id: 'swap',
    keyIndex: 0,
    type: SwapType.bitcoinToLiquid,
    status: SwapStatus.paid,
    environment: SwapEnvironment.testnet,
    creationTime: DateTime.utc(2026),
    sendWalletId: 'wallet',
    paymentAddress: 'address',
    paymentAmount: 1000,
    sendTxid: 'funding',
  ) as ChainSwap;

  bool succeeded(ChainSwap candidate, {String id = 'swap'}) =>
      swapTransitionSucceeded(
        swapId: id,
        orderId: null,
        swap: candidate,
        order: null,
      );

  WalletTransaction walletTransaction(String txId, {required bool confirmed}) =>
      WalletTransaction(
        walletId: 'receiver',
        network: BitcoinNetwork.testnet,
        direction: WalletTransactionDirection.incoming,
        status: confirmed
            ? WalletTransactionStatus.confirmed
            : WalletTransactionStatus.pending,
        txId: txId,
        amountSat: 1000,
        feeSat: 10,
        vsize: 140,
        inputs: const [],
        outputs: const [],
        isRbf: false,
      );

  group('Boltz chain swap', () {
    const external = ['Sending', 'Sent', 'Claimable', 'Claim broadcast'];
    const owned = [...external, 'Confirmed'];
    final toWallet = swap.copyWith(receiveWalletId: 'receiver');

    BullPaymentProgress progress(
      ChainSwap? candidate, {
      String id = 'swap',
      WalletTransaction? receiveTransaction,
    }) => swapTransitionProgress(
      swapId: id,
      orderId: null,
      swap: candidate,
      order: null,
      steps: candidate?.receiveWalletId == null ? external : owned,
      receiveTransaction: receiveTransaction,
    );

    test('statuses follow the swap fields', () {
      expect(progress(null).completed, 0);
      expect(progress(swap, id: 'other').completed, 0);
      final pending = progress(
        swap.copyWith(status: SwapStatus.pending, sendTxid: null),
      );
      expect(pending.completed, 0);
      expect(pending.currentState, BullPaymentStepState.active);
      final lockup = progress(swap);
      expect(lockup.completed, 1);
      expect(lockup.currentState, BullPaymentStepState.active);
      final claimable = progress(swap.copyWith(status: SwapStatus.claimable));
      expect(claimable.completed, 2);
      expect(claimable.currentState, BullPaymentStepState.active);
      final claim = progress(
        swap.copyWith(status: SwapStatus.claimable, receiveTxid: 'claim'),
      );
      expect(claim.completed, 3);
      expect(claim.currentState, BullPaymentStepState.broadcast);
    });

    test('a completed status without a claim txid is not a broadcast', () {
      expect(
        progress(swap.copyWith(status: SwapStatus.completed)).completed,
        2,
      );
    });

    test('a claim broadcast is not a confirmation', () {
      final claimed = toWallet.copyWith(
        status: SwapStatus.completed,
        receiveTxid: 'claim',
      );
      for (final transaction in [
        null,
        walletTransaction('claim', confirmed: false),
        walletTransaction('other', confirmed: true),
      ]) {
        final result = progress(claimed, receiveTransaction: transaction);
        expect(result.completed, 3);
        expect(result.currentState, BullPaymentStepState.broadcast);
        expect(
          swapTransitionPhase(
            swapId: 'swap',
            orderId: null,
            swap: claimed,
            order: null,
            receiveTransaction: transaction,
          ),
          BullPaymentPhase.sending,
        );
      }
    });

    test('the confirmed receiving transaction completes the swap', () {
      final claimed = toWallet.copyWith(
        status: SwapStatus.completed,
        receiveTxid: 'claim',
      );
      final confirmed = walletTransaction('claim', confirmed: true);
      expect(progress(claimed, receiveTransaction: confirmed).completed, 4);
      expect(
        swapTransitionPhase(
          swapId: 'swap',
          orderId: null,
          swap: claimed,
          order: null,
          receiveTransaction: confirmed,
        ),
        BullPaymentPhase.success,
      );
    });

    test('an external destination ends at the claim broadcast', () {
      final claimed = swap.copyWith(
        status: SwapStatus.completed,
        receiveTxid: 'claim',
      );
      expect(
        swapTransitionPhase(
          swapId: 'swap',
          orderId: null,
          swap: claimed,
          order: null,
        ),
        BullPaymentPhase.success,
      );
      expect(progress(claimed).completed, 3);
    });

    test('a refundable swap offers the refund at the first missed status', () {
      final result = progress(swap.copyWith(status: SwapStatus.refundable));
      expect(result.refund, BullPaymentRefund.available);
      expect(result.failedAt, 2);
      expect(result.completed, 2);
    });

    test('a broadcast refund fails the swap with the refund done', () {
      for (final refunded in [
        swap.copyWith(status: SwapStatus.refunded),
        swap.copyWith(status: SwapStatus.refundable, refundTxid: 'refund'),
      ]) {
        final result = progress(refunded);
        expect(result.refund, BullPaymentRefund.done);
        expect(result.failedAt, 2);
      }
      expect(
        progress(
          swap.copyWith(status: SwapStatus.refunded),
          id: 'other',
        ).refund,
        isNull,
      );
    });

    test('a failure after funding is held, one before it fails', () {
      for (final status in [SwapStatus.failed, SwapStatus.expired]) {
        final held = progress(swap.copyWith(status: status));
        expect(held.currentState, BullPaymentStepState.held);
        expect(held.failedAt, isNull);
        expect(held.completed, 1);
        final unfunded = progress(
          swap.copyWith(status: status, sendTxid: null),
        );
        expect(unfunded.failedAt, 1);
        expect(unfunded.completed, 1);
      }
    });
  });

  test('funding and an unproven completion do not show success', () {
    expect(succeeded(swap), isFalse);
    expect(succeeded(swap.copyWith(status: SwapStatus.completed)), isFalse);
    expect(
      succeeded(swap.copyWith(status: SwapStatus.completed, receiveTxid: '')),
      isFalse,
    );
  });

  test('only the same successfully paid swap can show success', () {
    final paid = swap.copyWith(
      status: SwapStatus.completed,
      receiveTxid: 'payout',
    );
    expect(succeeded(paid), isTrue);
    expect(succeeded(paid, id: 'another'), isFalse);
    expect(succeeded(paid.copyWith(refundTxid: 'refund')), isFalse);
    expect(succeeded(paid.copyWith(status: SwapStatus.refunded)), isFalse);
    expect(succeeded(paid.copyWith(status: SwapStatus.failed)), isFalse);
  });

  test('refunds and funded failures remain provisional until resolved', () {
    BullPaymentPhase phase(ChainSwap candidate) => swapTransitionPhase(
      swapId: 'swap',
      orderId: null,
      swap: candidate,
      order: null,
    );
    expect(
      phase(swap.copyWith(status: SwapStatus.refundable)),
      BullPaymentPhase.sending,
    );
    expect(
      phase(swap.copyWith(status: SwapStatus.failed)),
      BullPaymentPhase.sending,
    );
    expect(
      phase(swap.copyWith(status: SwapStatus.expired)),
      BullPaymentPhase.sending,
    );
    expect(
      phase(swap.copyWith(status: SwapStatus.refunded)),
      BullPaymentPhase.failed,
    );
    expect(
      phase(swap.copyWith(status: SwapStatus.failed, sendTxid: null)),
      BullPaymentPhase.failed,
    );
    expect(
      swapTransitionPhase(
        swapId: 'swap',
        orderId: null,
        swap: swap.copyWith(status: SwapStatus.failed, sendTxid: null),
        order: null,
        fundingTxId: 'funding',
      ),
      BullPaymentPhase.sending,
    );
  });

  test('a late cross-chain funding txid cannot take over navigation', () {
    const before = TransferState(sendToExternal: true);
    const after = TransferState(sendToExternal: true, txId: 'funding');
    expect(shouldNavigateOnTransferBroadcast(before, after), isFalse);
  });

  test('exchange progress follows the durable order and its payout', () {
    OrderSwapRecord order(
      String id,
      OrderSwapLocalStatus status, {
      bool review = false,
    }) => OrderSwapRecord(
      localId: id,
      purpose: OrderSwapPurpose.transfer,
      environment: OrderSwapEnvironment.testnet,
      inNetwork: OrderSwapNetwork.bitcoin,
      outNetwork: OrderSwapNetwork.liquid,
      isInAmountFixed: true,
      requestedAmountSat: BigInt.from(1000),
      destination: 'destination',
      fallback: 'fallback',
      createdAt: DateTime.utc(2026),
      localStatus: status,
      order: OrderSwap(
        orderId: 'server-$id',
        orderNumber: 1,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.liquid,
        payinAmountSat: BigInt.from(1000),
        payoutAmountSat: BigInt.from(990),
        payinCurrency: 'BTC',
        payoutCurrency: 'L-BTC',
        payinMethod: 'bitcoin',
        payoutMethod: 'liquid',
        orderType: 'swap',
        orderStatus: status.name,
        payinStatus: review
            ? 'under review'
            : status == OrderSwapLocalStatus.broadcastUnknown
            ? 'pending'
            : 'completed',
        payoutStatus: status.name,
        messageCode: '',
        liquidAddress: 'destination',
        createdAt: DateTime.utc(2026),
        confirmationDeadline: DateTime.utc(2026, 1, 2),
      ),
      signedPayinTransaction: 'signed',
      payinIsPsbt: true,
      localPayinTransactionId: status == OrderSwapLocalStatus.payinBroadcast
          ? 'funding'
          : null,
    );
    final paid = swap.copyWith(status: SwapStatus.completed);
    bool check(OrderSwapRecord candidate) => swapTransitionSucceeded(
      swapId: 'swap',
      orderId: 'order',
      swap: paid,
      order: candidate,
    );
    expect(check(order('order', OrderSwapLocalStatus.completed)), isTrue);
    expect(check(order('other', OrderSwapLocalStatus.completed)), isFalse);
    expect(
      check(order('order', OrderSwapLocalStatus.broadcastUnknown)),
      isFalse,
    );
    expect(check(order('order', OrderSwapLocalStatus.refunded)), isFalse);
    BullPaymentProgress progress(
      OrderSwapRecord candidate, {
      ChainSwap? chain,
    }) {
      final target = chain ?? paid;
      return swapTransitionProgress(
        swapId: 'swap',
        orderId: 'order',
        swap: target,
        order: candidate,
        steps: target.receiveWalletId == null
            ? const ['Sending', 'Payin', 'Payout', 'Completed']
            : const ['Sending', 'Payin', 'Payout', 'Broadcast', 'Confirmed'],
      );
    }

    expect(
      progress(order('other', OrderSwapLocalStatus.completed)).completed,
      0,
    );
    final unknown = progress(
      order('order', OrderSwapLocalStatus.broadcastUnknown),
    );
    expect(unknown.completed, 0);
    expect(unknown.currentState, BullPaymentStepState.held);
    final payin = progress(order('order', OrderSwapLocalStatus.payinBroadcast));
    expect(payin.completed, 1);
    expect(payin.currentState, BullPaymentStepState.broadcast);
    final payout = progress(
      order('order', OrderSwapLocalStatus.payoutInProgress),
    );
    expect(payout.completed, 2);
    expect(payout.currentState, BullPaymentStepState.active);
    expect(
      progress(order('order', OrderSwapLocalStatus.completed)).completed,
      3,
    );
    final refunded = progress(order('order', OrderSwapLocalStatus.refunded));
    expect(refunded.failedAt, 1);
    expect(refunded.refund, BullPaymentRefund.done);
    final failed = progress(
      order('order', OrderSwapLocalStatus.failed),
      chain: swap.copyWith(status: SwapStatus.failed, sendTxid: null),
    );
    expect(failed.failedAt, 1);
    expect(failed.refund, isNull);
    expect(
      progress(
        order('order', OrderSwapLocalStatus.payoutInProgress, review: true),
      ).currentState,
      BullPaymentStepState.held,
    );

    // A payout the receiving wallet can watch.
    final toWallet = paid.copyWith(
      receiveWalletId: 'receiver',
      receiveTxid: 'payout',
    );
    final record = order('order', OrderSwapLocalStatus.completed);
    BullPaymentProgress ownedProgress(
      ChainSwap candidate,
      OrderSwapRecord current, [
      WalletTransaction? transaction,
    ]) => swapTransitionProgress(
      swapId: 'swap',
      orderId: 'order',
      swap: candidate,
      order: current,
      steps: const ['Sending', 'Payin', 'Payout', 'Broadcast', 'Confirmed'],
      receiveTransaction: transaction,
    );
    final broadcast = ownedProgress(
      toWallet,
      order('order', OrderSwapLocalStatus.payoutInProgress),
    );
    expect(broadcast.completed, 3);
    expect(broadcast.currentState, BullPaymentStepState.broadcast);
    final unconfirmed = ownedProgress(
      toWallet,
      record,
      walletTransaction('payout', confirmed: false),
    );
    expect(unconfirmed.completed, 3);
    expect(unconfirmed.currentState, BullPaymentStepState.broadcast);
    expect(
      swapTransitionSucceeded(
        swapId: 'swap',
        orderId: 'order',
        swap: toWallet,
        order: record,
        receiveTransaction: walletTransaction('payout', confirmed: false),
      ),
      isFalse,
    );
    expect(
      swapTransitionSucceeded(
        swapId: 'swap',
        orderId: 'order',
        swap: toWallet,
        order: record,
        receiveTransaction: walletTransaction('payout', confirmed: true),
      ),
      isTrue,
    );
    final withoutTxid = ownedProgress(
      paid.copyWith(receiveWalletId: 'receiver'),
      record,
    );
    expect(withoutTxid.completed, 2);
    expect(withoutTxid.currentState, BullPaymentStepState.held);
  });
}
