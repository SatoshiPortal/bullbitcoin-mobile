import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
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
import 'package:flutter_bloc/flutter_bloc.dart';

part 'bitcoin_sync_backend_state.dart';

/// Drives the developer-only "compact block filters" toggle for a single
/// Bitcoin wallet — see `BitcoinSyncBackendTile`.
///
/// Reads/writes the wallet's persisted [BitcoinSyncBackend] through
/// [GetBitcoinSyncBackendUsecase]/[SetBitcoinSyncBackendUsecase], and only
/// ever starts a compact-filter attempt through [StartWalletSyncUsecase] —
/// never Electrum's usual background/foreground sync path (see
/// `SyncWalletUsecase`'s class doc). [WatchWalletSyncProgressUsecase] feeds
/// this wallet's advisory progress. A failed attempt keeps the user's CBF
/// selection so a retry actually retries CBF; switching back to Electrum is
/// always an explicit user action.
///
/// Turning the toggle off (or tapping "Turn off" while syncing) never kills
/// a live CBF session — [CheckCbfSyncActiveUsecase]/
/// [AwaitCbfSyncInactiveUsecase] defer the switch to Electrum until the
/// active attempt settles on its own, per the product rule normal app code
/// must never shut one down (see `CbfSyncActivityPort`'s class doc).
///
/// Never surfaces a failure's raw log message — every failure this cubit
/// reaches is shown to the user as one generic, translated message.
class BitcoinSyncBackendCubit extends Cubit<BitcoinSyncBackendState> {
  final String _walletId;
  final GetBitcoinSyncBackendUsecase _getBitcoinSyncBackendUsecase;
  final SetBitcoinSyncBackendUsecase _setBitcoinSyncBackendUsecase;
  final StartWalletSyncUsecase _startWalletSyncUsecase;
  final CheckCbfSyncActiveUsecase _checkCbfSyncActiveUsecase;
  final AwaitCbfSyncInactiveUsecase _awaitCbfSyncInactiveUsecase;
  final WatchWalletSyncProgressUsecase _watchWalletSyncProgressUsecase;

  StreamSubscription<WalletSyncProgress>? _progressSubscription;

  BitcoinSyncBackendCubit({
    required this._walletId,
    required this._getBitcoinSyncBackendUsecase,
    required this._setBitcoinSyncBackendUsecase,
    required this._startWalletSyncUsecase,
    required this._checkCbfSyncActiveUsecase,
    required this._awaitCbfSyncInactiveUsecase,
    required this._watchWalletSyncProgressUsecase,
  }) : super(const BitcoinSyncBackendState()) {
    _init();
  }

  Future<void> _init() async {
    _progressSubscription = _watchWalletSyncProgressUsecase
        .execute()
        .where((progress) => progress.walletId == _walletId)
        .listen(_onProgress);

    final result = await _getBitcoinSyncBackendUsecase.execute(
      walletId: _walletId,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(isLoading: false, backend: value));
      case Err(:final failure):
        log.warning(
          'Failed to load the wallet sync backend: ${failure.logMessage}',
        );
        emit(state.copyWith(isLoading: false));
    }
  }

  /// Persists compact block filters and starts a foreground sync attempt.
  /// Keeps CBF selected when the attempt fails so the visible retry control
  /// cannot silently route through Electrum.
  Future<void> enableCompactBlockFilters() async {
    emit(
      state.copyWith(
        phase: BitcoinSyncBackendPhase.connecting,
        clearScannedPercent: true,
        clearFailureReason: true,
      ),
    );

    final setResult = await _setBitcoinSyncBackendUsecase.execute(
      walletId: _walletId,
      backend: BitcoinSyncBackend.compactBlockFilters,
    );
    if (isClosed) return;
    if (setResult case Err(:final failure)) {
      log.warning(
        'Failed to persist the compact block filter backend: '
        '${failure.logMessage}',
      );
      emit(
        state.copyWith(
          phase: BitcoinSyncBackendPhase.failed,
          failureReason: BitcoinSyncBackendFailureReason.retriable,
        ),
      );
      return;
    }
    emit(state.copyWith(backend: BitcoinSyncBackend.compactBlockFilters));

    final startResult = await _startWalletSyncUsecase.execute(
      walletId: _walletId,
    );
    if (isClosed) return;

    switch (startResult) {
      case Ok():
        emit(
          state.copyWith(
            phase: BitcoinSyncBackendPhase.completed,
            clearScannedPercent: true,
          ),
        );
      case Err(:final failure):
        log.warning('Compact block filter sync failed: ${failure.logMessage}');
        emit(
          state.copyWith(
            phase: BitcoinSyncBackendPhase.failed,
            failureReason: _failureReasonFor(failure),
            clearScannedPercent: true,
          ),
        );
    }
  }

  /// Tor-unsupported and developer-gate-closed failures are refused by
  /// `WalletSyncRoutingRepository` before the CBF backend is ever entered,
  /// so retrying without changing the underlying setting/build would just
  /// fail again the same way — [BitcoinSyncBackendState.canRetry] is false
  /// for both. Every other failure (the CBF backend itself, or anything
  /// unmodeled) is treated as retriable.
  BitcoinSyncBackendFailureReason _failureReasonFor(
    WalletSyncFailure failure,
  ) => switch (failure) {
    WalletSyncTorUnsupportedFailure() =>
      BitcoinSyncBackendFailureReason.torUnsupported,
    WalletSyncDeveloperGateClosedFailure() =>
      BitcoinSyncBackendFailureReason.gateClosed,
    _ => BitcoinSyncBackendFailureReason.retriable,
  };

  /// Persists Electrum — deferring first if a CBF attempt is currently
  /// active. Used both for the switch turning off and for a "turn off" tap
  /// while syncing; neither ever cancels a live session (see this class's
  /// doc).
  Future<void> disableCompactBlockFilters() async {
    final isActive = _checkCbfSyncActiveUsecase.execute(walletId: _walletId);
    if (isActive) {
      // Deferred, not cancelled: wait for the live session to settle on
      // its own, then finish the switch. Never awaited here — a caller
      // must not block on however long the in-flight scan takes.
      unawaited(_deferDisable());
      return;
    }

    await _persistElectrum();
    if (isClosed) return;
    emit(
      state.copyWith(
        phase: BitcoinSyncBackendPhase.idle,
        clearScannedPercent: true,
        clearFailureReason: true,
      ),
    );
  }

  /// Alias for [disableCompactBlockFilters], for a "turn off" control shown
  /// while an attempt is in flight.
  Future<void> cancel() => disableCompactBlockFilters();

  /// Waits out the active CBF attempt this cubit's own [_init]/[_onProgress]
  /// may not even be tracking (e.g. a prior cubit instance for this wallet
  /// started it and was disposed since), then finishes the switch to
  /// Electrum exactly as the immediate path above does.
  Future<void> _deferDisable() async {
    await _awaitCbfSyncInactiveUsecase.execute(walletId: _walletId);
    if (isClosed) return;

    await _persistElectrum();
    if (isClosed) return;
    emit(
      state.copyWith(
        phase: BitcoinSyncBackendPhase.idle,
        clearScannedPercent: true,
        clearFailureReason: true,
      ),
    );
  }

  /// Alias for [enableCompactBlockFilters], for a "retry" control shown
  /// after a failed attempt.
  Future<void> retry() => enableCompactBlockFilters();

  @override
  Future<void> close() {
    // Only the subscription is torn down here — an in-flight foreground
    // sync keeps running; the datasource's own app-lifecycle listener is
    // what stops it if the app leaves the foreground, not a route change.
    unawaited(_progressSubscription?.cancel());
    return super.close();
  }

  void _onProgress(WalletSyncProgress progress) {
    switch (progress) {
      case WalletSyncStarted():
        emit(
          state.copyWith(
            phase: BitcoinSyncBackendPhase.connecting,
            clearScannedPercent: true,
            clearFailureReason: true,
          ),
        );
      case WalletSyncScanning(:final scannedPercent):
        emit(
          state.copyWith(
            phase: BitcoinSyncBackendPhase.scanning,
            scannedPercent: scannedPercent,
            clearScannedPercent: scannedPercent == null,
          ),
        );
      case WalletSyncWarningRaised():
        // Advisory only — the attempt keeps running under its current
        // phase; nothing user-facing changes.
        break;
      case WalletSyncCompleted():
        emit(
          state.copyWith(
            phase: BitcoinSyncBackendPhase.completed,
            clearScannedPercent: true,
          ),
        );
      case WalletSyncFailed():
        // Tor-unsupported and developer-gate-closed failures are refused
        // before the CBF backend is ever entered (see
        // `WalletSyncRoutingRepository`), so they never reach this stream —
        // only a genuine CBF-backend failure does, which is always
        // retriable. `enableCompactBlockFilters`'s own `Err` branch also
        // reaches the same phase/reason once its `Future` settles (that
        // path is what runs `_persistElectrum`); this handler exists so a
        // setup failure — which fails before the attempt's `Result` future
        // would otherwise resolve any sooner — is reflected here too.
        emit(
          state.copyWith(
            phase: BitcoinSyncBackendPhase.failed,
            failureReason: BitcoinSyncBackendFailureReason.retriable,
            clearScannedPercent: true,
          ),
        );
      case WalletSyncCancelled():
        // Mirrors the explicit idle state disableCompactBlockFilters()
        // already emits when the user taps cancel — this case only
        // matters for a cancellation this cubit didn't itself request
        // (e.g. the app leaving the foreground), so the tile doesn't get
        // stuck showing a stale in-progress phase.
        emit(
          state.copyWith(
            phase: BitcoinSyncBackendPhase.idle,
            clearScannedPercent: true,
            clearFailureReason: true,
          ),
        );
    }
  }

  Future<void> _persistElectrum() async {
    final result = await _setBitcoinSyncBackendUsecase.execute(
      walletId: _walletId,
      backend: BitcoinSyncBackend.electrum,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(backend: BitcoinSyncBackend.electrum));
      case Err(:final failure):
        log.warning(
          'Failed to revert the wallet sync backend to Electrum: '
          '${failure.logMessage}',
        );
    }
  }
}
