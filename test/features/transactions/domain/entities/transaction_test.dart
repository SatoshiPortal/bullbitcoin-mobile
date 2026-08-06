import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

WalletTransaction _walletTx({
  required String txId,
  WalletTransactionDirection direction = WalletTransactionDirection.outgoing,
  int amountSat = 50000,
}) => WalletTransaction(
  walletId: 'w1',
  network: Network.bitcoinMainnet,
  direction: direction,
  status: WalletTransactionStatus.pending,
  txId: txId,
  amountSat: amountSat,
  feeSat: 500,
  vsize: 150,
  inputs: const [],
  outputs: const [],
  isRbf: false,
);

Payjoin _senderPayjoin({
  PayjoinStatus status = PayjoinStatus.requested,
  String originalTxId = 'orig-txid',
  String? txId,
}) => Payjoin.sender(
  status: status,
  uri: 'bitcoin:tb1qsender?pj=https://payjo.in',
  isTestnet: false,
  walletId: 'w1',
  originalPsbt: 'cHNidP8=',
  originalTxId: originalTxId,
  amountSat: 50000,
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026, 1, 1, 0, 5),
  txId: txId,
);

void main() {
  group('Transaction.displayPayjoinStatus', () {
    test('is null when the transaction has no payjoin', () {
      expect(const Transaction().displayPayjoinStatus, isNull);
      expect(
        Transaction(
          walletTransaction: _walletTx(txId: 'any'),
        ).displayPayjoinStatus,
        isNull,
      );
    });

    test('passes the session status through while nothing is broadcast', () {
      for (final status in [
        PayjoinStatus.requested,
        PayjoinStatus.proposed,
        PayjoinStatus.completed,
        PayjoinStatus.aborted,
        PayjoinStatus.expired,
      ]) {
        expect(
          Transaction(
            payjoin: _senderPayjoin(status: status),
          ).displayPayjoinStatus,
          status,
        );
      }
    });

    test('derives completed from the wallet transaction being the payjoin '
        'transaction, even while the session row still lags on '
        'proposed', () {
      final transaction = Transaction(
        walletTransaction: _walletTx(txId: 'payjoin-txid'),
        payjoin: _senderPayjoin(
          status: PayjoinStatus.proposed,
          txId: 'payjoin-txid',
        ),
      );

      expect(transaction.displayPayjoinStatus, PayjoinStatus.completed);
    });

    test('derives aborted (fallback) from the wallet transaction being the '
        'ORIGINAL transaction, even while the session row still lags on '
        'requested', () {
      final transaction = Transaction(
        walletTransaction: _walletTx(txId: 'orig-txid'),
        payjoin: _senderPayjoin(status: PayjoinStatus.requested),
      );

      expect(transaction.displayPayjoinStatus, PayjoinStatus.aborted);
    });

    test('never downgrades a real payjoin completion to fallback', () {
      // Degenerate ordering safety: a session already marked completed keeps
      // that status regardless of which transaction this record was paired
      // with.
      final transaction = Transaction(
        walletTransaction: _walletTx(txId: 'orig-txid'),
        payjoin: _senderPayjoin(
          status: PayjoinStatus.completed,
          txId: 'payjoin-txid',
        ),
      );

      expect(transaction.displayPayjoinStatus, PayjoinStatus.completed);
    });

    test('keeps the session status when the wallet transaction matches '
        'neither txid', () {
      final transaction = Transaction(
        walletTransaction: _walletTx(txId: 'unrelated-txid'),
        payjoin: _senderPayjoin(status: PayjoinStatus.proposed),
      );

      expect(transaction.displayPayjoinStatus, PayjoinStatus.proposed);
    });
  });

  group('Transaction.payjoinFeeContributionSat', () {
    WalletTransaction buildWalletTransaction(int amountSat) =>
        WalletTransaction(
          walletId: 'w1',
          network: Network.bitcoinMainnet,
          direction: WalletTransactionDirection.incoming,
          status: WalletTransactionStatus.confirmed,
          txId: 'a' * 64,
          amountSat: amountSat,
          feeSat: 200,
          vsize: 250,
          inputs: const [],
          outputs: const [],
          isRbf: false,
        );

    Payjoin buildReceiver({
      required int amountSat,
      required PayjoinStatus status,
      String? txId,
    }) => Payjoin.receiver(
      status: status,
      id: 'r1',
      isTestnet: false,
      walletId: 'w1',
      pjUri: 'bitcoin:addr?pj=https://payjo.in/x',
      createdAt: DateTime(2026),
      expiresAt: DateTime(2026, 1, 2),
      amountSat: amountSat,
      txId: txId,
    );

    test('derives the gap between the negotiated amount and the wallet-visible '
        'amount for a completed receiver payjoin', () {
      final transaction = Transaction(
        walletTransaction: buildWalletTransaction(948),
        payjoin: buildReceiver(
          amountSat: 1002,
          status: PayjoinStatus.completed,
        ),
      );

      expect(transaction.payjoinFeeContributionSat, 54);
    });

    test('also applies while merely proposed when the broadcast tx IS the '
        'proposal (txid match) — mirrors the existing status-display '
        'heuristic, since a receiver session may never reach `completed` '
        'without watch-for-broadcast', () {
      final transaction = Transaction(
        walletTransaction: buildWalletTransaction(948),
        payjoin: buildReceiver(
          amountSat: 1002,
          status: PayjoinStatus.proposed,
          txId: 'a' * 64, // same as the wallet transaction's txId
        ),
      );

      expect(transaction.payjoinFeeContributionSat, 54);
    });

    test('null while proposed when the broadcast tx is NOT the proposal (e.g. '
        'the original transaction, joined to the session by originalTxId): a '
        'fallback contributed no input, so no fee-contribution row', () {
      final transaction = Transaction(
        walletTransaction: buildWalletTransaction(948),
        payjoin: buildReceiver(
          amountSat: 1002,
          status: PayjoinStatus.proposed,
          txId: 'b' * 64, // proposal txid differs from the broadcast tx
        ),
      );

      expect(transaction.payjoinFeeContributionSat, isNull);
    });

    test('null when there is no gap (amounts match)', () {
      final transaction = Transaction(
        walletTransaction: buildWalletTransaction(1002),
        payjoin: buildReceiver(
          amountSat: 1002,
          status: PayjoinStatus.completed,
        ),
      );

      expect(transaction.payjoinFeeContributionSat, isNull);
    });

    test('null when the wallet actually received more (a negative gap)', () {
      final transaction = Transaction(
        walletTransaction: buildWalletTransaction(1100),
        payjoin: buildReceiver(
          amountSat: 1002,
          status: PayjoinStatus.completed,
        ),
      );

      expect(transaction.payjoinFeeContributionSat, isNull);
    });

    test('null for a sender payjoin (receive-side only)', () {
      final transaction = Transaction(
        walletTransaction: buildWalletTransaction(948),
        payjoin: Payjoin.sender(
          status: PayjoinStatus.completed,
          uri: 'bitcoin:addr?pj=https://payjo.in/x',
          isTestnet: false,
          walletId: 'w1',
          originalPsbt: 'psbt',
          originalTxId: 'a' * 64,
          amountSat: 1002,
          createdAt: DateTime(2026),
          expiresAt: DateTime(2026, 1, 2),
        ),
      );

      expect(transaction.payjoinFeeContributionSat, isNull);
    });

    test('null when the session never resolved (still just requested)', () {
      final transaction = Transaction(
        walletTransaction: buildWalletTransaction(948),
        payjoin: buildReceiver(
          amountSat: 1002,
          status: PayjoinStatus.requested,
        ),
      );

      expect(transaction.payjoinFeeContributionSat, isNull);
    });

    test(
      'null for an aborted session (a plain broadcast, not a real payjoin)',
      () {
        final transaction = Transaction(
          walletTransaction: buildWalletTransaction(948),
          payjoin: buildReceiver(
            amountSat: 1002,
            status: PayjoinStatus.aborted,
          ),
        );

        expect(transaction.payjoinFeeContributionSat, isNull);
      },
    );

    test('null without a broadcast transaction yet', () {
      final transaction = Transaction(
        payjoin: buildReceiver(
          amountSat: 1002,
          status: PayjoinStatus.completed,
        ),
      );

      expect(transaction.payjoinFeeContributionSat, isNull);
    });
  });

  group('Transaction with OrderSwap', () {
    test('classifies a broadcast Bitcoin to Lightning order as ongoing', () {
      final transaction = Transaction(orderSwap: _orderSwap());

      expect(transaction.isSwap, isTrue);
      expect(transaction.isLnSwap, isTrue);
      expect(transaction.isChainSwap, isFalse);
      expect(transaction.isOngoingSwap, isTrue);
      expect(transaction.isOutgoing, isTrue);
      expect(transaction.isBitcoin, isTrue);
      expect(transaction.isTestnet, isTrue);
      expect(transaction.txId, 'payin-txid');
      expect(transaction.walletId, 'wallet-1');
      expect(transaction.swapListAmountSat, 100000);
      expect(transaction.swapDisplayAmountSat, 100000);
    });

    test('classifies terminal order states as no longer ongoing', () {
      for (final status in [
        OrderSwapLocalStatus.completed,
        OrderSwapLocalStatus.refunded,
        OrderSwapLocalStatus.expired,
        OrderSwapLocalStatus.failed,
      ]) {
        expect(
          Transaction(orderSwap: _orderSwap(status: status)).isOngoingSwap,
          isFalse,
        );
      }
    });

    test('identifies a Liquid to Bitcoin order as cross-chain', () {
      final transaction = Transaction(
        orderSwap: _orderSwap(
          inNetwork: OrderSwapNetwork.liquid,
          outNetwork: OrderSwapNetwork.bitcoin,
        ),
      );

      expect(transaction.isChainSwap, isTrue);
      expect(transaction.isLnSwap, isFalse);
      expect(transaction.isLiquidToBitcoinSwap, isTrue);
    });
  });
}

OrderSwapRecord _orderSwap({
  OrderSwapLocalStatus status = OrderSwapLocalStatus.payinBroadcast,
  OrderSwapNetwork inNetwork = OrderSwapNetwork.bitcoin,
  OrderSwapNetwork outNetwork = OrderSwapNetwork.lightning,
}) {
  final createdAt = DateTime.utc(2026, 8, 6);
  return OrderSwapRecord(
    localId: 'local-1',
    purpose: OrderSwapPurpose.sendLightning,
    environment: OrderSwapEnvironment.testnet,
    inNetwork: inNetwork,
    outNetwork: outNetwork,
    isInAmountFixed: false,
    requestedAmountSat: BigInt.from(100000),
    sourceWalletId: 'wallet-1',
    destination: 'invoice',
    fallback: 'fallback',
    order: OrderSwap(
      orderId: 'order-1',
      orderNumber: 1,
      inNetwork: inNetwork,
      outNetwork: outNetwork,
      payinAmountSat: BigInt.from(101000),
      payoutAmountSat: BigInt.from(100000),
      payinCurrency: inNetwork.name,
      payoutCurrency: outNetwork.name,
      payinMethod: inNetwork.name,
      payoutMethod: outNetwork.name,
      orderType: 'Swap',
      orderStatus: 'In progress',
      payinStatus: 'Completed',
      payoutStatus: 'In progress',
      messageCode: 'PAYOUT_IN_PROGRESS',
      createdAt: createdAt,
      confirmationDeadline: createdAt.add(const Duration(minutes: 5)),
    ),
    localPayinTransactionId: 'payin-txid',
    createdAt: createdAt,
    localStatus: status,
  );
}
