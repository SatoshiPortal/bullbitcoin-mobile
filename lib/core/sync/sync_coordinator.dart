import 'dart:async';
import 'dart:collection';

import 'package:bb_mobile/core/sync/sync_coordinator_state.dart';
import 'package:bb_mobile/core/sync/sync_kind.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState, WidgetsBinding;

/// Foreground sync orchestrator.
///
/// Schedules per-kind sync work (bitcoin, liquid, swaps) so that:
///  - the same kind is **never** run concurrently — duplicate requests are
///    dropped while one is queued or running;
///  - different kinds are **queued** and executed sequentially in FIFO order,
///    avoiding concurrent writes to the shared drift database (e.g. a wallet
///    sync committing wallet_metadata while the swap watcher restart writes
///    swaps_table) which were observed to cause "database is locked" errors;
///  - sync requests issued while the app is not resumed are dropped — there
///    is no point burning bandwidth/CPU for a UI no-one is looking at;
///  - the transition `paused → resumed` triggers a fresh `requestAll()`.
///
/// Background tasks (`lib/core/background_tasks/handler.dart`) intentionally
/// do **not** use this coordinator — they run in a separate Dart isolate with
/// their own GetIt and no widget binding, so the lifecycle gate would actively
/// block them. They keep calling the underlying usecases directly.
class SyncCoordinator {
  SyncCoordinator({
    required GetWalletsUsecase getWalletsUsecase,
    required SyncWalletUsecase syncWalletUsecase,
    required RestartSwapWatcherUsecase restartSwapWatcherUsecase,
  }) : _getWallets = getWalletsUsecase,
       _syncWallet = syncWalletUsecase,
       _restartSwaps = restartSwapWatcherUsecase {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isAppResumed =
        lifecycleState != AppLifecycleState.paused &&
        lifecycleState != AppLifecycleState.hidden;
    _lifecycleListener = AppLifecycleListener(onStateChange: _onLifecycleChange);
  }

  final GetWalletsUsecase _getWallets;
  final SyncWalletUsecase _syncWallet;
  final RestartSwapWatcherUsecase _restartSwaps;

  late final AppLifecycleListener _lifecycleListener;
  bool _isAppResumed = true;
  AppLifecycleState? _previousLifecycleState;

  final Queue<SyncKind> _queue = Queue<SyncKind>();
  final Set<SyncKind> _enqueued = <SyncKind>{};
  SyncKind? _running;
  bool _draining = false;

  final StreamController<SyncCoordinatorState> _stateController =
      StreamController<SyncCoordinatorState>.broadcast();

  Stream<SyncCoordinatorState> get stream => _stateController.stream;

  SyncCoordinatorState get state =>
      SyncCoordinatorState(running: _running, queued: Set.unmodifiable(_enqueued));

  /// Schedule `kinds` (or all kinds when `only` is null) and resolve once the
  /// queue has drained. Returns immediately if the app is paused or every
  /// requested kind was deduped.
  Future<void> sync({Set<SyncKind>? only}) async {
    final kinds = only ?? SyncKind.values.toSet();
    for (final kind in kinds) {
      _enqueue(kind);
    }
    unawaited(_drain());
    if (!state.isBusy) return;
    await stream.firstWhere((s) => !s.isBusy);
  }

  void _enqueue(SyncKind kind) {
    if (!_isAppResumed) {
      log.fine('[SyncCoordinator] skip $kind: app not resumed');
      return;
    }
    if (_running == kind || _enqueued.contains(kind)) {
      log.fine('[SyncCoordinator] drop $kind: already pending');
      return;
    }
    _enqueued.add(kind);
    _queue.add(kind);
    _emit();
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final kind = _queue.removeFirst();
        _enqueued.remove(kind);
        _running = kind;
        _emit();
        try {
          await _runTask(kind);
        } catch (e, st) {
          log.severe(
            message: '[SyncCoordinator] $kind failed',
            error: e,
            trace: st,
          );
        }
        _running = null;
      }
    } finally {
      _draining = false;
      _emit();
    }
  }

  Future<void> _runTask(SyncKind kind) async {
    switch (kind) {
      case SyncKind.bitcoin:
        final wallets = await _getWallets.execute(onlyBitcoin: true);
        for (final wallet in wallets) {
          await _syncWallet.execute(wallet);
        }
      case SyncKind.liquid:
        final wallets = await _getWallets.execute(onlyLiquid: true);
        for (final wallet in wallets) {
          await _syncWallet.execute(wallet);
        }
      case SyncKind.swaps:
        await _restartSwaps.execute();
    }
  }

  void _onLifecycleChange(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
    if (_previousLifecycleState == AppLifecycleState.paused &&
        state == AppLifecycleState.resumed) {
      unawaited(sync());
    }
    _previousLifecycleState = state;
  }

  void _emit() => _stateController.add(state);

  void dispose() {
    _lifecycleListener.dispose();
    _stateController.close();
  }
}
