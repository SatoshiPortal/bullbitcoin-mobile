import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

WalletTransaction _walletTx({required String txId}) => WalletTransaction(
  walletId: 'w1',
  network: Network.bitcoinMainnet,
  direction: WalletTransactionDirection.outgoing,
  status: WalletTransactionStatus.pending,
  txId: txId,
  amountSat: 50000,
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
}
