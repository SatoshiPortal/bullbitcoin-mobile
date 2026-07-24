import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_bitcoin_sync_backend_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/start_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_sync_progress_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'wallet_initial_sync_state.dart';

/// Route-scoped controller for `WalletInitialSyncScreen`, the dedicated
/// first-run compact-block-filter (CBF) sync screen `WalletRouter` reaches
/// only for a recovery/import operation whose wallet already persisted
/// [BitcoinSyncBackend.compactBlockFilters] (see
/// `WalletRouter.goToWalletHomeOrInitialSync`'s `isRecoveryOrImport` gate —
/// never for a newly created wallet).
///
/// Registered as a route-scoped factory (see `WalletLocator`) — a fresh
/// instance per visit to this route, rather than reusing the app-wide
/// `WalletSyncProgressCubit` lazy singleton for its own control flow.
/// `WalletRouter` used to kick off [StartWalletSyncUsecase] itself,
/// *before* navigating, so a fast-settling attempt's very first broadcast
/// progress events could fire before that singleton — only ever
/// instantiated the first time something resolves it from the locator —
/// was subscribed. This cubit closes that gap: it subscribes to
/// [WatchWalletSyncProgressUsecase] itself, synchronously in its own
/// constructor, strictly before it ever calls [StartWalletSyncUsecase] —
/// see [_start]. `WalletRouter` itself now only ever navigates; it never
/// starts a sync.
///
/// Still re-verifies the wallet's persisted [BitcoinSyncBackend] is
/// [BitcoinSyncBackend.compactBlockFilters] before starting anything — a
/// defense-in-depth check independent of `WalletRouter`'s own routing
/// decision, in case that has somehow changed by the time this cubit
/// starts running. A non-CBF backend (or a lookup failure) settles
/// straight on [WalletInitialSyncPhase.failed] with nothing to show
/// progress for — this screen must never be shown running against a
/// non-CBF wallet.
///
/// [WalletInitialSyncState.phase] only ever drives this screen's own
/// Continue/Skip gating. The staged progress diagnostics
/// (connected/filters/chain height/etc.) keep coming from the existing
/// `WalletSyncProgressCard`/`WalletSyncProgressCubit`, unchanged — this
/// cubit renders nothing on its own.
class WalletInitialSyncCubit extends Cubit<WalletInitialSyncState> {
  WalletInitialSyncCubit({
    required this._walletId,
    required WatchWalletSyncProgressUsecase watchWalletSyncProgressUsecase,
    required this._getBitcoinSyncBackendUsecase,
    required this._startWalletSyncUsecase,
  }) : super(const WalletInitialSyncState()) {
    // Subscribed before this constructor's own _start() (below) ever
    // reaches StartWalletSyncUsecase — see this class's doc. `.where` scopes
    // this cubit to its own wallet, same as every other progress consumer.
    _subscription = watchWalletSyncProgressUsecase
        .execute()
        .where((progress) => progress.walletId == _walletId)
        .listen(_onProgress);
    unawaited(_start());
  }

  final String _walletId;
  final GetBitcoinSyncBackendUsecase _getBitcoinSyncBackendUsecase;
  final StartWalletSyncUsecase _startWalletSyncUsecase;

  StreamSubscription<WalletSyncProgress>? _subscription;

  /// Re-runs the verify-then-start sequence below. The only consumer today
  /// is `WalletSyncProgressCard`'s own Retry button, wired to the app-wide
  /// `WalletSyncProgressCubit.retry` — that call reaches the same
  /// `WalletSyncRepository.startSync`, whose resulting progress events this
  /// cubit's own subscription above already observes independently (so a
  /// retry via that shared control still moves this cubit's phase back to
  /// [WalletInitialSyncPhase.connecting] without this method ever being
  /// called). Exposed and tested directly so a future control on this
  /// screen has a route-aware retry to call that also re-verifies CBF.
  Future<void> retry() => _start();

  Future<void> _start() async {
    emit(state.copyWith(phase: WalletInitialSyncPhase.verifying));

    final backendResult = await _getBitcoinSyncBackendUsecase.execute(
      walletId: _walletId,
    );
    if (isClosed) return;

    bool isCbf;
    switch (backendResult) {
      case Ok(:final value):
        isCbf = value == BitcoinSyncBackend.compactBlockFilters;
      case Err(:final failure):
        log.warning(
          'WalletInitialSyncCubit: backend lookup failed for $_walletId: '
          '${failure.logMessage}',
        );
        isCbf = false;
    }
    if (!isCbf) {
      emit(state.copyWith(phase: WalletInitialSyncPhase.failed));
      return;
    }

    emit(state.copyWith(phase: WalletInitialSyncPhase.connecting));
    final startResult = await _startWalletSyncUsecase.execute(
      walletId: _walletId,
    );
    if (isClosed) return;
    // An immediate Err here (e.g. the developer gate closed, or Tor
    // enabled) settles before a single progress event is ever emitted for
    // this attempt — WalletSyncRoutingRepository refuses these before the
    // CBF backend is ever entered, so no later WalletSyncFailed arrives on
    // the stream to cover it. This must still reach `failed` on its own.
    // An `Ok` is deliberately left alone: from here on this cubit's phase
    // comes only from the progress stream (`_onProgress`), the single
    // source of truth for both an attempt this call started and one it
    // merely joined already running — see StartWalletSyncUsecase's doc.
    if (startResult case Err(:final failure)) {
      log.warning(
        'WalletInitialSyncCubit: sync failed to start for $_walletId: '
        '${failure.logMessage}',
      );
      emit(state.copyWith(phase: WalletInitialSyncPhase.failed));
    }
  }

  void _onProgress(WalletSyncProgress progress) {
    switch (progress) {
      case WalletSyncStarted():
        emit(state.copyWith(phase: WalletInitialSyncPhase.connecting));
      case WalletSyncScanning():
        emit(state.copyWith(phase: WalletInitialSyncPhase.scanning));
      case WalletSyncWarningRaised():
        // Advisory only — WalletSyncProgressCard surfaces it; this cubit's
        // own phase is unaffected.
        break;
      case WalletSyncCompleted():
        emit(state.copyWith(phase: WalletInitialSyncPhase.completed));
      case WalletSyncFailed():
        emit(state.copyWith(phase: WalletInitialSyncPhase.failed));
      case WalletSyncCancelled():
        // Only ever reachable through wallet deletion or a mid-session
        // Tor-enable (see WalletSyncCancelled's domain doc) — neither is
        // reachable from this first-run screen, but settle on failed
        // rather than leaving the screen stuck on an indeterminate
        // spinner if it somehow arrived.
        emit(state.copyWith(phase: WalletInitialSyncPhase.failed));
    }
  }

  @override
  Future<void> close() {
    unawaited(_subscription?.cancel());
    return super.close();
  }
}
