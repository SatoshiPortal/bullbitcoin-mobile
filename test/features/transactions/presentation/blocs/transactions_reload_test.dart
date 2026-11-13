import 'dart:async';
import 'package:bb_mobile/features/transactions/domain/usecases/watch_transaction_reloads_usecase.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Ok;

import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/refresh_transaction_labels_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/watch_wallet_revisions_usecase.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/wallet/data/sync_coordinator.dart';
import 'package:bb_mobile/core/sync/sync_kind.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _Read extends Mock implements GetTransactionsUsecase {}

class _Labels extends Mock implements RefreshTransactionLabelsUsecase {}

class _Started extends Mock implements WatchStartedWalletSyncsUsecase {}

class _Finished extends Mock implements WatchFinishedWalletSyncsUsecase {}

class _Wallets extends Mock implements GetWalletsUsecase {}

class _Sync extends Mock implements SyncWalletUsecase {}

class _Wallet extends Mock implements Wallet {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(SyncReason.auto);

  testWidgets('wallet-scoped history still reloads only its own wallet', (
    tester,
  ) async {
    final read = _Read();
    final started = _Started();
    final finished = _Finished();
    final revisions = StreamController<WalletRevisionState>.broadcast();
    final finishes = StreamController<Wallet>.broadcast();
    final facade = WalletFacade(revisions.stream);
    final a = _Wallet();
    final b = _Wallet();
    when(() => a.id).thenReturn('a');
    when(() => b.id).thenReturn('b');
    when(
      () => started.execute(walletId: 'a'),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => finished.execute(walletId: 'a'),
    ).thenAnswer((_) => finishes.stream.where((wallet) => wallet.id == 'a'));
    var reads = 0;
    when(() => read.execute(walletId: 'a')).thenAnswer((_) async {
      reads++;
      return const Ok([]);
    });
    final cubit = TransactionsCubit(
      walletId: 'a',
      getTransactionsUsecase: read,
      refreshTransactionLabelsUsecase: _Labels(),
      watchStartedWalletSyncsUsecase: started,
      watchFinishedWalletSyncsUsecase: finished,
      watchWalletRevisionsUsecase: WatchWalletRevisionsUsecase(facade),
      watchTransactionReloadsUsecase: WatchTransactionReloadsUsecase(facade),
    );
    addTearDown(() async {
      await cubit.close();
      await revisions.close();
      await finishes.close();
    });
    revisions.add(_revision('b'));
    finishes.add(b);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(reads, 0);
    revisions.add(_revision('a'));
    finishes.add(a);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(reads, 1);
    verifyNever(() => read.execute(walletId: null));
  });

  testWidgets('two-wallet pass admits no history reader until completion', (
    tester,
  ) async {
    final read = _Read();
    final started = _Started();
    final finished = _Finished();
    final wallets = _Wallets();
    final sync = _Sync();
    final a = _Wallet();
    final b = _Wallet();
    final first = Completer<void>();
    final second = Completer<void>();
    final revisions = StreamController<WalletRevisionState>.broadcast();
    final finishes = StreamController<Wallet>.broadcast();
    final coordinator = SyncCoordinator(
      getWalletsUsecase: wallets,
      syncWalletUsecase: sync,
    );
    final facade = WalletFacade(
      revisions.stream,
      syncFinished: finishes.stream.map((_) {}),
      syncPassActivity: coordinator.syncPassActivity,
      isSyncPassActive: () => coordinator.isSyncPassActive,
    );
    when(() => a.id).thenReturn('a');
    when(() => b.id).thenReturn('b');
    when(
      () => wallets.execute(onlyBitcoin: true),
    ).thenAnswer((_) async => Ok([a, b]));
    var walletRuns = 0;
    for (final entry in [(a, first), (b, second)]) {
      when(
        () => sync.execute(
          entry.$1,
          discover: any(named: 'discover'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async {
        walletRuns++;
        await entry.$2.future;
        revisions.add(_revision(entry.$1.id));
        finishes.add(entry.$1);
      });
    }
    when(
      () => started.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) => const Stream.empty());
    var finishSubscriptions = 0;
    when(() => finished.execute(walletId: any(named: 'walletId'))).thenAnswer((
      _,
    ) {
      finishSubscriptions++;
      return finishes.stream;
    });
    var reads = 0;
    when(() => read.execute(walletId: any(named: 'walletId'))).thenAnswer((
      _,
    ) async {
      reads++;
      return const Ok([]);
    });
    final cubit = TransactionsCubit(
      getTransactionsUsecase: read,
      refreshTransactionLabelsUsecase: _Labels(),
      watchStartedWalletSyncsUsecase: started,
      watchFinishedWalletSyncsUsecase: finished,
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
