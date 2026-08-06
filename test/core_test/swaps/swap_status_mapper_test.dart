import 'package:bb_mobile/core/swaps/data/models/swap_model.dart';
import 'package:bb_mobile/core/swaps/data/services/swap_status_mapper.dart';
import 'package:bull_sdk/boltz.dart' as boltz;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = SwapStatusMapper();
  final now = DateTime(2026, 6, 12, 12);
  final fresh = now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
  final ancient = now.subtract(const Duration(days: 20)).millisecondsSinceEpoch;

  LnReceiveSwapModel lnReceive({
    String status = 'pending',
    String type = 'lightningToLiquid',
    String? receiveTxid,
    bool wasDirectPayment = false,
    int? creationTime,
  }) => LnReceiveSwapModel(
    id: 'rcv123456789',
    type: type,
    status: status,
    keyIndex: 0,
    creationTime: creationTime ?? fresh,
    receiveWalletId: 'w1',
    invoice: 'lnbc1...',
    receiveTxid: receiveTxid,
    wasDirectPayment: wasDirectPayment,
  );

  LnSendSwapModel lnSend({
    String status = 'pending',
    String type = 'liquidToLightning',
    String? sendTxid,
    String? refundTxid,
    int? creationTime,
  }) => LnSendSwapModel(
    id: 'snd123456789',
    type: type,
    status: status,
    keyIndex: 0,
    creationTime: creationTime ?? fresh,
    sendWalletId: 'w1',
    invoice: 'lnbc1...',
    paymentAddress: 'lq1...',
    paymentAmount: 10000,
    sendTxid: sendTxid,
    refundTxid: refundTxid,
  );

  ChainSwapModel chain({
    String status = 'pending',
    String type = 'liquidToBitcoin',
    String? sendTxid,
    String? receiveTxid,
    String? refundTxid,
  }) => ChainSwapModel(
    id: 'chn123456789',
    type: type,
    status: status,
    keyIndex: 0,
    creationTime: fresh,
    sendWalletId: 'w1',
    paymentAddress: 'lq1...',
    paymentAmount: 100000,
    sendTxid: sendTxid,
    receiveTxid: receiveTxid,
    refundTxid: refundTxid,
  );

  SwapStatusMapping map(
    SwapModel swap,
    boltz.SwapStatus status, {
    String? txid,
  }) => mapper.map(
    swap: swap,
    boltzStatus: status,
    transactionId: txid,
    now: now,
  );

  String statusOf(SwapStatusMapping m) => (m as SwapUpdated).swap.status;

  group('reverse swap (LnReceive) lifecycle', () {
    test('liquid lockup in mempool becomes claimable (0-conf)', () {
      final result = map(lnReceive(), boltz.SwapStatus.txnMempool);
      expect(statusOf(result), 'claimable');
    });

    test('bitcoin lockup in mempool only becomes paid', () {
      final result = map(
        lnReceive(type: 'lightningToBitcoin'),
        boltz.SwapStatus.txnMempool,
      );
      expect(statusOf(result), 'paid');
    });

    test('bitcoin lockup confirmed becomes claimable', () {
      final result = map(
        lnReceive(type: 'lightningToBitcoin', status: 'paid'),
        boltz.SwapStatus.txnConfirmed,
      );
      expect(statusOf(result), 'claimable');
    });

    test('invoice settled without claim txid stays claimable', () {
      final result = map(
        lnReceive(status: 'claimable'),
        boltz.SwapStatus.invoiceSettled,
      );
      expect(result, isA<SwapUnchanged>());
    });

    test('invoice settled with claim txid completes', () {
      final result = map(
        lnReceive(status: 'claimable', receiveTxid: 'tx1'),
        boltz.SwapStatus.invoiceSettled,
      );
      expect(statusOf(result), 'completed');
    });

    test('boltz refunding itself fails the reverse swap', () {
      final result = map(
        lnReceive(status: 'paid'),
        boltz.SwapStatus.txnRefunded,
      );
      expect(statusOf(result), 'failed');
    });

    test('boltz lockup failure fails the swap (no user funds at risk)', () {
      final result = map(lnReceive(), boltz.SwapStatus.txnFailed);
      expect(statusOf(result), 'failed');
    });
  });

  group('MRH direct payments', () {
    test('transaction.direct with txid completes and marks direct', () {
      final result = map(
        lnReceive(),
        boltz.SwapStatus.txnDirect,
        txid: 'direct-tx',
      );
      final updated = (result as SwapUpdated).swap as LnReceiveSwapModel;
      expect(updated.status, 'completed');
      expect(updated.receiveTxid, 'direct-tx');
      expect(updated.wasDirectPayment, isTrue);
    });

    test('transaction.direct without txid holds at paid, never completed', () {
      final result = map(lnReceive(), boltz.SwapStatus.txnDirect);
      final updated = (result as SwapUpdated).swap as LnReceiveSwapModel;
      expect(updated.status, 'paid');
      expect(updated.wasDirectPayment, isTrue);
      expect(updated.receiveTxid, isNull);
    });

    test('direct payment held at paid is immune to the trailing expiry', () {
      // Boltz ends the MRH lifecycle with swap.expired — the user was paid
      // on-chain, so expiry must not relabel the swap.
      final result = map(
        lnReceive(status: 'paid', wasDirectPayment: true),
        boltz.SwapStatus.swapExpired,
      );
      expect(result, isA<SwapUnchanged>());
    });

    test('completed direct payment is immune to the trailing expiry', () {
      final result = map(
        lnReceive(
          status: 'completed',
          receiveTxid: 'direct-tx',
          wasDirectPayment: true,
        ),
        boltz.SwapStatus.swapExpired,
      );
      expect(result, isA<SwapUnchanged>());
    });

    test('completed direct payment can not be reopened to claimable', () {
      final result = map(
        lnReceive(status: 'completed', wasDirectPayment: true),
        boltz.SwapStatus.invoiceSettled,
      );
      expect(result, isNot(isA<SwapUpdated>()));
    });
  });

  group('submarine swap (LnSend) lifecycle', () {
    test('invoice.paid is persisted as paid with completion time', () {
      final swap = lnSend(status: 'paid', sendTxid: 'lockup-tx');
      final result = map(swap, boltz.SwapStatus.invoicePaid);
      final updated = (result as SwapUpdated).swap as LnSendSwapModel;
      expect(updated.status, 'paid');
      expect(updated.completionTime, isNotNull);
    });

    test('claim pending asks for coop close', () {
      final result = map(
        lnSend(status: 'paid', sendTxid: 'tx'),
        boltz.SwapStatus.txnClaimPending,
      );
      expect(statusOf(result), 'canCoop');
    });

    test('transaction claimed completes the send swap', () {
      final result = map(
        lnSend(status: 'canCoop', sendTxid: 'tx'),
        boltz.SwapStatus.txnClaimed,
      );
      expect(statusOf(result), 'completed');
    });

    test('failed invoice with locked funds becomes refundable', () {
      final result = map(
        lnSend(status: 'paid', sendTxid: 'tx'),
        boltz.SwapStatus.invoiceFailedToPay,
      );
      expect(statusOf(result), 'refundable');
    });

    test('failed invoice already refunded becomes refunded', () {
      final result = map(
        lnSend(status: 'refundable', sendTxid: 'tx', refundTxid: 'rtx'),
        boltz.SwapStatus.invoiceFailedToPay,
      );
      expect(statusOf(result), 'refunded');
    });

    test('failed invoice without lockup fails outright', () {
      final result = map(lnSend(), boltz.SwapStatus.invoiceFailedToPay);
      expect(statusOf(result), 'failed');
    });

    test('expiry with locked funds becomes refundable, not expired', () {
      final result = map(
        lnSend(status: 'paid', sendTxid: 'tx'),
        boltz.SwapStatus.swapExpired,
      );
      expect(statusOf(result), 'refundable');
    });

    test('expiry without funds becomes expired', () {
      final result = map(lnSend(), boltz.SwapStatus.swapExpired);
      expect(statusOf(result), 'expired');
    });
  });

  group('chain swap lifecycle', () {
    test('server lockup mempool is claimable when receiving liquid', () {
      final result = map(
        chain(type: 'bitcoinToLiquid', status: 'paid', sendTxid: 'tx'),
        boltz.SwapStatus.txnServerMempool,
      );
      expect(statusOf(result), 'claimable');
    });

    test('server lockup mempool is only paid when receiving bitcoin', () {
      final result = map(
        chain(status: 'paid', sendTxid: 'tx'),
        boltz.SwapStatus.txnServerMempool,
      );
      expect(result, isA<SwapUnchanged>());
    });

    test('server lockup confirmed is claimable when receiving bitcoin', () {
      final result = map(
        chain(status: 'paid', sendTxid: 'tx'),
        boltz.SwapStatus.txnServerConfirmed,
      );
      expect(statusOf(result), 'claimable');
    });

    test('lockup failed with funds becomes refundable', () {
      final result = map(
        chain(status: 'paid', sendTxid: 'tx'),
        boltz.SwapStatus.txnLockupFailed,
      );
      expect(statusOf(result), 'refundable');
    });

    test('boltz claimed but no local claim txid reopens claimable', () {
      final result = map(
        chain(status: 'paid', sendTxid: 'tx'),
        boltz.SwapStatus.txnClaimed,
      );
      expect(statusOf(result), 'claimable');
    });

    // claimable and refundable are both action states (rank 2): a chain swap
    // reopened to claimable can still self-correct to refundable when Boltz
    // reports the lockup failed, so the refund path is never blocked.
    test('claimable chain swap reroutes to refundable on lockup failure', () {
      final result = map(
        chain(status: 'claimable', sendTxid: 'tx'),
        boltz.SwapStatus.txnLockupFailed,
      );
      expect(statusOf(result), 'refundable');
    });
  });

  group('stranded funds recovery', () {
    test('locally expired swap with locked funds can become refundable', () {
      final result = map(
        lnSend(status: 'expired', sendTxid: 'tx'),
        boltz.SwapStatus.txnLockupFailed,
      );
      expect(statusOf(result), 'refundable');
    });

    test('locally failed chain swap with locked funds can refund', () {
      final result = map(
        chain(status: 'failed', sendTxid: 'tx'),
        boltz.SwapStatus.swapExpired,
      );
      expect(statusOf(result), 'refundable');
    });

    // A chain swap wedged as "completed" by a bogus outspend recovery has its
    // receiveTxid retracted at startup; from there Boltz's own refund event
    // must be able to route the still-locked user funds to the refund path.
    test(
        'unproven completed chain swap with locked funds becomes refundable '
        'on boltz refund', () {
      final result = map(
        chain(status: 'completed', sendTxid: 'tx'),
        boltz.SwapStatus.txnRefunded,
      );
      expect(statusOf(result), 'refundable');
    });

    test('completed chain swap with a recorded claim stays completed', () {
      final result = map(
        chain(status: 'completed', sendTxid: 'tx', receiveTxid: 'claim'),
        boltz.SwapStatus.txnRefunded,
      );
      expect(result, isA<SwapUnchanged>());
    });

    test('unproven completed chain swap without lockup cannot refund', () {
      final result = map(
        chain(status: 'completed'),
        boltz.SwapStatus.txnRefunded,
      );
      expect(result, isA<SwapUnchanged>());
    });
  });

  group('monotonicity', () {
    test('completed send swap ignores late lockup events', () {
      final result = map(
        lnSend(status: 'completed', sendTxid: 'tx'),
        boltz.SwapStatus.txnMempool,
      );
      expect(result, isA<SwapUnchanged>());
    });

    test('refunded swap ignores everything', () {
      final result = map(
        lnSend(status: 'refunded', sendTxid: 'tx', refundTxid: 'rtx'),
        boltz.SwapStatus.txnMempool,
      );
      expect(result, isA<SwapUnchanged>());
    });

    test('claimable does not regress to paid on replayed mempool event', () {
      final result = map(
        lnReceive(status: 'claimable', type: 'lightningToBitcoin'),
        boltz.SwapStatus.txnMempool,
      );
      expect(result, isA<SwapUnchanged>());
    });

    test('completed LnReceive without claim txid reopens to claimable', () {
      final result = map(
        lnReceive(status: 'completed'),
        boltz.SwapStatus.invoiceSettled,
      );
      expect(statusOf(result), 'claimable');
    });

    test('completed chain swap without claim txid reopens to claimable', () {
      final result = map(
        chain(status: 'completed', sendTxid: 'tx'),
        boltz.SwapStatus.txnClaimed,
      );
      expect(statusOf(result), 'claimable');
    });

    test('completed chain swap with claim txid is not reopened', () {
      final result = map(
        chain(status: 'completed', sendTxid: 'tx', receiveTxid: 'rtx'),
        boltz.SwapStatus.txnClaimed,
      );
      expect(statusOf(result), 'completed');
    });

    // A completed submarine swap means Boltz claimed the user's lockup — the
    // success outcome. There is no user claim txid to be "missing", and a
    // successful submarine swap never has a refundTxid, so completed must stay
    // terminal: it must never be reopened to refundable.
    test('completed submarine swap is never reopened to refundable', () {
      final result = map(
        lnSend(status: 'completed', sendTxid: 'tx'),
        boltz.SwapStatus.invoiceFailedToPay,
      );
      expect(result, isA<SwapUnchanged>());
    });
  });

  group('stale pending deletion', () {
    test('old pending swap with no funds is deleted on expiry event', () {
      final result = map(
        lnSend(creationTime: ancient),
        boltz.SwapStatus.swapExpired,
      );
      expect(result, isA<SwapStale>());
    });

    test('old pending swap WITH locked funds is never deleted', () {
      final result = map(
        lnSend(creationTime: ancient, sendTxid: 'tx'),
        boltz.SwapStatus.swapExpired,
      );
      expect(result, isA<SwapUpdated>());
      expect(statusOf(result), 'refundable');
    });

    test('old pending swap is not deleted on non-expiry events', () {
      final result = map(
        lnSend(creationTime: ancient),
        boltz.SwapStatus.txnMempool,
      );
      expect(result, isA<SwapUpdated>());
      expect(statusOf(result), 'paid');
    });

    test('young pending swap is not deleted on expiry', () {
      final result = map(lnSend(), boltz.SwapStatus.swapExpired);
      expect(statusOf(result), 'expired');
    });
  });

  group('no-op events', () {
    test('swap.created and invoice.set change nothing', () {
      expect(map(lnSend(), boltz.SwapStatus.swapCreated), isA<SwapUnchanged>());
      expect(map(lnSend(), boltz.SwapStatus.invoiceSet), isA<SwapUnchanged>());
    });
  });
}
