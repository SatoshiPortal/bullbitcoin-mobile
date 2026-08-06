import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Sats;

WalletTransaction _walletTx({
  required String txId,
  WalletTransactionDirection direction = WalletTransactionDirection.outgoing,
  int amountSat = 50000,
  int feeSat = 500,
}) => WalletTransaction(
  walletId: 'w1',
  network: Network.bitcoinMainnet,
  direction: direction,
  status: WalletTransactionStatus.pending,
  txId: txId,
  amountSat: amountSat,
  feeSat: feeSat,
  vsize: 150,
  inputs: const [],
  outputs: const [],
  isRbf: false,
);

PayjoinSession _senderPayjoin({
  PayjoinStatus status = PayjoinStatus.requested,
  String originalTxId = 'orig-txid',
  String? txId,
  int amountSat = 50000,
}) => PayjoinSenderSession(
  status: status,
  uri: 'bitcoin:tb1qsender?pj=https://payjo.in',
  network: BitcoinNetwork.mainnet,
  walletId: 'w1',
  originalTransactionId: originalTxId,
  amount: Sats.fromInt(amountSat),
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026, 1, 1, 0, 5),
  transactionId: txId,
);

void main() {
  group('Transaction Payjoin sender amounts', () {
    test(
      'displays the negotiated amount instead of BDK receiver-net amount',
      () {
        final transaction = Transaction(
          walletTransaction: _walletTx(
            txId: 'payjoin-txid',
            amountSat: 99705,
            feeSat: 2381,
          ),
          payjoin: _senderPayjoin(
            status: PayjoinStatus.completed,
            txId: 'payjoin-txid',
            amountSat: 100001,
          ),
        );

        expect(transaction.amountSat, 100001);
      },
    );

    test('attributes only the sender fee share to the sender', () {
      final transaction = Transaction(
        walletTransaction: _walletTx(
          txId: 'payjoin-txid',
          amountSat: 99705,
          feeSat: 2381,
        ),
        payjoin: _senderPayjoin(
          status: PayjoinStatus.completed,
          txId: 'payjoin-txid',
          amountSat: 100001,
        ),
      );

      expect(transaction.payjoinSenderFeeSat, 2085);
    });

    test('keeps the full sender fee for a plain fallback', () {
      final transaction = Transaction(
        walletTransaction: _walletTx(
          txId: 'orig-txid',
          amountSat: 100001,
          feeSat: 500,
        ),
        payjoin: _senderPayjoin(
          status: PayjoinStatus.aborted,
          amountSat: 100001,
        ),
      );

      expect(transaction.amountSat, 100001);
      expect(transaction.payjoinSenderFeeSat, 500);
    });
  });

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

    PayjoinSession buildReceiver({
      required int amountSat,
      required PayjoinStatus status,
      String? txId,
    }) => PayjoinReceiverSession(
      status: status,
      id: 'r1',
      network: BitcoinNetwork.mainnet,
      walletId: 'w1',
      payjoinUri: 'bitcoin:addr?pj=https://payjo.in/x',
      createdAt: DateTime(2026),
      expiresAt: DateTime(2026, 1, 2),
      amount: Sats.fromInt(amountSat),
      transactionId: txId,
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
        payjoin: PayjoinSenderSession(
          status: PayjoinStatus.completed,
          uri: 'bitcoin:addr?pj=https://payjo.in/x',
          network: BitcoinNetwork.mainnet,
          walletId: 'w1',
          originalTransactionId: 'a' * 64,
          amount: Sats.fromInt(1002),
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

    test('uses the destination leg for a Lightning receive', () {
      final transaction = Transaction(orderSwap: _receiveOrderSwap());

      expect(transaction.txId, 'liquid-payout-txid');
      expect(transaction.walletId, 'liquid-wallet');
      expect(transaction.isIncoming, isTrue);
      expect(transaction.isLiquid, isTrue);
      expect(transaction.isBitcoin, isFalse);
      expect(transaction.swapDisplayAmountSat, 19800);
    });
  });
}

OrderSwapRecord _receiveOrderSwap() {
  final createdAt = DateTime.utc(2026, 8, 6);
  return OrderSwapRecord(
    localId: 'receive-local',
    purpose: OrderSwapPurpose.receiveLightning,
    environment: OrderSwapEnvironment.testnet,
    inNetwork: OrderSwapNetwork.lightning,
    outNetwork: OrderSwapNetwork.liquid,
    isInAmountFixed: true,
    requestedAmountSat: BigInt.from(20000),
    destinationWalletId: 'liquid-wallet',
    destination: 'liquid-address',
    fallback: 'atomic-refund',
    order: OrderSwap(
      orderId: 'receive-order',
      orderNumber: 2,
      inNetwork: OrderSwapNetwork.lightning,
      outNetwork: OrderSwapNetwork.liquid,
      payinAmountSat: BigInt.from(20000),
      payoutAmountSat: BigInt.from(19800),
      payinCurrency: 'BTCLN',
      payoutCurrency: 'LBTC',
      payinMethod: 'Lightning',
      payoutMethod: 'Liquid',
      orderType: 'Swap',
      orderStatus: 'Completed',
      payinStatus: 'Completed',
      payoutStatus: 'Completed',
      messageCode: 'COMPLETED',
      liquidTransactionId: 'liquid-payout-txid',
      createdAt: createdAt,
      confirmationDeadline: createdAt.add(const Duration(minutes: 5)),
    ),
    createdAt: createdAt,
    localStatus: OrderSwapLocalStatus.completed,
  );
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
