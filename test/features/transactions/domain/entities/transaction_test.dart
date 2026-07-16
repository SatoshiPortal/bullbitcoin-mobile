import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
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

Payjoin _receiverPayjoin({
  PayjoinStatus status = PayjoinStatus.completed,
  String? txId = 'payjoin-txid',
  int? amountSat = 1002,
}) => Payjoin.receiver(
  status: status,
  id: 'recv-1',
  isTestnet: false,
  walletId: 'w1',
  pjUri: 'bitcoin:tb1qreceiver?pj=https://payjo.in',
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026, 1, 1, 0, 5),
  originalTxId: 'orig-txid',
  amountSat: amountSat,
  txId: txId,
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
    test('is the gap between the negotiated payment and the net received '
        'amount on the receive side of a completed payjoin (BIP78 fee for '
        'the contributed input)', () {
      // Observed live: 1002 sats sent, 948 received — 54 sats of mining fee
      // paid for the receiver's contributed input.
      final transaction = Transaction(
        walletTransaction: _walletTx(
          txId: 'payjoin-txid',
          direction: WalletTransactionDirection.incoming,
          amountSat: 948,
        ),
        payjoin: _receiverPayjoin(amountSat: 1002),
      );

      expect(transaction.payjoinFeeContributionSat, 54);
    });

    test('is null on the send side — the sender does not pay the '
        'receiver\'s input fee', () {
      final transaction = Transaction(
        walletTransaction: _walletTx(txId: 'payjoin-txid', amountSat: 1002),
        payjoin: _senderPayjoin(
          status: PayjoinStatus.completed,
          txId: 'payjoin-txid',
        ),
      );

      expect(transaction.payjoinFeeContributionSat, isNull);
    });

    test('is null for an aborted payjoin — the plain original transaction '
        'has no contributed input', () {
      final transaction = Transaction(
        walletTransaction: _walletTx(
          txId: 'orig-txid',
          direction: WalletTransactionDirection.incoming,
          amountSat: 902,
        ),
        payjoin: _receiverPayjoin(
          status: PayjoinStatus.aborted,
          txId: null,
          amountSat: 902,
        ),
      );

      expect(transaction.payjoinFeeContributionSat, isNull);
    });

    test('is null when there is no positive gap', () {
      final transaction = Transaction(
        walletTransaction: _walletTx(
          txId: 'payjoin-txid',
          direction: WalletTransactionDirection.incoming,
          amountSat: 1002,
        ),
        payjoin: _receiverPayjoin(amountSat: 1002),
      );

      expect(transaction.payjoinFeeContributionSat, isNull);
    });

    test('is null while the wallet transaction is not visible yet', () {
      expect(
        Transaction(
          payjoin: _receiverPayjoin(amountSat: 1002),
        ).payjoinFeeContributionSat,
        isNull,
      );
    });
  });
}
