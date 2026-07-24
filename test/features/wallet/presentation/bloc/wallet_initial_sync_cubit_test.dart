import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_bitcoin_sync_backend_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/start_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_sync_progress_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_initial_sync_cubit.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchWalletSyncProgressUsecase extends Mock
    implements WatchWalletSyncProgressUsecase {}

class _MockGetBitcoinSyncBackendUsecase extends Mock
    implements GetBitcoinSyncBackendUsecase {}

class _MockStartWalletSyncUsecase extends Mock
    implements StartWalletSyncUsecase {}

const _walletId = 'w1';

void main() {
  late _MockWatchWalletSyncProgressUsecase watchUsecase;
  late _MockGetBitcoinSyncBackendUsecase getBackendUsecase;
  late _MockStartWalletSyncUsecase startUsecase;
  late StreamController<WalletSyncProgress> controller;

  setUp(() {
    watchUsecase = _MockWatchWalletSyncProgressUsecase();
    getBackendUsecase = _MockGetBitcoinSyncBackendUsecase();
    startUsecase = _MockStartWalletSyncUsecase();
    controller = StreamController<WalletSyncProgress>.broadcast();
    when(() => watchUsecase.execute()).thenAnswer((_) => controller.stream);
    when(() => getBackendUsecase.execute(walletId: any(named: 'walletId')))
        .thenAnswer(
          (_) async => const Ok(BitcoinSyncBackend.compactBlockFilters),
        );
    when(
      () => startUsecase.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => const Ok(null));
  });

  tearDown(() => controller.close());

  WalletInitialSyncCubit buildCubit({String walletId = _walletId}) =>
      WalletInitialSyncCubit(
        walletId: walletId,
        watchWalletSyncProgressUsecase: watchUsecase,
        getBitcoinSyncBackendUsecase: getBackendUsecase,
        startWalletSyncUsecase: startUsecase,
      );

  test('subscribes to progress before ever verifying the backend or '
      'invoking StartWalletSyncUsecase', () {
    final calls = <String>[];
    when(() => watchUsecase.execute()).thenAnswer((_) {
      calls.add('watch');
      return controller.stream;
    });
    when(() => getBackendUsecase.execute(walletId: any(named: 'walletId')))
        .thenAnswer((_) async {
          calls.add('getBackend');
          return const Ok(BitcoinSyncBackend.compactBlockFilters);
        });
    when(
      () => startUsecase.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async {
      calls.add('start');
      return const Ok(null);
    });

    fakeAsync((async) {
      buildCubit();
      async.flushMicrotasks();

      expect(calls, ['watch', 'getBackend', 'start']);
    });
  });

  test('a progress event broadcast synchronously right after construction '
      'is still observed — the subscription is already active before any '
      'async gate (backend verification/start) has even resumed', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      // Still fully synchronous: no microtask has run yet, so if the
      // subscription were set up lazily (e.g. after awaiting the backend
      // check) this event would be lost on a broadcast stream.
      controller.add(
        const WalletSyncStarted('w1', BitcoinSyncBackend.compactBlockFilters),
      );
      async.flushMicrotasks();

      expect(cubit.state.phase, WalletInitialSyncPhase.connecting);
    });
  });

  test(
    'an immediate Err from StartWalletSyncUsecase settles failed on its '
    'own, with no progress event ever required (refused-before-entry '
    'failures never reach the progress stream)',
    () {
      when(
        () => startUsecase.execute(walletId: any(named: 'walletId')),
      ).thenAnswer(
        (_) async => const Err(WalletSyncDeveloperGateClosedFailure()),
      );

      fakeAsync((async) {
        final cubit = buildCubit();
        async.flushMicrotasks();

        expect(cubit.state.phase, WalletInitialSyncPhase.failed);
      });
    },
  );

  test(
    'a non-CBF backend never starts a sync and settles failed — defense in '
    'depth independent of WalletRouter\'s own routing decision',
    () {
      when(() => getBackendUsecase.execute(walletId: any(named: 'walletId')))
          .thenAnswer((_) async => const Ok(BitcoinSyncBackend.electrum));

      fakeAsync((async) {
        final cubit = buildCubit();
        async.flushMicrotasks();

        expect(cubit.state.phase, WalletInitialSyncPhase.failed);
        verifyNever(
          () => startUsecase.execute(walletId: any(named: 'walletId')),
        );
      });
    },
  );

  test(
    'a backend lookup failure never starts a sync and settles failed',
    () {
      when(
        () => getBackendUsecase.execute(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => const Err(WalletSyncWalletNotFoundFailure()));

      fakeAsync((async) {
        final cubit = buildCubit();
        async.flushMicrotasks();

        expect(cubit.state.phase, WalletInitialSyncPhase.failed);
        verifyNever(
          () => startUsecase.execute(walletId: any(named: 'walletId')),
        );
      });
    },
  );

  test('a verified CBF backend starts the sync exactly once', () {
    fakeAsync((async) {
      buildCubit();
      async.flushMicrotasks();

      verify(() => startUsecase.execute(walletId: 'w1')).called(1);
    });
  });

  test('WalletSyncScanning moves the phase to scanning', () {
    fakeAsync((async) {
      final cubit = buildCubit();
      async.flushMicrotasks();

      controller.add(const WalletSyncScanning('w1', scannedPercent: 40));
      async.flushMicrotasks();

      expect(cubit.state.phase, WalletInitialSyncPhase.scanning);
    });
  });

  test('WalletSyncCompleted moves the phase to completed', () {
    fakeAsync((async) {
      final cubit = buildCubit();
      async.flushMicrotasks();

      controller.add(const WalletSyncCompleted('w1'));
      async.flushMicrotasks();

      expect(cubit.state.phase, WalletInitialSyncPhase.completed);
      expect(cubit.state.isCompleted, isTrue);
    });
  });

  test('WalletSyncFailed on the progress stream moves the phase to failed', () {
    fakeAsync((async) {
      final cubit = buildCubit();
      async.flushMicrotasks();

      controller.add(
        const WalletSyncFailed(
          'w1',
          WalletSyncFailureCategory.compactBlockFilters,
        ),
      );
      async.flushMicrotasks();

      expect(cubit.state.phase, WalletInitialSyncPhase.failed);
      expect(cubit.state.isFailed, isTrue);
    });
  });

  test(
    'WalletSyncCancelled settles failed defensively rather than leaving the '
    'screen stuck on an indeterminate spinner',
    () {
      fakeAsync((async) {
        final cubit = buildCubit();
        async.flushMicrotasks();

        controller.add(const WalletSyncCancelled('w1'));
        async.flushMicrotasks();

        expect(cubit.state.phase, WalletInitialSyncPhase.failed);
      });
    },
  );

  test('ignores a progress event for a different wallet', () {
    fakeAsync((async) {
      final cubit = buildCubit();
      async.flushMicrotasks();
      final phaseAfterStart = cubit.state.phase;

      controller.add(const WalletSyncCompleted('some-other-wallet'));
      async.flushMicrotasks();

      expect(cubit.state.phase, phaseAfterStart);
    });
  });

  test('retry() re-verifies the backend and calls StartWalletSyncUsecase '
      'again', () {
    fakeAsync((async) {
      final cubit = buildCubit();
      async.flushMicrotasks();
      verify(() => getBackendUsecase.execute(walletId: 'w1')).called(1);
      verify(() => startUsecase.execute(walletId: 'w1')).called(1);

      controller.add(
        const WalletSyncFailed(
          'w1',
          WalletSyncFailureCategory.compactBlockFilters,
        ),
      );
      async.flushMicrotasks();
      expect(cubit.state.phase, WalletInitialSyncPhase.failed);

      unawaited(cubit.retry());
      async.flushMicrotasks();

      // mocktail's `verify(...).called(n)` only counts calls not already
      // marked verified by an earlier `verify` on the same mock/args (see
      // `_VerifyCall` in package:mocktail) — not a cumulative total. Each
      // check above already consumed the first call, so retry's own call
      // is the only one left to match here.
      verify(() => getBackendUsecase.execute(walletId: 'w1')).called(1);
      verify(() => startUsecase.execute(walletId: 'w1')).called(1);
    });
  });

  test('close() cancels the subscription without throwing', () {
    fakeAsync((async) {
      final cubit = buildCubit();
      async.flushMicrotasks();

      expect(cubit.close(), completes);
      async.flushMicrotasks();

      // A late event after close() must not throw or emit on a closed
      // cubit.
      expect(
        () => controller.add(const WalletSyncCompleted('w1')),
        returnsNormally,
      );
      async.flushMicrotasks();
    });
  });
}
