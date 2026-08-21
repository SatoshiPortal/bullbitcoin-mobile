import 'dart:async';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/refresh_transaction_labels_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetTransactionsUsecase extends Mock
    implements GetTransactionsUsecase {}

class _MockRefreshTransactionLabelsUsecase extends Mock
    implements RefreshTransactionLabelsUsecase {}

class _MockWatchStartedWalletSyncsUsecase extends Mock
    implements WatchStartedWalletSyncsUsecase {}

class _MockWatchFinishedWalletSyncsUsecase extends Mock
    implements WatchFinishedWalletSyncsUsecase {}

Transaction _transaction({List<Label> labels = const []}) {
  return Transaction(
    walletTransaction: WalletTransaction(
      walletId: 'wallet-1',
      network: Network.bitcoinMainnet,
      direction: WalletTransactionDirection.incoming,
      status: WalletTransactionStatus.confirmed,
      txId: 'txid-1',
      amountSat: 100000,
      feeSat: 0,
      vsize: 141,
      inputs: const [],
      outputs: const [],
      labels: labels,
      isRbf: false,
    ),
  );
}

void main() {
  late _MockGetTransactionsUsecase getTransactionsUsecase;
  late _MockRefreshTransactionLabelsUsecase refreshTransactionLabelsUsecase;
  late _MockWatchStartedWalletSyncsUsecase watchStartedWalletSyncsUsecase;
  late _MockWatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase;
  late TransactionsCubit cubit;
  late int emissions;

  setUp(() {
    getTransactionsUsecase = _MockGetTransactionsUsecase();
    refreshTransactionLabelsUsecase = _MockRefreshTransactionLabelsUsecase();
    watchStartedWalletSyncsUsecase = _MockWatchStartedWalletSyncsUsecase();
    watchFinishedWalletSyncsUsecase = _MockWatchFinishedWalletSyncsUsecase();

    when(
      () => watchStartedWalletSyncsUsecase.execute(
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => watchFinishedWalletSyncsUsecase.execute(
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) => const Stream.empty());

    cubit = TransactionsCubit(
      getTransactionsUsecase: getTransactionsUsecase,
      refreshTransactionLabelsUsecase: refreshTransactionLabelsUsecase,
      watchStartedWalletSyncsUsecase: watchStartedWalletSyncsUsecase,
      watchFinishedWalletSyncsUsecase: watchFinishedWalletSyncsUsecase,
    );
    emissions = 0;
    cubit.stream.listen((_) => emissions++);
  });

  tearDown(() async => cubit.close());

  group('TransactionsCubit.refreshLabels', () {
    test('shows a label added while the details screen was open, without '
        'reloading the transactions', () async {
      cubit.emit(TransactionsState(transactions: [_transaction()]));
      final relabelled = _transaction(
        labels: [Label.tx(id: 1, transactionId: 'txid-1', label: 'rent')],
      );
      when(
        () => refreshTransactionLabelsUsecase.execute(any()),
      ).thenAnswer((_) async => [relabelled]);

      await cubit.refreshLabels();

      expect(cubit.state.transactions?.single.labels?.single.label, 'rent');
      // A local re-read, not a full reload: that one hits the network.
      verifyNever(
        () => getTransactionsUsecase.execute(
          walletId: any(named: 'walletId'),
          sync: any(named: 'sync'),
        ),
      );
    });

    test('emits nothing when no label changed', () async {
      cubit.emit(TransactionsState(transactions: [_transaction()]));
      await pumpEventQueue();
      final emissionsBefore = emissions;
      // The use case hands back the list it was given when nothing changed.
      when(() => refreshTransactionLabelsUsecase.execute(any())).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments.first as List<Transaction>,
      );

      await cubit.refreshLabels();
      await pumpEventQueue();

      expect(emissions, emissionsBefore);
    });

    test('drops its result when a load landed while it was reading', () async {
      cubit.emit(TransactionsState(transactions: [_transaction()]));
      final relabelled = _transaction(
        labels: [Label.tx(id: 1, transactionId: 'txid-1', label: 'rent')],
      );
      final freshlySynced = _transaction(
        labels: [Label.tx(id: 2, transactionId: 'txid-1', label: 'synced')],
      );
      // Hold the label read open so the load can land underneath it.
      final labelRead = Completer<List<Transaction>>();
      when(
        () => refreshTransactionLabelsUsecase.execute(any()),
      ).thenAnswer((_) => labelRead.future);
      when(
        () => getTransactionsUsecase.execute(
          walletId: any(named: 'walletId'),
          sync: any(named: 'sync'),
        ),
      ).thenAnswer((_) async => [freshlySynced]);

      final refresh = cubit.refreshLabels();
      await cubit.loadTxs();
      labelRead.complete([relabelled]);
      await refresh;

      // The load's transactions win: they are newer and were hydrated with
      // freshly read labels anyway.
      expect(cubit.state.transactions, [freshlySynced]);
    });

    test('does nothing before the first load', () async {
      await cubit.refreshLabels();
      await pumpEventQueue();

      expect(emissions, 0);
      verifyNever(() => refreshTransactionLabelsUsecase.execute(any()));
    });
  });
}
