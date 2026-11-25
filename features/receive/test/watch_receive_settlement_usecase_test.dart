import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:receive/src/domain/usecases/watch_receive_settlement_usecase.dart';
import 'package:transactions/transactions.dart';

class _MockTransactions extends Mock implements Transactions {}

WalletTransaction _tx({required bool confirmed}) => WalletTransaction(
  walletId: 'w',
  network: BitcoinNetwork.testnet,
  direction: WalletTransactionDirection.incoming,
  status: confirmed
      ? WalletTransactionStatus.confirmed
      : WalletTransactionStatus.pending,
  txId: 'tx',
  amountSat: 1000,
  feeSat: 10,
  vsize: 140,
  inputs: const [],
  outputs: const [],
  isRbf: false,
);

void main() {
  test(
    'forwards the wallet transaction revisions and cancels with them',
    () async {
      final transactions = _MockTransactions();
      final source = StreamController<WalletTransaction>();
      addTearDown(source.close);
      when(
        () => transactions.watchWalletTransactionByTxId(
          walletId: 'w',
          txId: 'tx',
        ),
      ).thenAnswer((_) => source.stream);

      final seen = <WalletTransaction>[];
      final sub = WatchReceiveSettlementUsecase(transactions)
          .execute(walletId: 'w', txId: 'tx')
          .listen(seen.add);
      source.add(_tx(confirmed: false));
      source.add(_tx(confirmed: true));
      await pumpEventQueue();
      expect(seen.map((tx) => tx.isConfirmed), [false, true]);
      await sub.cancel();
      expect(source.hasListener, isFalse);
    },
  );
}
