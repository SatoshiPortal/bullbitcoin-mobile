import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_warning.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/cancel_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/start_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_sync_progress_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_sync_progress_cubit.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchWalletSyncProgressUsecase extends Mock
    implements WatchWalletSyncProgressUsecase {}

class _MockCancelWalletSyncUsecase extends Mock
    implements CancelWalletSyncUsecase {}

class _MockStartWalletSyncUsecase extends Mock
    implements StartWalletSyncUsecase {}

void main() {
  late _MockWatchWalletSyncProgressUsecase watchUsecase;
  late _MockCancelWalletSyncUsecase cancelUsecase;
  late _MockStartWalletSyncUsecase startUsecase;
  late StreamController<WalletSyncProgress> controller;

  setUp(() {
    watchUsecase = _MockWatchWalletSyncProgressUsecase();
    cancelUsecase = _MockCancelWalletSyncUsecase();
    startUsecase = _MockStartWalletSyncUsecase();
    controller = StreamController<WalletSyncProgress>.broadcast();
    when(() => watchUsecase.execute()).thenAnswer((_) => controller.stream);
    when(
      () => cancelUsecase.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async {});
    when(
      () => startUsecase.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => const Ok(null));
  });

  tearDown(() => controller.close());

  WalletSyncProgressCubit buildCubit({
    Duration completedConfirmationDuration = const Duration(seconds: 3),
  }) => WalletSyncProgressCubit(
    watchWalletSyncProgressUsecase: watchUsecase,
    cancelWalletSyncUsecase: cancelUsecase,
    startWalletSyncUsecase: startUsecase,
    completedConfirmationDuration: completedConfirmationDuration,
  );

  test('subscribes exactly once at construction', () {
    buildCubit();
    verify(() => watchUsecase.execute()).called(1);
  });

  test('a bare Started tagged electrum never creates a tracked entry (ordinary '
      'Electrum sync)', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(
        const WalletSyncStarted('w1', BitcoinSyncBackend.electrum),
      );
      async.flushMicrotasks();

      expect(cubit.state.entries, isEmpty);
    });
  });

  test('a Started tagged compactBlockFilters immediately creates a connecting, '
      'confirmed-CBF entry — no heuristic delay waiting for Scanning', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(
        const WalletSyncStarted('w1', BitcoinSyncBackend.compactBlockFilters),
      );
      async.flushMicrotasks();

      final entry = cubit.state.forWallet('w1');
      expect(entry, isNotNull);
      expect(entry!.isConfirmedCbf, isTrue);
      expect(entry.phase, WalletSyncProgressPhase.connecting);
    });
  });

  test('Scanning confirms CBF and tracks a determinate percent', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(
        const WalletSyncStarted('w1', BitcoinSyncBackend.compactBlockFilters),
      );
      controller.add(
        const WalletSyncScanning('w1', scannedPercent: 42, chainHeight: 100),
      );
      async.flushMicrotasks();

      final entry = cubit.state.forWallet('w1');
      expect(entry, isNotNull);
      expect(entry!.isConfirmedCbf, isTrue);
      expect(entry.phase, WalletSyncProgressPhase.scanning);
      expect(entry.scannedPercent, 42);
    });
  });

  test(
    'Scanning with no percent yet stays indeterminate but still confirms CBF',
    () {
      fakeAsync((async) {
        final cubit = buildCubit();

        controller.add(const WalletSyncScanning('w1'));
        async.flushMicrotasks();

        final entry = cubit.state.forWallet('w1');
        expect(entry!.isConfirmedCbf, isTrue);
        expect(entry.scannedPercent, isNull);
      });
    },
  );

  test(
    'a later Scanning with null percent clears a previously known percent',
    () {
      fakeAsync((async) {
        final cubit = buildCubit();

        controller.add(const WalletSyncScanning('w1', scannedPercent: 10));
        async.flushMicrotasks();
        expect(cubit.state.forWallet('w1')?.scannedPercent, 10);

        controller.add(const WalletSyncScanning('w1'));
        async.flushMicrotasks();
        expect(cubit.state.forWallet('w1')?.scannedPercent, isNull);
      });
    },
  );

  test('a connected stage sets hasConnected sticky even after moving past it '
      'to a later stage', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(
        const WalletSyncScanning('w1', stage: WalletSyncScanStage.connected),
      );
      controller.add(
        const WalletSyncScanning(
          'w1',
          stage: WalletSyncScanStage.matchingBlocks,
          receivedBlockCount: 3,
        ),
      );
      async.flushMicrotasks();

      final entry = cubit.state.forWallet('w1');
      expect(entry!.hasConnected, isTrue);
      expect(entry.scanStage, WalletSyncScanStage.matchingBlocks);
      expect(entry.receivedBlockCount, 3);
    });
  });

  test('a syncingHeaders stage carries chainHeight but never a scannedPercent, '
      'and downloadingFilters afterwards carries both', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(
        const WalletSyncScanning(
          'w1',
          stage: WalletSyncScanStage.syncingHeaders,
          chainHeight: 100,
        ),
      );
      async.flushMicrotasks();
      var entry = cubit.state.forWallet('w1');
      expect(entry!.scanStage, WalletSyncScanStage.syncingHeaders);
      expect(entry.chainHeight, 100);
      expect(entry.scannedPercent, isNull);
      expect(entry.hasFilterProgress, isFalse);

      controller.add(
        const WalletSyncScanning(
          'w1',
          stage: WalletSyncScanStage.downloadingFilters,
          scannedPercent: 30,
          chainHeight: 105,
        ),
      );
      async.flushMicrotasks();
      entry = cubit.state.forWallet('w1');
      expect(entry!.scanStage, WalletSyncScanStage.downloadingFilters);
      expect(entry.scannedPercent, 30);
      // chainHeight is a sticky local count, never reset by a later event.
      expect(entry.chainHeight, 105);
      expect(entry.hasFilterProgress, isTrue);
    });
  });

  test('an applyingUpdate stage sets hasReachedApplyingUpdate sticky, and it '
      'survives into a failed outcome as diagnostic context', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(
        const WalletSyncScanning(
          'w1',
          stage: WalletSyncScanStage.applyingUpdate,
        ),
      );
      async.flushMicrotasks();
      expect(cubit.state.forWallet('w1')?.hasReachedApplyingUpdate, isTrue);

      controller.add(
        const WalletSyncFailed(
          'w1',
          WalletSyncFailureCategory.compactBlockFilters,
        ),
      );
      async.flushMicrotasks();

      final entry = cubit.state.forWallet('w1');
      expect(entry!.hasReachedApplyingUpdate, isTrue);
      expect(entry.phase, WalletSyncProgressPhase.failed);
    });
  });

  test('once applyingUpdate is reached, a later stale/out-of-order Scanning '
      'event never regresses the displayed stage (or its percent/height/'
      'block count) back to an earlier one', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(
        const WalletSyncScanning(
          'w1',
          stage: WalletSyncScanStage.applyingUpdate,
        ),
      );
      async.flushMicrotasks();
      var entry = cubit.state.forWallet('w1');
      expect(entry!.scanStage, WalletSyncScanStage.applyingUpdate);

      // A stale native event arriving after applyingUpdate must not flip
      // the headline stage — or the fields tied to it — back down.
      controller.add(
        const WalletSyncScanning(
          'w1',
          stage: WalletSyncScanStage.matchingBlocks,
          scannedPercent: 40,
          chainHeight: 999,
          receivedBlockCount: 7,
        ),
      );
      async.flushMicrotasks();

      entry = cubit.state.forWallet('w1');
      expect(entry!.scanStage, WalletSyncScanStage.applyingUpdate);
      expect(entry.scannedPercent, isNull);
      expect(entry.chainHeight, isNull);
      expect(entry.receivedBlockCount, 0);
      // Sticky diagnostic flags still pick up the stale event's stage —
      // they only ever accumulate and are harmless as "was reached at some
      // point" context.
      expect(entry.hasReachedApplyingUpdate, isTrue);
    });
  });

  test('WarningRaised confirms CBF and sets hasWarning without leaking the '
      'raw warning payload', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(
        const WalletSyncWarningRaised(
          'w1',
          WalletSyncNeedsConnectionsWarning(),
        ),
      );
      async.flushMicrotasks();

      final entry = cubit.state.forWallet('w1');
      expect(entry!.isConfirmedCbf, isTrue);
      expect(entry.hasWarning, isTrue);
      expect(entry.phase, WalletSyncProgressPhase.connecting);
    });
  });

  test(
    'Completed with no prior CBF signal is ignored (ordinary Electrum sync)',
    () {
      fakeAsync((async) {
        final cubit = buildCubit();

        controller.add(
          const WalletSyncStarted('w1', BitcoinSyncBackend.electrum),
        );
        controller.add(const WalletSyncCompleted('w1'));
        async.flushMicrotasks();

        expect(cubit.state.entries, isEmpty);
      });
    },
  );

  test('Completed after a confirmed-CBF attempt is retained for the '
      'confirmation duration, then removed', () {
    fakeAsync((async) {
      final cubit = buildCubit(
        completedConfirmationDuration: const Duration(seconds: 3),
      );

      controller.add(const WalletSyncScanning('w1', scannedPercent: 90));
      async.flushMicrotasks();
      controller.add(const WalletSyncCompleted('w1'));
      async.flushMicrotasks();

      var entry = cubit.state.forWallet('w1');
      expect(entry, isNotNull);
      expect(entry!.phase, WalletSyncProgressPhase.completed);
      expect(entry.hasWarning, isFalse);

      async.elapse(const Duration(seconds: 2));
      expect(cubit.state.entries.containsKey('w1'), isTrue);

      async.elapse(const Duration(seconds: 2));
      expect(cubit.state.entries.containsKey('w1'), isFalse);
    });
  });

  test('WalletSyncCancelled removes a tracked entry and cancels any '
      'pending completion timer', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(const WalletSyncScanning('w1', scannedPercent: 5));
      async.flushMicrotasks();
      controller.add(const WalletSyncCompleted('w1'));
      async.flushMicrotasks();
      expect(cubit.state.entries.containsKey('w1'), isTrue);

      controller.add(const WalletSyncCancelled('w1'));
      async.flushMicrotasks();
      expect(cubit.state.entries.containsKey('w1'), isFalse);

      // The completion timer that would have fired at +3s must have been
      // cancelled by the WalletSyncCancelled above — elapsing past it must
      // not throw or resurrect the entry.
      async.elapse(const Duration(seconds: 5));
      expect(cubit.state.entries.containsKey('w1'), isFalse);
    });
  });

  test('WalletSyncCancelled for a wallet with nothing tracked is a no-op', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(const WalletSyncCancelled('w1'));
      async.flushMicrotasks();

      expect(cubit.state.entries, isEmpty);
    });
  });

  test('tracks multiple wallets independently', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(const WalletSyncScanning('w1', scannedPercent: 10));
      controller.add(const WalletSyncScanning('w2', scannedPercent: 90));
      async.flushMicrotasks();

      expect(cubit.state.forWallet('w1')?.scannedPercent, 10);
      expect(cubit.state.forWallet('w2')?.scannedPercent, 90);

      controller.add(const WalletSyncCancelled('w1'));
      async.flushMicrotasks();

      expect(cubit.state.entries.containsKey('w1'), isFalse);
      expect(cubit.state.forWallet('w2')?.scannedPercent, 90);
    });
  });

  test('a fresh CBF Started resets an entry still in its '
      'completion-confirmation window back to connecting', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(const WalletSyncScanning('w1', scannedPercent: 100));
      async.flushMicrotasks();
      controller.add(const WalletSyncCompleted('w1'));
      async.flushMicrotasks();
      expect(
        cubit.state.forWallet('w1')?.phase,
        WalletSyncProgressPhase.completed,
      );

      // A new CBF attempt starts before the 3s confirmation window clears.
      controller.add(
        const WalletSyncStarted('w1', BitcoinSyncBackend.compactBlockFilters),
      );
      async.flushMicrotasks();

      final entry = cubit.state.forWallet('w1');
      expect(entry!.phase, WalletSyncProgressPhase.connecting);
      expect(entry.isConfirmedCbf, isTrue);
      expect(entry.scannedPercent, isNull);

      // The old completion timer must not resurrect/mutate the reset entry.
      async.elapse(const Duration(seconds: 5));
      expect(
        cubit.state.forWallet('w1')?.phase,
        WalletSyncProgressPhase.connecting,
      );
    });
  });

  test('an Electrum Started arriving while a CBF entry is still confirmation-'
      'pending is ignored, never resetting or clearing the CBF entry', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(const WalletSyncScanning('w1', scannedPercent: 100));
      async.flushMicrotasks();
      controller.add(const WalletSyncCompleted('w1'));
      async.flushMicrotasks();

      controller.add(
        const WalletSyncStarted('w1', BitcoinSyncBackend.electrum),
      );
      async.flushMicrotasks();

      expect(
        cubit.state.forWallet('w1')?.phase,
        WalletSyncProgressPhase.completed,
      );
    });
  });

  test('cancel(walletId) forwards to CancelWalletSyncUsecase', () async {
    final cubit = buildCubit();

    await cubit.cancel('w1');

    verify(() => cancelUsecase.execute(walletId: 'w1')).called(1);
  });

  test('a CBF-tagged Failed creates an entry even with no preceding tracked '
      'Started (e.g. a setup failure)', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(
        const WalletSyncFailed(
          'w1',
          WalletSyncFailureCategory.compactBlockFilters,
        ),
      );
      async.flushMicrotasks();

      final entry = cubit.state.forWallet('w1');
      expect(entry, isNotNull);
      expect(entry!.isConfirmedCbf, isTrue);
      expect(entry.phase, WalletSyncProgressPhase.failed);
    });
  });

  test('Failed after a confirmed-CBF attempt moves the entry to failed and '
      'clears any warning, with no completion timer scheduled', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(
        const WalletSyncStarted('w1', BitcoinSyncBackend.compactBlockFilters),
      );
      controller.add(
        const WalletSyncWarningRaised(
          'w1',
          WalletSyncNeedsConnectionsWarning(),
        ),
      );
      async.flushMicrotasks();
      expect(cubit.state.forWallet('w1')?.hasWarning, isTrue);

      controller.add(
        const WalletSyncFailed(
          'w1',
          WalletSyncFailureCategory.compactBlockFilters,
        ),
      );
      async.flushMicrotasks();

      final entry = cubit.state.forWallet('w1');
      expect(entry!.phase, WalletSyncProgressPhase.failed);
      expect(entry.hasWarning, isFalse);

      // No completion timer should resurrect/remove the failed entry.
      async.elapse(const Duration(seconds: 10));
      expect(
        cubit.state.forWallet('w1')?.phase,
        WalletSyncProgressPhase.failed,
      );
    });
  });

  test('an Electrum-tagged Failed for an untracked wallet is ignored (ordinary '
      'Electrum sync)', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(
        const WalletSyncFailed('w1', WalletSyncFailureCategory.electrum),
      );
      async.flushMicrotasks();

      expect(cubit.state.entries, isEmpty);
    });
  });

  test('retry(walletId) forwards to StartWalletSyncUsecase', () async {
    final cubit = buildCubit();

    await cubit.retry('w1');

    verify(() => startUsecase.execute(walletId: 'w1')).called(1);
  });

  test('close() cancels the subscription and any pending completion timers '
      'without throwing', () {
    fakeAsync((async) {
      final cubit = buildCubit();

      controller.add(const WalletSyncScanning('w1', scannedPercent: 50));
      async.flushMicrotasks();
      controller.add(const WalletSyncCompleted('w1'));
      async.flushMicrotasks();

      expect(cubit.close(), completes);
      async.flushMicrotasks();

      // Elapsing past the (now-cancelled) completion timer must not throw
      // or emit on a closed cubit.
      expect(() => async.elapse(const Duration(seconds: 5)), returnsNormally);
    });
  });
}
