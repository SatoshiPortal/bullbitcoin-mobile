import 'package:transactions/testing.dart';

import 'dart:async';

import 'package:primitives/primitives.dart' show BitcoinNetwork, Failure, Ok;

import 'package:overview/setup.dart';
import 'package:overview/overview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sync/sync.dart' hide Wallet;

class _Read extends Mock implements GetTransactionsUsecase {}

class _Labels extends Mock implements RefreshTransactionLabelsUsecase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('wallet-scoped history still reloads only its own wallet', (
    tester,
  ) async {
    final read = _Read();
    final revisions = StreamController<WalletRevisionState>.broadcast();
    final finishes = StreamController<String>.broadcast();
    final facade = walletHistoryEvents(revisions.stream);
    var reads = 0;
    when(() => read.execute(walletId: 'a')).thenAnswer((_) async {
      reads++;
      return const Ok(
        TransactionHistory(
          transactions: [],
          exchangeOrders: ExchangeOrdersMerged(),
        ),
      );
    });
    final cubit = TransactionsCubit(
      walletId: 'a',
      getTransactionsUsecase: read,
      refreshTransactionLabelsUsecase: _Labels(),
      watchStartedWalletSyncsUsecase: const Stream.empty(),
      watchFinishedWalletSyncsUsecase: finishes.stream,
      watchWalletRevisionsUsecase: WatchWalletRevisionsUsecase(facade),
      watchTransactionReloadsUsecase: WatchTransactionReloadsUsecase(facade),
    );
    addTearDown(() async {
      await cubit.close();
      await revisions.close();
      await finishes.close();
    });
    revisions.add(_revision('b'));
    finishes.add('b');
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(reads, 0);
    revisions.add(_revision('a'));
    finishes.add('a');
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(reads, 1);
    verifyNever(() => read.execute(walletId: null));
  });

  testWidgets('two-wallet pass admits no history reader until completion', (
    tester,
  ) async {
    final read = _Read();
    final a = WalletKey(id: 'a', network: BitcoinNetwork.mainnet);
    final b = WalletKey(id: 'b', network: BitcoinNetwork.mainnet);
    final first = Completer<void>();
    final second = Completer<void>();
    final revisions = StreamController<WalletRevisionState>.broadcast();
    final finishes = StreamController<WalletKey>.broadcast();
    var walletRuns = 0;
    final coordinator = SyncCoordinator<WalletKey, Failure>(
      walletKey: (wallet) => wallet,
      classifyFailure: (_) => (empty: false, code: 'unexpected'),
      getWallets: ({onlyBitcoin, onlyLiquid}) async =>
          Ok(WalletRead<WalletKey, Failure>([a, b])),
      syncWallet:
          (
            wallet, {
            discover = false,
            allowInitialScan = false,
            reason = SyncReason.auto,
          }) async {
            walletRuns++;
            await (wallet == a ? first.future : second.future);
            revisions.add(_revision(wallet.id));
            finishes.add(wallet);
          },
    );
    final facade = walletHistoryEvents(
      revisions.stream,
      syncFinished: finishes.stream.map((_) {}),
      syncPassActivity: coordinator.syncPassActivity,
      isSyncPassActive: () => coordinator.isSyncPassActive,
    );
    var finishSubscriptions = 0;
    final legacyFinishes = StreamController<String>.broadcast(
      onListen: () => finishSubscriptions++,
    );
    addTearDown(legacyFinishes.close);
    var reads = 0;
    when(() => read.execute(walletId: any(named: 'walletId')))
        .thenAnswer((_) async {
          reads++;
          return const Ok(
            TransactionHistory(
              transactions: [],
              exchangeOrders: ExchangeOrdersMerged(),
            ),
          );
        });
    final cubit = TransactionsCubit(
      getTransactionsUsecase: read,
      refreshTransactionLabelsUsecase: _Labels(),
      watchStartedWalletSyncsUsecase: const Stream.empty(),
      watchFinishedWalletSyncsUsecase: legacyFinishes.stream,
      watchWalletRevisionsUsecase: WatchWalletRevisionsUsecase(facade),
      watchTransactionReloadsUsecase: WatchTransactionReloadsUsecase(facade),
    );
    addTearDown(() async {
      await cubit.close();
      coordinator.dispose();
      await revisions.close();
      await finishes.close();
    });
    final pass = coordinator.sync(
      only: {SyncKind.bitcoin},
      trigger: SyncTrigger.user,
    );
    await tester.pump();
    expect(walletRuns, 1);
    expect(cubit.state.isSyncing, isTrue);
    first.complete();
    await tester.pump();
    expect(walletRuns, 2);
    await tester.pump(const Duration(seconds: 4));
    expect(
      reads,
      0,
      reason: 'wallet A must not admit readers while B is syncing',
    );
    expect(cubit.state.isSyncing, isTrue);
    second.complete();
    await tester.pump();
    await pass;
    await tester.pump(const Duration(seconds: 4));
    expect(reads, 1);
    expect(cubit.state.isSyncing, isFalse);
    expect(
      finishSubscriptions,
      0,
      reason: 'legacy finishes hydrate every wallet before filtering',
    );
  });
}

WalletRevisionState _revision(
  String id, {
  WalletLifecycle lifecycle = WalletLifecycle.active,
  int generation = 0,
}) => WalletRevisionState(
  stamp: WalletRevision(
    key: WalletKey(id: id, network: BitcoinNetwork.mainnet),
    generation: generation,
    revision: 1,
  ),
  lifecycle: lifecycle,
);
