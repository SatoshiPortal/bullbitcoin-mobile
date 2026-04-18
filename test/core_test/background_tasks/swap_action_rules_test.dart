import 'package:bb_mobile/core/background_tasks/swap_action_rules.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:boltz/boltz.dart' as boltz_pkg;
import 'package:flutter_test/flutter_test.dart';

Swap _lnReceive({
  required SwapStatus status,
  required SwapType type,
  String? receiveTxid,
}) {
  return Swap.lnReceive(
    id: 'ln-recv-1',
    keyIndex: 0,
    type: type,
    status: status,
    environment: Environment.mainnet,
    creationTime: DateTime(2025),
    receiveWalletId: 'receive-wallet',
    invoice: 'lnbc...',
    receiveTxid: receiveTxid,
  );
}

Swap _lnSend({
  required SwapStatus status,
  required SwapType type,
  String? sendTxid,
  String? refundTxid,
}) {
  return Swap.lnSend(
    id: 'ln-send-1',
    keyIndex: 0,
    type: type,
    status: status,
    environment: Environment.mainnet,
    creationTime: DateTime(2025),
    sendWalletId: 'send-wallet',
    invoice: 'lnbc...',
    paymentAddress: 'bc1...',
    paymentAmount: 10000,
    sendTxid: sendTxid,
    refundTxid: refundTxid,
  );
}

Swap _chain({
  required SwapStatus status,
  required SwapType type,
  String? sendTxid,
  String? receiveTxid,
  String? refundTxid,
  String? receiveWalletId = 'receive-wallet',
}) {
  return Swap.chain(
    id: 'chain-1',
    keyIndex: 0,
    type: type,
    status: status,
    environment: Environment.mainnet,
    creationTime: DateTime(2025),
    sendWalletId: 'send-wallet',
    paymentAddress: 'bc1...',
    paymentAmount: 10000,
    sendTxid: sendTxid,
    receiveWalletId: receiveWalletId,
    receiveTxid: receiveTxid,
    refundTxid: refundTxid,
  );
}

void main() {
  group('effectiveActionableStatus — LnReceiveSwap', () {
    test('returns claimable when persisted status is claimable', () {
      final s = _lnReceive(
        status: SwapStatus.claimable,
        type: SwapType.lightningToBitcoin,
      );
      expect(effectiveActionableStatus(s, null), SwapStatus.claimable);
    });

    test('returns null when already claimed (receiveTxid set)', () {
      final s = _lnReceive(
        status: SwapStatus.pending,
        type: SwapType.lightningToLiquid,
        receiveTxid: 'tx',
      );
      expect(
        effectiveActionableStatus(s, boltz_pkg.SwapStatus.invoiceSettled),
        isNull,
      );
    });

    test('returns claimable on fresh invoiceSettled', () {
      final s = _lnReceive(
        status: SwapStatus.pending,
        type: SwapType.lightningToBitcoin,
      );
      expect(
        effectiveActionableStatus(s, boltz_pkg.SwapStatus.invoiceSettled),
        SwapStatus.claimable,
      );
    });

    test('liquid-target: returns claimable on fresh txnMempool', () {
      final s = _lnReceive(
        status: SwapStatus.pending,
        type: SwapType.lightningToLiquid,
      );
      expect(
        effectiveActionableStatus(s, boltz_pkg.SwapStatus.txnMempool),
        SwapStatus.claimable,
      );
    });

    test(
      'bitcoin-target: returns null on fresh txnMempool (needs confirm)',
      () {
        final s = _lnReceive(
          status: SwapStatus.pending,
          type: SwapType.lightningToBitcoin,
        );
        expect(
          effectiveActionableStatus(s, boltz_pkg.SwapStatus.txnMempool),
          isNull,
        );
      },
    );

    test('bitcoin-target: returns claimable on fresh txnConfirmed', () {
      final s = _lnReceive(
        status: SwapStatus.pending,
        type: SwapType.lightningToBitcoin,
      );
      expect(
        effectiveActionableStatus(s, boltz_pkg.SwapStatus.txnConfirmed),
        SwapStatus.claimable,
      );
    });

    test(
      'liquid-target: returns null on fresh txnConfirmed (wrong signal)',
      () {
        final s = _lnReceive(
          status: SwapStatus.pending,
          type: SwapType.lightningToLiquid,
        );
        expect(
          effectiveActionableStatus(s, boltz_pkg.SwapStatus.txnConfirmed),
          isNull,
        );
      },
    );

    test('returns null with no fresh and non-actionable persisted status', () {
      final s = _lnReceive(
        status: SwapStatus.pending,
        type: SwapType.lightningToBitcoin,
      );
      expect(effectiveActionableStatus(s, null), isNull);
    });
  });

  group('effectiveActionableStatus — LnSendSwap', () {
    test('returns canCoop when persisted status is canCoop', () {
      final s = _lnSend(
        status: SwapStatus.canCoop,
        type: SwapType.bitcoinToLightning,
        sendTxid: 'tx',
      );
      expect(effectiveActionableStatus(s, null), SwapStatus.canCoop);
    });

    test(
      'returns failed when status=failed AND sendTxid set AND no refund yet',
      () {
        final s = _lnSend(
          status: SwapStatus.failed,
          type: SwapType.bitcoinToLightning,
          sendTxid: 'tx',
        );
        expect(effectiveActionableStatus(s, null), SwapStatus.failed);
      },
    );

    test(
      'returns null when status=failed but no sendTxid (nothing locked)',
      () {
        final s = _lnSend(
          status: SwapStatus.failed,
          type: SwapType.bitcoinToLightning,
        );
        expect(effectiveActionableStatus(s, null), isNull);
      },
    );

    test('returns null when status=failed but already refunded', () {
      final s = _lnSend(
        status: SwapStatus.failed,
        type: SwapType.bitcoinToLightning,
        sendTxid: 'tx',
        refundTxid: 'refund',
      );
      expect(effectiveActionableStatus(s, null), isNull);
    });

    test('returns refundable when persisted is refundable', () {
      final s = _lnSend(
        status: SwapStatus.refundable,
        type: SwapType.bitcoinToLightning,
        sendTxid: 'tx',
      );
      expect(effectiveActionableStatus(s, null), SwapStatus.refundable);
    });

    test('returns canCoop on fresh invoicePaid', () {
      final s = _lnSend(
        status: SwapStatus.pending,
        type: SwapType.bitcoinToLightning,
        sendTxid: 'tx',
      );
      expect(
        effectiveActionableStatus(s, boltz_pkg.SwapStatus.invoicePaid),
        SwapStatus.canCoop,
      );
    });

    test('returns canCoop on fresh txnClaimPending', () {
      final s = _lnSend(
        status: SwapStatus.pending,
        type: SwapType.bitcoinToLightning,
        sendTxid: 'tx',
      );
      expect(
        effectiveActionableStatus(s, boltz_pkg.SwapStatus.txnClaimPending),
        SwapStatus.canCoop,
      );
    });

    test('returns failed on fresh swapError when can refund', () {
      final s = _lnSend(
        status: SwapStatus.pending,
        type: SwapType.bitcoinToLightning,
        sendTxid: 'tx',
      );
      expect(
        effectiveActionableStatus(s, boltz_pkg.SwapStatus.swapError),
        SwapStatus.failed,
      );
    });

    test('returns null on fresh swapError when nothing locked', () {
      final s = _lnSend(
        status: SwapStatus.pending,
        type: SwapType.bitcoinToLightning,
      );
      expect(
        effectiveActionableStatus(s, boltz_pkg.SwapStatus.swapError),
        isNull,
      );
    });
  });

  group('effectiveActionableStatus — ChainSwap', () {
    test('returns claimable when persisted status is claimable', () {
      final s = _chain(
        status: SwapStatus.claimable,
        type: SwapType.bitcoinToLiquid,
      );
      expect(effectiveActionableStatus(s, null), SwapStatus.claimable);
    });

    test('returns refundable when persisted status is refundable', () {
      final s = _chain(
        status: SwapStatus.refundable,
        type: SwapType.bitcoinToLiquid,
        sendTxid: 'tx',
      );
      expect(effectiveActionableStatus(s, null), SwapStatus.refundable);
    });

    test('liquid-target: returns claimable on fresh txnServerMempool', () {
      final s = _chain(
        status: SwapStatus.pending,
        type: SwapType.bitcoinToLiquid,
      );
      expect(
        effectiveActionableStatus(s, boltz_pkg.SwapStatus.txnServerMempool),
        SwapStatus.claimable,
      );
    });

    test(
      'bitcoin-target: returns null on fresh txnServerMempool (needs confirm)',
      () {
        final s = _chain(
          status: SwapStatus.pending,
          type: SwapType.liquidToBitcoin,
        );
        expect(
          effectiveActionableStatus(s, boltz_pkg.SwapStatus.txnServerMempool),
          isNull,
        );
      },
    );

    test('returns claimable on fresh txnServerConfirmed (any target)', () {
      final s = _chain(
        status: SwapStatus.pending,
        type: SwapType.liquidToBitcoin,
      );
      expect(
        effectiveActionableStatus(s, boltz_pkg.SwapStatus.txnServerConfirmed),
        SwapStatus.claimable,
      );
    });

    test('returns claimable on fresh txnClaimed', () {
      final s = _chain(
        status: SwapStatus.pending,
        type: SwapType.bitcoinToLiquid,
      );
      expect(
        effectiveActionableStatus(s, boltz_pkg.SwapStatus.txnClaimed),
        SwapStatus.claimable,
      );
    });

    test('returns null when already received (receiveTxid set)', () {
      final s = _chain(
        status: SwapStatus.pending,
        type: SwapType.bitcoinToLiquid,
        receiveTxid: 'tx',
      );
      expect(
        effectiveActionableStatus(s, boltz_pkg.SwapStatus.txnClaimed),
        isNull,
      );
    });

    test('returns failed on fresh failure when can refund', () {
      final s = _chain(
        status: SwapStatus.pending,
        type: SwapType.bitcoinToLiquid,
        sendTxid: 'tx',
      );
      expect(
        effectiveActionableStatus(s, boltz_pkg.SwapStatus.swapExpired),
        SwapStatus.failed,
      );
    });

    test('returns null on fresh failure when no sendTxid', () {
      final s = _chain(
        status: SwapStatus.pending,
        type: SwapType.bitcoinToLiquid,
      );
      expect(
        effectiveActionableStatus(s, boltz_pkg.SwapStatus.swapExpired),
        isNull,
      );
    });
  });

  group('notificationWalletId', () {
    test('LnReceiveSwap always uses walletId (receiveWalletId)', () {
      final s = _lnReceive(
        status: SwapStatus.claimable,
        type: SwapType.lightningToBitcoin,
      );
      expect(notificationWalletId(s, SwapStatus.claimable), 'receive-wallet');
    });

    test('LnSendSwap always uses walletId (sendWalletId)', () {
      final s = _lnSend(
        status: SwapStatus.refundable,
        type: SwapType.bitcoinToLightning,
        sendTxid: 'tx',
      );
      expect(notificationWalletId(s, SwapStatus.refundable), 'send-wallet');
    });

    test('ChainSwap claimable → receiveWalletId', () {
      final s = _chain(
        status: SwapStatus.claimable,
        type: SwapType.bitcoinToLiquid,
      );
      expect(notificationWalletId(s, SwapStatus.claimable), 'receive-wallet');
    });

    test('ChainSwap refundable → sendWalletId', () {
      final s = _chain(
        status: SwapStatus.refundable,
        type: SwapType.bitcoinToLiquid,
        sendTxid: 'tx',
      );
      expect(notificationWalletId(s, SwapStatus.refundable), 'send-wallet');
    });

    test('external ChainSwap claimable → null (no in-app claim)', () {
      final s = _chain(
        status: SwapStatus.claimable,
        type: SwapType.bitcoinToLiquid,
        receiveWalletId: null,
      );
      expect(notificationWalletId(s, SwapStatus.claimable), isNull);
    });
  });

  group('isFailureStatus', () {
    test('matches all documented boltz failure statuses', () {
      const failures = [
        boltz_pkg.SwapStatus.invoiceFailedToPay,
        boltz_pkg.SwapStatus.txnLockupFailed,
        boltz_pkg.SwapStatus.txnFailed,
        boltz_pkg.SwapStatus.txnRefunded,
        boltz_pkg.SwapStatus.swapExpired,
        boltz_pkg.SwapStatus.invoiceExpired,
        boltz_pkg.SwapStatus.swapError,
        boltz_pkg.SwapStatus.swapRefunded,
      ];
      for (final f in failures) {
        expect(isFailureStatus(f), isTrue, reason: 'expected $f → true');
      }
    });

    test('rejects non-failure statuses', () {
      const nonFailures = [
        boltz_pkg.SwapStatus.invoicePaid,
        boltz_pkg.SwapStatus.invoicePending,
        boltz_pkg.SwapStatus.invoiceSet,
        boltz_pkg.SwapStatus.invoiceSettled,
        boltz_pkg.SwapStatus.txnMempool,
        boltz_pkg.SwapStatus.txnConfirmed,
        boltz_pkg.SwapStatus.txnServerMempool,
        boltz_pkg.SwapStatus.txnServerConfirmed,
        boltz_pkg.SwapStatus.txnClaimPending,
        boltz_pkg.SwapStatus.txnClaimed,
      ];
      for (final s in nonFailures) {
        expect(isFailureStatus(s), isFalse, reason: 'expected $s → false');
      }
    });
  });
}
