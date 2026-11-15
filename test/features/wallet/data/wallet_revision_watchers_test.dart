import 'dart:async';

import 'package:bb_mobile/features/wallet/domain/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:primitives/primitives.dart' as primitives;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Transactions extends Mock implements WalletTransactionRepository {}

void main() {
  test(
    'receive and transaction detail watchers re-read a committed revision',
    () async {
      final revisions = StreamController<WalletRevisionState>.broadcast();
      final facade = WalletFacade(revisions.stream);
      final repository = _Transactions();
      const tx = WalletTransaction(
        walletId: 'fixture',
        network: Network.bitcoinTestnet,
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
      ).thenAnswer((_) async => [tx]);
      when(
        () =>
            repository.getWalletTransaction('fixture-tx', walletId: 'fixture'),
      ).thenAnswer((_) async => tx);
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
