import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/await_cbf_sync_inactive_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_cbf_sync_active_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_bitcoin_sync_backend_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/set_bitcoin_sync_backend_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/start_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_sync_progress_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/bitcoin_sync_backend_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetBitcoinSyncBackendUsecase extends Mock
    implements GetBitcoinSyncBackendUsecase {}

class _MockSetBitcoinSyncBackendUsecase extends Mock
    implements SetBitcoinSyncBackendUsecase {}

class _MockStartWalletSyncUsecase extends Mock
    implements StartWalletSyncUsecase {}

class _MockCheckCbfSyncActiveUsecase extends Mock
    implements CheckCbfSyncActiveUsecase {}

class _MockAwaitCbfSyncInactiveUsecase extends Mock
    implements AwaitCbfSyncInactiveUsecase {}

class _MockWatchWalletSyncProgressUsecase extends Mock
    implements WatchWalletSyncProgressUsecase {}

const _walletId = 'w1';

/// [BitcoinSyncBackendCubit] distinguishes retriable CBF-backend failures
/// from the two non-retriable ones (`WalletSyncTorUnsupportedFailure`,
/// `WalletSyncDeveloperGateClosedFailure`) via the sealed
/// `WalletSyncFailure` the `Result` resolves with — see
/// `BitcoinSyncBackendCubit._failureReasonFor`. Retrying without changing
/// the underlying setting/build would just fail the same way again, so
/// `BitcoinSyncBackendState.canRetry` must be false for both.
void main() {
  late _MockGetBitcoinSyncBackendUsecase getUsecase;
  late _MockSetBitcoinSyncBackendUsecase setUsecase;
  late _MockStartWalletSyncUsecase startUsecase;
  late _MockCheckCbfSyncActiveUsecase checkActiveUsecase;
  late _MockAwaitCbfSyncInactiveUsecase awaitInactiveUsecase;
  late _MockWatchWalletSyncProgressUsecase watchUsecase;
  late StreamController<WalletSyncProgress> progressController;

  setUpAll(() {
    registerFallbackValue(BitcoinSyncBackend.electrum);
  });

  setUp(() {
    getUsecase = _MockGetBitcoinSyncBackendUsecase();
    setUsecase = _MockSetBitcoinSyncBackendUsecase();
    startUsecase = _MockStartWalletSyncUsecase();
    checkActiveUsecase = _MockCheckCbfSyncActiveUsecase();
    awaitInactiveUsecase = _MockAwaitCbfSyncInactiveUsecase();
    watchUsecase = _MockWatchWalletSyncProgressUsecase();
    progressController = StreamController<WalletSyncProgress>.broadcast();

    when(
      () => watchUsecase.execute(),
    ).thenAnswer((_) => progressController.stream);
    when(
      () => getUsecase.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => const Ok(BitcoinSyncBackend.electrum));
    when(
      () => setUsecase.execute(
        walletId: any(named: 'walletId'),
        backend: any(named: 'backend'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    // Every existing test below only exercises enableCompactBlockFilters();
    // the CBF-activity mocks default to "inactive" so the dedicated group
    // for disableCompactBlockFilters()/cancel() is the only place that
    // overrides them.
    when(
      () => checkActiveUsecase.execute(walletId: any(named: 'walletId')),
    ).thenReturn(false);
    when(
      () => awaitInactiveUsecase.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async {});
  });

  tearDown(() => progressController.close());

  BitcoinSyncBackendCubit buildCubit() => BitcoinSyncBackendCubit(
    walletId: _walletId,
    getBitcoinSyncBackendUsecase: getUsecase,
    setBitcoinSyncBackendUsecase: setUsecase,
    startWalletSyncUsecase: startUsecase,
    checkCbfSyncActiveUsecase: checkActiveUsecase,
    awaitCbfSyncInactiveUsecase: awaitInactiveUsecase,
    watchWalletSyncProgressUsecase: watchUsecase,
  );

  test(
    'a Tor-unsupported failure is non-retriable and keeps CBF selected',
    () async {
      when(
        () => startUsecase.execute(walletId: _walletId),
      ).thenAnswer((_) async => const Err(WalletSyncTorUnsupportedFailure()));
      final cubit = buildCubit();
      await pumpEventQueue();

      await cubit.enableCompactBlockFilters();

      expect(cubit.state.phase, BitcoinSyncBackendPhase.failed);
      expect(
        cubit.state.failureReason,
        BitcoinSyncBackendFailureReason.torUnsupported,
      );
      expect(cubit.state.canRetry, isFalse);
      verifyNever(
        () => setUsecase.execute(
          walletId: _walletId,
          backend: BitcoinSyncBackend.electrum,
        ),
      );
    },
  );

  test('a developer-gate-closed failure is non-retriable and keeps CBF '
      'selected', () async {
    when(() => startUsecase.execute(walletId: _walletId)).thenAnswer(
      (_) async => const Err(WalletSyncDeveloperGateClosedFailure()),
    );
    final cubit = buildCubit();
    await pumpEventQueue();

    await cubit.enableCompactBlockFilters();

    expect(cubit.state.phase, BitcoinSyncBackendPhase.failed);
    expect(
      cubit.state.failureReason,
      BitcoinSyncBackendFailureReason.gateClosed,
    );
    expect(cubit.state.canRetry, isFalse);
  });

  test('a CBF-backend failure is retriable', () async {
    when(
      () => startUsecase.execute(walletId: _walletId),
    ).thenAnswer((_) async => const Err(WalletSyncCbfFailure('SomeError')));
    final cubit = buildCubit();
    await pumpEventQueue();

    await cubit.enableCompactBlockFilters();

    expect(cubit.state.phase, BitcoinSyncBackendPhase.failed);
    expect(
      cubit.state.failureReason,
      BitcoinSyncBackendFailureReason.retriable,
    );
    expect(cubit.state.canRetry, isTrue);
  });

  test('an unmodeled failure defaults to retriable', () async {
    when(
      () => startUsecase.execute(walletId: _walletId),
    ).thenAnswer((_) async => const Err(WalletSyncUnexpectedFailure('boom')));
    final cubit = buildCubit();
    await pumpEventQueue();

    await cubit.enableCompactBlockFilters();

    expect(cubit.state.canRetry, isTrue);
  });

  test('a successful attempt completes with no failure reason', () async {
    when(
      () => startUsecase.execute(walletId: _walletId),
    ).thenAnswer((_) async => const Ok(null));
    final cubit = buildCubit();
    await pumpEventQueue();

    await cubit.enableCompactBlockFilters();

    expect(cubit.state.phase, BitcoinSyncBackendPhase.completed);
    expect(cubit.state.failureReason, isNull);
  });

  test('retry() re-enables and clears a previous non-retriable failure '
      'reason once the new attempt starts', () async {
    when(
      () => startUsecase.execute(walletId: _walletId),
    ).thenAnswer((_) async => const Err(WalletSyncTorUnsupportedFailure()));
    final cubit = buildCubit();
    await pumpEventQueue();
    await cubit.enableCompactBlockFilters();
    expect(cubit.state.canRetry, isFalse);

    when(
      () => startUsecase.execute(walletId: _walletId),
    ).thenAnswer((_) async => const Ok(null));
    await cubit.retry();

    expect(cubit.state.phase, BitcoinSyncBackendPhase.completed);
    expect(cubit.state.failureReason, isNull);
  });

  group('disableCompactBlockFilters()/cancel() — never a shutdown', () {
    test('persists Electrum immediately when no CBF sync is active, without '
        'ever awaiting settlement', () async {
      when(
        () => checkActiveUsecase.execute(walletId: _walletId),
      ).thenReturn(false);
      final cubit = buildCubit();
      await pumpEventQueue();

      await cubit.disableCompactBlockFilters();

      expect(cubit.state.phase, BitcoinSyncBackendPhase.idle);
      verify(
        () => setUsecase.execute(
          walletId: _walletId,
          backend: BitcoinSyncBackend.electrum,
        ),
      ).called(1);
      verifyNever(
        () => awaitInactiveUsecase.execute(walletId: any(named: 'walletId')),
      );
    });

    test('defers to Electrum instead of persisting immediately when a CBF '
        'sync is currently active, and never requests cancellation', () async {
      when(
        () => checkActiveUsecase.execute(walletId: _walletId),
      ).thenReturn(true);
      final settleCompleter = Completer<void>();
      when(
        () => awaitInactiveUsecase.execute(walletId: _walletId),
      ).thenAnswer((_) => settleCompleter.future);
      final cubit = buildCubit();
      await pumpEventQueue();

      await cubit.disableCompactBlockFilters();
      // Deferred: not persisted yet, and disableCompactBlockFilters()
      // itself already returned without waiting on the active session.
      verifyNever(
        () => setUsecase.execute(
          walletId: _walletId,
          backend: BitcoinSyncBackend.electrum,
        ),
      );

      settleCompleter.complete();
      await pumpEventQueue();

      expect(cubit.state.phase, BitcoinSyncBackendPhase.idle);
      verify(
        () => setUsecase.execute(
          walletId: _walletId,
          backend: BitcoinSyncBackend.electrum,
        ),
      ).called(1);
    });

    test('cancel() is an alias that also defers while active', () async {
      when(
        () => checkActiveUsecase.execute(walletId: _walletId),
      ).thenReturn(true);
      final settleCompleter = Completer<void>();
      when(
        () => awaitInactiveUsecase.execute(walletId: _walletId),
      ).thenAnswer((_) => settleCompleter.future);
      final cubit = buildCubit();
      await pumpEventQueue();

      await cubit.cancel();
      verifyNever(
        () => setUsecase.execute(
          walletId: _walletId,
          backend: BitcoinSyncBackend.electrum,
        ),
      );

      settleCompleter.complete();
      await pumpEventQueue();

      expect(cubit.state.phase, BitcoinSyncBackendPhase.idle);
    });
  });
}
