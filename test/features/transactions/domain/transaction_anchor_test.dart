import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction_anchor.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(String iso) => DateTime.parse(iso);

WalletTransaction _wt({
  required bool incoming,
  required Network network,
  DateTime? confirmedAt,
  int? lockTime,
  int? confirmationHeight,
  bool isToSelf = false,
}) => WalletTransaction(
  walletId: 'w1',
  network: network,
  direction: incoming
      ? WalletTransactionDirection.incoming
      : WalletTransactionDirection.outgoing,
  status: confirmedAt == null
      ? WalletTransactionStatus.pending
      : WalletTransactionStatus.confirmed,
  txId: 'tx1',
  amountSat: 100000,
  feeSat: 200,
  vsize: 141,
  inputs: const [],
  outputs: const [],
  isRbf: false,
  confirmationTime: confirmedAt,
  lockTime: lockTime,
  confirmationHeight: confirmationHeight,
  isToSelf: isToSelf,
);

void main() {
  group('a self-transfer never shows a value', () {
    test('isToSelf resolves to none', () {
      final tx = Transaction(
        walletTransaction: _wt(
          incoming: false,
          network: Network.bitcoinMainnet,
          confirmedAt: _at('2026-09-01T12:00:00Z'),
          isToSelf: true,
        ),
      );
      expect(TransactionAnchor.of(tx), isA<NoAnchor>());
    });
  });

  group('outgoing', () {
    test('uses the stored send timestamp when it exists', () {
      final tx = Transaction(
        walletTransaction: _wt(
          incoming: false,
          network: Network.bitcoinMainnet,
          confirmedAt: _at('2026-09-01T13:10:00Z'),
        ),
      );
      final anchor = TransactionAnchor.of(
        tx,
        sentAt: _at('2026-09-01T12:00:00Z'),
      );
      expect(anchor, isA<SingleAnchor>());
      expect((anchor as SingleAnchor).at, _at('2026-09-01T12:00:00Z'));
      expect(anchor.reason, AnchorReason.sent);
    });

    test('falls back to confirmation after a restore loses the timestamp', () {
      final tx = Transaction(
        walletTransaction: _wt(
          incoming: false,
          network: Network.bitcoinMainnet,
          confirmedAt: _at('2026-09-01T13:10:00Z'),
        ),
      );
      final anchor = TransactionAnchor.of(tx);
      expect(anchor, isA<SingleAnchor>());
      expect((anchor as SingleAnchor).at, _at('2026-09-01T13:10:00Z'));
      expect(anchor.reason, AnchorReason.confirmed);
    });
  });

  group('incoming on-chain bitcoin', () {
    test('a short mempool wait gives a range', () {
      // 2 blocks between build and confirmation, so the estimate is trusted.
      final tx = Transaction(
        walletTransaction: _wt(
          incoming: true,
          network: Network.bitcoinMainnet,
          confirmedAt: _at('2026-09-01T12:41:00Z'),
          lockTime: 900000,
          confirmationHeight: 900002,
        ),
      );
      final anchor = TransactionAnchor.of(tx);
      expect(anchor, isA<RangeAnchor>());
      final range = anchor as RangeAnchor;
      expect(range.to, _at('2026-09-01T12:41:00Z'));
      expect(range.from, _at('2026-09-01T12:21:00Z')); // 2 blocks x 10 min
    });

    test('a long wait falls back to a single confirmation price', () {
      // 9 blocks: the 10-minutes-a-block estimate is no longer trustworthy.
      final tx = Transaction(
        walletTransaction: _wt(
          incoming: true,
          network: Network.bitcoinMainnet,
          confirmedAt: _at('2026-09-01T12:41:00Z'),
          lockTime: 900000,
          confirmationHeight: 900009,
        ),
      );
      final anchor = TransactionAnchor.of(tx);
      expect(anchor, isA<SingleAnchor>());
      expect((anchor as SingleAnchor).reason, AnchorReason.confirmed);
    });

    test('a zero locktime gives a single confirmation price', () {
      final tx = Transaction(
        walletTransaction: _wt(
          incoming: true,
          network: Network.bitcoinMainnet,
          confirmedAt: _at('2026-09-01T12:41:00Z'),
          lockTime: 0,
          confirmationHeight: 900002,
        ),
      );
      final anchor = TransactionAnchor.of(tx);
      expect(anchor, isA<SingleAnchor>());
      expect((anchor as SingleAnchor).reason, AnchorReason.confirmed);
    });

    test('a locktime that is a unix timestamp is not treated as a height', () {
      // Values of 500,000,000 and up are timestamps, not block heights.
      final tx = Transaction(
        walletTransaction: _wt(
          incoming: true,
          network: Network.bitcoinMainnet,
          confirmedAt: _at('2026-09-01T12:41:00Z'),
          lockTime: 1756819200,
          confirmationHeight: 900002,
        ),
      );
      final anchor = TransactionAnchor.of(tx);
      expect(anchor, isA<SingleAnchor>());
      expect((anchor as SingleAnchor).reason, AnchorReason.confirmed);
    });

    test('a locktime above the confirming height is rejected', () {
      final tx = Transaction(
        walletTransaction: _wt(
          incoming: true,
          network: Network.bitcoinMainnet,
          confirmedAt: _at('2026-09-01T12:41:00Z'),
          lockTime: 900005,
          confirmationHeight: 900002,
        ),
      );
      final anchor = TransactionAnchor.of(tx);
      expect(anchor, isA<SingleAnchor>());
      expect((anchor as SingleAnchor).reason, AnchorReason.confirmed);
    });
  });

  group('liquid', () {
    test('an incoming liquid payment is a single price, never a range', () {
      // Liquid confirms in about a minute, so there is nothing to bound.
      final tx = Transaction(
        walletTransaction: _wt(
          incoming: true,
          network: Network.liquidMainnet,
          confirmedAt: _at('2026-08-28T18:44:00Z'),
        ),
      );
      final anchor = TransactionAnchor.of(tx);
      expect(anchor, isA<SingleAnchor>());
      expect((anchor as SingleAnchor).at, _at('2026-08-28T18:44:00Z'));
    });
  });

  group('pending', () {
    test('an unconfirmed incoming payment has no anchor yet', () {
      final tx = Transaction(
        walletTransaction: _wt(incoming: true, network: Network.bitcoinMainnet),
      );
      expect(TransactionAnchor.of(tx), isA<NoAnchor>());
    });
  });
}
