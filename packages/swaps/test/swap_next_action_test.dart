import 'package:swaps/src/domain/entities/swap.dart';
import 'package:test/test.dart';

void main() {
  Swap reverse(SwapStatus status, {String? receiveTxid, bool direct = false}) =>
      Swap.lnReceive(
        id: 'reverse',
        keyIndex: 0,
        type: SwapType.lightningToLiquid,
        status: status,
        environment: Environment.mainnet,
        creationTime: DateTime.utc(2026),
        receiveWalletId: 'w',
        invoice: 'lnbc1',
        receiveTxid: receiveTxid,
        wasDirectPayment: direct,
      );

  Swap submarine(SwapStatus status, {String? sendTxid, String? refundTxid}) =>
      Swap.lnSend(
        id: 'submarine',
        keyIndex: 0,
        type: SwapType.liquidToLightning,
        status: status,
        environment: Environment.mainnet,
        creationTime: DateTime.utc(2026),
        sendWalletId: 'w',
        invoice: 'lnbc1',
        paymentAddress: 'lq1lockup',
        paymentAmount: 1000,
        sendTxid: sendTxid,
        refundTxid: refundTxid,
      );

  Swap chain(
    SwapStatus status, {
    String? sendTxid,
    String? receiveTxid,
    String? refundTxid,
  }) => Swap.chain(
    id: 'chain',
    keyIndex: 0,
    type: SwapType.liquidToBitcoin,
    status: status,
    environment: Environment.mainnet,
    creationTime: DateTime.utc(2026),
    sendWalletId: 'w',
    paymentAddress: 'lq1lockup',
    paymentAmount: 1000,
    sendTxid: sendTxid,
    receiveTxid: receiveTxid,
    refundTxid: refundTxid,
  );

  group('unfunded', () {
    test('an unpaid invoice and an unsent lockup are unfunded', () {
      expect(reverse(SwapStatus.pending).isUnfunded, isTrue);
      expect(submarine(SwapStatus.pending).isUnfunded, isTrue);
      expect(chain(SwapStatus.pending).isUnfunded, isTrue);
    });

    test('a sent lockup is funded even before Boltz sees it', () {
      expect(
        submarine(SwapStatus.pending, sendTxid: 'lockup').isUnfunded,
        isFalse,
      );
      expect(chain(SwapStatus.pending, sendTxid: 'lockup').isUnfunded, isFalse);
    });

    test('a swap past pending is never unfunded', () {
      for (final status in SwapStatus.values.where(
        (status) => status != SwapStatus.pending,
      )) {
        expect(reverse(status).isUnfunded, isFalse, reason: '$status');
        expect(submarine(status).isUnfunded, isFalse, reason: '$status');
        expect(chain(status).isUnfunded, isFalse, reason: '$status');
      }
    });
  });

  group('reverse swap', () {
    test('claims Boltz\'s lockup until our claim is recorded', () {
      for (final status in [
        SwapStatus.claimable,
        SwapStatus.canCoop,
        SwapStatus.completed,
      ]) {
        expect(reverse(status).nextAction, SwapAction.claim, reason: '$status');
        expect(
          reverse(status, receiveTxid: 'claim').nextAction,
          SwapAction.none,
          reason: '$status claimed',
        );
      }
    });

    test('never claims a direct payment or before Boltz locks', () {
      expect(
        reverse(SwapStatus.completed, direct: true).nextAction,
        SwapAction.none,
      );
      expect(reverse(SwapStatus.pending).nextAction, SwapAction.none);
      expect(reverse(SwapStatus.paid).nextAction, SwapAction.none);
    });
  });

  group('submarine swap', () {
    test('refunds our lockup once the swap failed', () {
      for (final status in [
        SwapStatus.failed,
        SwapStatus.expired,
        SwapStatus.refunded,
      ]) {
        expect(
          submarine(status, sendTxid: 'lockup').nextAction,
          SwapAction.refund,
          reason: '$status',
        );
        expect(
          submarine(status).nextAction,
          SwapAction.none,
          reason: '$status without a lockup',
        );
      }
    });

    test('waits while the payment is in flight', () {
      expect(
        submarine(SwapStatus.paid, sendTxid: 'lockup').nextAction,
        SwapAction.none,
      );
    });

    test('co-signs Boltz\'s claim and stops once refunded', () {
      expect(
        submarine(SwapStatus.canCoop, sendTxid: 'lockup').nextAction,
        SwapAction.coopSign,
      );
      expect(
        submarine(
          SwapStatus.refundable,
          sendTxid: 'lockup',
          refundTxid: 'refund',
        ).nextAction,
        SwapAction.none,
      );
    });
  });

  group('chain swap', () {
    test('claims the server lockup until our claim is recorded', () {
      expect(chain(SwapStatus.claimable).nextAction, SwapAction.claim);
      expect(
        chain(SwapStatus.completed, sendTxid: 'lockup').nextAction,
        SwapAction.claim,
      );
      expect(
        chain(
          SwapStatus.completed,
          sendTxid: 'lockup',
          receiveTxid: 'claim',
        ).nextAction,
        SwapAction.none,
      );
    });

    test(
      'refunds our lockup after Boltz gave up, even after its own refund',
      () {
        for (final status in [
          SwapStatus.failed,
          SwapStatus.expired,
          SwapStatus.refunded,
        ]) {
          expect(
            chain(status, sendTxid: 'lockup').nextAction,
            SwapAction.refund,
            reason: '$status',
          );
          expect(
            chain(status, sendTxid: 'lockup', refundTxid: 'refund').nextAction,
            SwapAction.none,
            reason: '$status refunded',
          );
        }
      },
    );

    test('holds nothing without a lockup', () {
      expect(chain(SwapStatus.pending).nextAction, SwapAction.none);
      expect(chain(SwapStatus.expired).nextAction, SwapAction.none);
    });
  });

  group('timeout refund', () {
    final created = DateTime.utc(2026);
    final later = created.add(const Duration(hours: 25));

    test('a paid swap holding our lockup awaits the timeout refund', () {
      expect(
        submarine(
          SwapStatus.paid,
          sendTxid: 'lockup',
        ).awaitsTimeoutRefund(later),
        isTrue,
      );
      expect(
        chain(SwapStatus.paid, sendTxid: 'lockup').awaitsTimeoutRefund(later),
        isTrue,
      );
    });

    test('a claim or co-sign that never resolves falls back to it', () {
      expect(
        submarine(
          SwapStatus.canCoop,
          sendTxid: 'lockup',
        ).awaitsTimeoutRefund(later),
        isTrue,
      );
      expect(
        chain(
          SwapStatus.claimable,
          sendTxid: 'lockup',
        ).awaitsTimeoutRefund(later),
        isTrue,
      );
    });

    test('nothing is attempted in the first day', () {
      expect(
        submarine(
          SwapStatus.paid,
          sendTxid: 'lockup',
        ).awaitsTimeoutRefund(created.add(const Duration(hours: 23))),
        isFalse,
      );
    });

    test('nothing is attempted without a lockup or once resolved', () {
      expect(submarine(SwapStatus.paid).awaitsTimeoutRefund(later), isFalse);
      expect(
        submarine(
          SwapStatus.paid,
          sendTxid: 'lockup',
          refundTxid: 'refund',
        ).awaitsTimeoutRefund(later),
        isFalse,
      );
      expect(
        chain(
          SwapStatus.paid,
          sendTxid: 'lockup',
          receiveTxid: 'claim',
        ).awaitsTimeoutRefund(later),
        isFalse,
      );
      expect(reverse(SwapStatus.paid).awaitsTimeoutRefund(later), isFalse);
    });

    test('a refundable or settled swap is not a timeout case', () {
      expect(
        chain(
          SwapStatus.refundable,
          sendTxid: 'lockup',
        ).awaitsTimeoutRefund(later),
        isFalse,
      );
      expect(
        chain(
          SwapStatus.completed,
          sendTxid: 'lockup',
        ).awaitsTimeoutRefund(later),
        isFalse,
      );
    });
  });

  test('a swap pins the provider for its first day only', () {
    final swap = submarine(SwapStatus.pending);
    final created = DateTime.utc(2026);

    expect(
      swap.mayStillNeedProvider(created.add(const Duration(hours: 23))),
      isTrue,
    );
    expect(
      swap.mayStillNeedProvider(created.add(const Duration(hours: 25))),
      isFalse,
    );
  });
}
