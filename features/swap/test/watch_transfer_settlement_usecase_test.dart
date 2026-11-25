import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:swap_feature/src/domain/usecases/watch_transfer_settlement_usecase.dart'
    as uc;
import 'package:transactions/transactions.dart';

class _MockTransactions extends Mock implements Transactions {}

WalletTransaction _tx({required bool confirmed}) => WalletTransaction(
  walletId: 'w',
  network: BitcoinNetwork.testnet,
  direction: WalletTransactionDirection.outgoing,
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
  test('forwards the wallet transaction revisions and nothing else', () async {
    final transactions = _MockTransactions();
    final source = StreamController<WalletTransaction>();
    addTearDown(source.close);
    when(
      () =>
          transactions.watchWalletTransactionByTxId(walletId: 'w', txId: 'tx'),
    ).thenAnswer((_) => source.stream);

    final seen = <WalletTransaction>[];
    final sub = uc.WatchTransferSettlementUsecase(transactions)
        .execute(walletId: 'w', txId: 'tx')
        .listen(seen.add);
    source
      ..add(_tx(confirmed: false))
      ..add(_tx(confirmed: true));
    await Future<void>.delayed(Duration.zero);

    expect(seen.map((tx) => tx.isConfirmed), [false, true]);
    await sub.cancel();
    expect(source.hasListener, isFalse);
  });
}
