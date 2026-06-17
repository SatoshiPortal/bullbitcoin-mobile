import 'dart:async';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/coins/domain/coins_error.dart';
import 'package:bb_mobile/features/coins/domain/usecases/freeze_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/get_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/unfreeze_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/utxo_sort_filter.dart';
import 'package:bb_mobile/features/coins/presentation/coins_cubit.dart';
import 'package:bb_mobile/features/coins/presentation/coins_state.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../wallet_utxo_fixture.dart';

class _MockGetUtxosUsecase extends Mock implements GetUtxosUsecase {}

class _MockFreezeUtxosUsecase extends Mock implements FreezeUtxosUsecase {}

class _MockUnfreezeUtxosUsecase extends Mock implements UnfreezeUtxosUsecase {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockWatchStarted extends Mock
    implements WatchStartedWalletSyncsUsecase {}

class _MockWatchFinished extends Mock
    implements WatchFinishedWalletSyncsUsecase {}

void main() {
  late _MockGetUtxosUsecase getUtxos;
  late _MockFreezeUtxosUsecase freezeUtxos;
  late _MockUnfreezeUtxosUsecase unfreezeUtxos;
  late _MockLabelsFacade labelsFacade;
  late _MockWatchStarted watchStarted;
  late _MockWatchFinished watchFinished;
  late StreamController<Wallet> startedController;
  late StreamController<Wallet> finishedController;

  const walletId = 'w1';

  CoinsCubit buildCubit() => CoinsCubit(
    walletId: walletId,
    getUtxosUsecase: getUtxos,
    freezeUtxosUsecase: freezeUtxos,
    unfreezeUtxosUsecase: unfreezeUtxos,
    labelsFacade: labelsFacade,
    watchStartedWalletSyncsUsecase: watchStarted,
    watchFinishedWalletSyncsUsecase: watchFinished,
  );

  setUp(() {
    getUtxos = _MockGetUtxosUsecase();
    freezeUtxos = _MockFreezeUtxosUsecase();
    unfreezeUtxos = _MockUnfreezeUtxosUsecase();
    labelsFacade = _MockLabelsFacade();
    watchStarted = _MockWatchStarted();
    watchFinished = _MockWatchFinished();
    startedController = StreamController<Wallet>.broadcast();
    finishedController = StreamController<Wallet>.broadcast();

    when(() => watchStarted.execute(walletId: any(named: 'walletId')))
        .thenAnswer((_) => startedController.stream);
    when(() => watchFinished.execute(walletId: any(named: 'walletId')))
        .thenAnswer((_) => finishedController.stream);
    when(() => labelsFacade.fetchDistinctLabels())
        .thenAnswer((_) async => <String>{});
  });

  tearDown(() {
    startedController.close();
    finishedController.close();
  });

  group('load', () {
    test('emits ready with utxos when load succeeds', () async {
      final utxos = [walletUtxoFixture(sats: 100), walletUtxoFixture(sats: 200)];
      when(() => getUtxos.execute(walletId: any(named: 'walletId')))
          .thenAnswer((_) async => utxos);

      final cubit = buildCubit();
      await cubit.load();

      expect(cubit.state.status, CoinsStatus.ready);
      expect(cubit.state.utxos, hasLength(2));
      await cubit.close();
    });

    test('emits empty when no utxos', () async {
      when(() => getUtxos.execute(walletId: any(named: 'walletId')))
          .thenAnswer((_) async => []);

      final cubit = buildCubit();
      await cubit.load();

      expect(cubit.state.status, CoinsStatus.empty);
      await cubit.close();
    });

    test('emits error holding a CoinsError on failure', () async {
      when(() => getUtxos.execute(walletId: any(named: 'walletId')))
          .thenThrow(const CoinsError.loadFailed());

      final cubit = buildCubit();
      await cubit.load();

      expect(cubit.state.status, CoinsStatus.error);
      expect(cubit.state.error, isA<LoadFailedCoinsError>());
      await cubit.close();
    });
  });

  group('selection', () {
    test('toggle adds and removes outpoints', () async {
      final cubit = buildCubit();
      cubit.enterSelect();
      cubit.toggle('tx:0');
      expect(cubit.state.selectedOutpoints, {'tx:0'});
      cubit.toggle('tx:0');
      expect(cubit.state.selectedOutpoints, isEmpty);
      await cubit.close();
    });

    test('selectAllUnfrozen selects only unfrozen visible coins', () async {
      final utxos = [
        walletUtxoFixture(sats: 100, txId: 'a', isFrozen: false),
        walletUtxoFixture(sats: 200, txId: 'b', isFrozen: true),
      ];
      when(() => getUtxos.execute(walletId: any(named: 'walletId')))
          .thenAnswer((_) async => utxos);

      final cubit = buildCubit();
      await cubit.load();
      cubit.enterSelect();
      cubit.selectAllUnfrozen();

      expect(cubit.state.selectedOutpoints, {'a:0'});
      await cubit.close();
    });

    test('reload silently prunes a vanished selected outpoint', () async {
      final initial = [walletUtxoFixture(txId: 'a'), walletUtxoFixture(txId: 'b')];
      when(() => getUtxos.execute(walletId: any(named: 'walletId')))
          .thenAnswer((_) async => initial);

      final cubit = buildCubit();
      await cubit.load();
      cubit.enterSelect();
      cubit.toggle('a:0');
      cubit.toggle('b:0');
      expect(cubit.state.selectedOutpoints, {'a:0', 'b:0'});

      // 'b' is spent — gone from the next load.
      when(() => getUtxos.execute(walletId: any(named: 'walletId')))
          .thenAnswer((_) async => [walletUtxoFixture(txId: 'a')]);
      await cubit.load();

      expect(cubit.state.selectedOutpoints, {'a:0'});
      await cubit.close();
    });
  });

  group('freeze / unfreeze', () {
    test('freeze success reloads and exits selection', () async {
      when(() => getUtxos.execute(walletId: any(named: 'walletId')))
          .thenAnswer((_) async => [walletUtxoFixture(txId: 'a')]);
      when(
        () => freezeUtxos.execute(
          walletId: any(named: 'walletId'),
          outpoints: any(named: 'outpoints'),
        ),
      ).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.load();
      cubit.enterSelect();
      cubit.toggle('a:0');

      final ok = await cubit.freeze(['a:0']);

      expect(ok, isTrue);
      expect(cubit.state.selecting, isFalse);
      expect(cubit.state.selectedOutpoints, isEmpty);
      expect(cubit.state.error, isNull);
      verify(
        () => freezeUtxos.execute(
          walletId: walletId,
          outpoints: [(txId: 'a', vout: 0)],
        ),
      ).called(1);
      await cubit.close();
    });

    test('freeze failure holds error and preserves selection', () async {
      when(() => getUtxos.execute(walletId: any(named: 'walletId')))
          .thenAnswer((_) async => [walletUtxoFixture(txId: 'a')]);
      when(
        () => freezeUtxos.execute(
          walletId: any(named: 'walletId'),
          outpoints: any(named: 'outpoints'),
        ),
      ).thenThrow(const CoinsError.freezeFailed());

      final cubit = buildCubit();
      await cubit.load();
      cubit.enterSelect();
      cubit.toggle('a:0');

      final ok = await cubit.freeze(['a:0']);

      // Returns false on failure so the UI can gate the success toast on the
      // return value rather than re-reading state.error (which the listener
      // clears before the awaiting caller resumes).
      expect(ok, isFalse);
      expect(cubit.state.selecting, isTrue);
      expect(cubit.state.selectedOutpoints, {'a:0'});
      expect(cubit.state.error, isA<FreezeFailedCoinsError>());
      await cubit.close();
    });

    test('unfreeze failure holds error and preserves selection', () async {
      when(() => getUtxos.execute(walletId: any(named: 'walletId')))
          .thenAnswer((_) async => [walletUtxoFixture(txId: 'a', isFrozen: true)]);
      when(
        () => unfreezeUtxos.execute(
          walletId: any(named: 'walletId'),
          outpoints: any(named: 'outpoints'),
        ),
      ).thenThrow(const CoinsError.unfreezeFailed());

      final cubit = buildCubit();
      await cubit.load();
      cubit.enterSelect();
      cubit.toggle('a:0');

      final ok = await cubit.unfreeze(['a:0']);

      expect(ok, isFalse);
      expect(cubit.state.selecting, isTrue);
      expect(cubit.state.selectedOutpoints, {'a:0'});
      expect(cubit.state.error, isA<UnfreezeFailedCoinsError>());
      await cubit.close();
    });
  });

  group('reactive refresh via sync streams', () {
    test('started sets syncing=true; finished triggers debounced reload', () {
      fakeAsync((async) {
        var loadCalls = 0;
        when(() => getUtxos.execute(walletId: any(named: 'walletId')))
            .thenAnswer((_) async {
          loadCalls++;
          return [walletUtxoFixture()];
        });

        final cubit = buildCubit();

        // Sync started → syncing flips true.
        startedController.add(_fakeWallet());
        async.flushMicrotasks();
        expect(cubit.state.syncing, isTrue);

        // Sync finished → reload only after the debounce window.
        finishedController.add(_fakeWallet());
        async.flushMicrotasks();
        expect(loadCalls, 0);

        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(loadCalls, 1);

        cubit.close();
        async.flushMicrotasks();
      });
    });

    test('rapid finished events collapse to a single reload (debounce)', () {
      fakeAsync((async) {
        var loadCalls = 0;
        when(() => getUtxos.execute(walletId: any(named: 'walletId')))
            .thenAnswer((_) async {
          loadCalls++;
          return [walletUtxoFixture()];
        });

        final cubit = buildCubit();

        finishedController.add(_fakeWallet());
        async.elapse(const Duration(seconds: 1));
        finishedController.add(_fakeWallet());
        async.elapse(const Duration(seconds: 1));
        finishedController.add(_fakeWallet());

        // Only the last timer survives; advance past it.
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(loadCalls, 1);

        cubit.close();
        async.flushMicrotasks();
      });
    });
  });

  group('filters', () {
    test('clearFilters preserves the current sort', () async {
      final cubit = buildCubit();
      cubit.applyFilter(
        const CoinsFilter(
          sort: CoinsSort.amountAsc,
          frozen: FrozenFilter.frozen,
        ),
      );
      cubit.clearFilters();
      expect(cubit.state.filter.sort, CoinsSort.amountAsc);
      expect(cubit.state.filter.hasActiveFilter, isFalse);
      await cubit.close();
    });
  });
}

Wallet _fakeWallet() => _FakeWallet();

class _FakeWallet extends Fake implements Wallet {
  @override
  String get id => 'w1';
}
