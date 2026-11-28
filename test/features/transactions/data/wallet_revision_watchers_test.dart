import 'package:primitives/primitives.dart';

import 'dart:async';

import 'package:transactions/testing.dart';
import 'package:sync/sync.dart'
    show WalletKey, WalletLifecycle, WalletRevision, WalletRevisionState;
import 'package:primitives/primitives.dart' as primitives;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Transactions extends Mock implements WalletTransactionRepository {}

void main() {
  test(
    'receive and transaction detail watchers re-read a committed revision',
    () async {
      final revisions = StreamController<WalletRevisionState>.broadcast();
      final facade = walletHistoryEvents(revisions.stream);
      final repository = _Transactions();
      const tx = WalletTransaction(
        walletId: 'fixture',
        network: BitcoinNetwork.testnet,
        direction: WalletTransactionDirection.incoming,
        status: WalletTransactionStatus.confirmed,
        txId: 'fixture-tx',
        amountSat: 1,
        feeSat: 0,
        vsize: 100,
        inputs: [],
        outputs: [],
        isRbf: false,
      );
      when(
        () => repository.getWalletTransactions(
          walletId: 'fixture',
          toAddress: 'fixture-address',
        ),
      ).thenAnswer((_) async => Ok([tx]));
      when(
        () =>
            repository.getWalletTransaction('fixture-tx', walletId: 'fixture'),
      ).thenAnswer((_) async => Ok(tx));
      final addressUpdates = <WalletTransaction>[];
      final byAddress =
          WatchWalletTransactionByAddressUsecase(
                walletTransactionRepository: repository,
                walletFacade: facade,
              )
              .execute(walletId: 'fixture', toAddress: 'fixture-address')
              .listen(addressUpdates.add);
      final byId = WatchWalletTransactionByTxIdUsecase(
        walletTransactionRepository: repository,
        walletFacade: facade,
      ).execute(walletId: 'fixture', txId: 'fixture-tx').first;
      WalletRevisionState revision(String id) => WalletRevisionState(
        stamp: WalletRevision(
          key: WalletKey(id: id, network: primitives.BitcoinNetwork.testnet),
          generation: 1,
          revision: 1,
        ),
        lifecycle: WalletLifecycle.active,
        initializedSchema: 1,
      );
      await pumpEventQueue();
      expect(addressUpdates, [tx]);
      verify(
        () => repository.getWalletTransactions(
          walletId: 'fixture',
          toAddress: 'fixture-address',
        ),
      ).called(1);
      clearInteractions(repository);
      revisions.add(revision('other'));
      await pumpEventQueue();
      verifyZeroInteractions(repository);
      revisions.add(revision('fixture'));
      expect(await byId, tx);
      await pumpEventQueue();
      expect(addressUpdates, [tx, tx]);
      verify(
        () => repository.getWalletTransactions(
          walletId: 'fixture',
          toAddress: 'fixture-address',
        ),
      ).called(1);
      await byAddress.cancel();
      await revisions.close();
    },
  );
}
