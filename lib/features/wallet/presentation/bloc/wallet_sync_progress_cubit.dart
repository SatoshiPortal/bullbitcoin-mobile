import 'dart:async';

import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/cancel_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/start_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_sync_progress_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'wallet_sync_progress_state.dart';

/// App-wide, always-on observer of every wallet's advisory sync progress.
///
/// Registered as a single lazy singleton (see `WalletLocator`) that
/// subscribes exactly once to [WatchWalletSyncProgressUsecase] for the
/// lifetime of the process, so a foreground compact-filter (CBF) sync's
/// progress is never missed just because no screen happened to be
/// observing it yet. `WalletRouter` threads this same instance through the
/// wallet routes with `BlocProvider.value` so route disposal never closes
/// it.
///
/// Deliberately domain-only — no `data/` or backend-specific import here;
/// every case in [_onProgress] switches on [WalletSyncProgress], the
/// backend-agnostic domain event.
class WalletSyncProgressCubit extends Cubit<WalletSyncProgressState> {
  WalletSyncProgressCubit({
    required WatchWalletSyncProgressUsecase watchWalletSyncProgressUsecase,
    required this._cancelWalletSyncUsecase,
    required this._startWalletSyncUsecase,
    this._completedConfirmationDuration = const Duration(seconds: 3),
  }) : super(const WalletSyncProgressState()) {
    _subscription = watchWalletSyncProgressUsecase.execute().listen(
      _onProgress,
    );
  }

  final CancelWalletSyncUsecase _cancelWalletSyncUsecase;
  final StartWalletSyncUsecase _startWalletSyncUsecase;

  /// How long a completed entry is retained after
  /// [WalletSyncProgressPhase.completed] before it is removed. Injectable
  /// so tests don't need to wait out the real default.
  final Duration _completedConfirmationDuration;

  final Map<String, Timer> _completionTimers = {};

  StreamSubscription<WalletSyncProgress>? _subscription;

  /// Requests cancellation of [walletId]'s in-flight sync. A no-op for a
  /// wallet with nothing in flight, or for a backend that cannot be
  /// interrupted by an ordinary cancellation — both Electrum
  /// (`ElectrumWalletSyncRepository.cancelSync`) and, under its long-lived
  /// session policy, CBF (`CbfWalletDatasource.cancelSync`) — see
  /// `CancelWalletSyncUsecase`. No UI in this app currently calls this: the
  /// only consumer that used to (`WalletSyncProgressCard`'s "Stop for now"
  /// button) was removed once CBF sessions became long-lived, since it
  /// would have offered a control that no longer does anything. Retained on
  /// the cubit as a harmless no-op rather than deleted, so a future
  /// interruptible backend (or a real interrupt path) has somewhere to
  /// plug in without re-threading this call through every layer again.
  Future<void> cancel(String walletId) =>
      _cancelWalletSyncUsecase.execute(walletId: walletId);

  /// Retries [walletId]'s sync after a [WalletSyncProgressPhase.failed]
  /// entry. Only ever meaningful for a CBF-backend wallet — a fresh
  /// `WalletSyncStarted` tagged `BitcoinSyncBackend.compactBlockFilters`
  /// resets the entry back to [WalletSyncProgressPhase.connecting]; the
  /// wallet's persisted backend choice is untouched either way.
  Future<void> retry(String walletId) =>
      _startWalletSyncUsecase.execute(walletId: walletId).then((_) {});

  @override
  Future<void> close() {
    unawaited(_subscription?.cancel());
    for (final timer in _completionTimers.values) {
      timer.cancel();
    }
    _completionTimers.clear();
    return super.close();
  }

  void _onProgress(WalletSyncProgress progress) {
    final walletId = progress.walletId;
    switch (progress) {
      case WalletSyncStarted(:final backend):
        _cancelCompletionTimer(walletId);
        // Electrum's Started is tagged BitcoinSyncBackend.electrum and must
        // never create a tracked entry — that would make every ordinary
        // Electrum sync appear here. CBF's Started is known immediately
        // from this event alone (no need to wait for a later
        // Scanning/WarningRaised signal), so it always (re)creates a
        // connecting entry — including resetting one still inside a
        // previous attempt's completion-confirmation window, see
        // [_completedConfirmationDuration].
        if (backend == BitcoinSyncBackend.compactBlockFilters) {
          _upsert(
            walletId,
            const WalletSyncProgressEntry(
              phase: WalletSyncProgressPhase.connecting,
              isConfirmedCbf: true,
            ),
          );
        }
      case WalletSyncScanning(
        :final scannedPercent,
        :final stage,
        :final chainHeight,
        :final receivedBlockCount,
        :final peerHandshakeCount,
      ):
        _cancelCompletionTimer(walletId);
        final entry =
            state.entries[walletId] ??
            const WalletSyncProgressEntry(
              phase: WalletSyncProgressPhase.connecting,
            );
        // WalletSyncScanStage.applyingUpdate is emitted exactly once,
        // immediately before the scan's single opaque
        // awaitAndApplyUpdate() call, with no further progress signal
        // expected until the attempt settles (see that enum value's doc).
        // A later Scanning event reaching the cubit after that point would
        // only ever be a stale/out-of-order native event, never a real
        // regression of the scan itself — so once reached, the entire
        // scanning snapshot (not just the headline stage) is frozen rather
        // than letting a stray event flip the UI back to an earlier stage.
        final scanStageLocked =
            entry.scanStage == WalletSyncScanStage.applyingUpdate;
        final stageAdvances =
            entry.scanStage == null ||
            _stageOrder(stage) >= _stageOrder(entry.scanStage!);
        final keepCurrentStage = scanStageLocked || !stageAdvances;
        final nextPercent = stage == WalletSyncScanStage.downloadingFilters
            ? _maxPercent(entry.scannedPercent, scannedPercent)
            : entry.scannedPercent;
        _upsert(
          walletId,
          entry.copyWith(
            phase: WalletSyncProgressPhase.scanning,
            scanStage: keepCurrentStage ? entry.scanStage : stage,
            scannedPercent: nextPercent,
            chainHeight: _maxHeight(entry.chainHeight, chainHeight),
            receivedBlockCount: scanStageLocked
                ? entry.receivedBlockCount
                : receivedBlockCount,
            peerHandshakeCount: peerHandshakeCount,
            hasConnected:
                entry.hasConnected || stage == WalletSyncScanStage.connected,
            hasFilterProgress:
                entry.hasFilterProgress ||
                stage == WalletSyncScanStage.downloadingFilters,
            hasMatchingBlocks:
                entry.hasMatchingBlocks ||
                stage == WalletSyncScanStage.matchingBlocks,
            hasReachedApplyingUpdate:
                entry.hasReachedApplyingUpdate ||
                stage == WalletSyncScanStage.applyingUpdate,
            isConfirmedCbf: true,
          ),
        );
      case WalletSyncWarningRaised():
        // Advisory only — never surfaced with its raw payload (see
        // `WalletSyncWarning`); the sync keeps running under its current
        // phase.
        final entry =
            state.entries[walletId] ??
            const WalletSyncProgressEntry(
              phase: WalletSyncProgressPhase.connecting,
            );
        _upsert(
          walletId,
          entry.copyWith(hasWarning: true, isConfirmedCbf: true),
        );
      case WalletSyncCompleted():
        final entry = state.entries[walletId];
        // Not tracked, or never confirmed CBF — an ordinary Electrum
        // Started/Completed pair with no CBF signal in between. Nothing
        // to retain or confirm.
        if (entry == null || !entry.isConfirmedCbf) return;
        _upsert(
          walletId,
          entry.copyWith(
            phase: WalletSyncProgressPhase.completed,
            hasWarning: false,
          ),
        );
        _completionTimers[walletId] = Timer(
          _completedConfirmationDuration,
          () => _remove(walletId),
        );
      case WalletSyncFailed(:final category):
        _cancelCompletionTimer(walletId);
        final isCbf = category == WalletSyncFailureCategory.compactBlockFilters;
        final entry = state.entries[walletId];
        // Not tracked, and not itself a CBF-tagged failure (e.g. Electrum's)
        // — nothing to surface. A CBF failure creates the entry even with
        // no preceding tracked Started, so a setup failure (which fails
        // before Started is ever emitted) still surfaces.
        if (entry == null && !isCbf) return;
        _upsert(
          walletId,
          (entry ??
                  const WalletSyncProgressEntry(
                    phase: WalletSyncProgressPhase.connecting,
                  ))
              .copyWith(
                phase: WalletSyncProgressPhase.failed,
                hasWarning: false,
                isConfirmedCbf: true,
              ),
        );
      case WalletSyncCancelled():
        _cancelCompletionTimer(walletId);
        _remove(walletId);
    }
  }

  void _upsert(String walletId, WalletSyncProgressEntry entry) {
    final entries = Map<String, WalletSyncProgressEntry>.from(state.entries);
    entries[walletId] = entry;
    emit(state.copyWith(entries: entries));
  }

  void _remove(String walletId) {
    if (!state.entries.containsKey(walletId)) return;
    final entries = Map<String, WalletSyncProgressEntry>.from(state.entries)
      ..remove(walletId);
    emit(state.copyWith(entries: entries));
  }

  void _cancelCompletionTimer(String walletId) {
    _completionTimers.remove(walletId)?.cancel();
  }

  static int _stageOrder(WalletSyncScanStage stage) => switch (stage) {
    WalletSyncScanStage.connecting => 0,
    WalletSyncScanStage.connected => 1,
    WalletSyncScanStage.syncingHeaders => 2,
    WalletSyncScanStage.downloadingFilters => 3,
    WalletSyncScanStage.matchingBlocks => 4,
    WalletSyncScanStage.applyingUpdate => 5,
  };

  static double? _maxPercent(double? current, double? next) {
    if (next == null) return current;
    if (current == null) return next;
    return next > current ? next : current;
  }

  static int? _maxHeight(int? current, int? next) {
    if (next == null) return current;
    if (current == null) return next;
    return next > current ? next : current;
  }
}
