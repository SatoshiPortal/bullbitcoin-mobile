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
}
