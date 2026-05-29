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
///  - different kinds are **queued** and executed sequentially in FIFO order
///    (matching the [SyncKind] enum declaration), avoiding concurrent writes
///    to the shared drift database (e.g. a wallet sync committing
///    wallet_metadata while the swap watcher restart writes swaps_table)
///    which were observed to cause "database is locked" errors;
///  - sync requests issued while the app is paused or hidden are dropped —
///    there is no point burning bandwidth/CPU for a UI no-one is looking at;
///  - returning to the foreground after being backgrounded triggers a fresh
///    sync. Flutter routes the lifecycle state machine through intermediate
///    states (`paused → hidden → inactive → resumed`), so we track whether
///    the app entered `paused`/`hidden` since the last `resumed` rather than
///    relying on a direct paused→resumed transition that never fires;
///  - per-kind successes are throttled: a kind that completed within
///    [_minSyncInterval] is skipped on the next enqueue unless the caller
///    passes `force: true` (pull-to-refresh and other explicit gestures).
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

  /// Minimum time between successful syncs of the same kind. A second
  /// `sync()` call within this window is a no-op for that kind unless the
  /// caller passes `force: true`.
  static const Duration _minSyncInterval = Duration(seconds: 2);

  final GetWalletsUsecase _getWallets;
  final SyncWalletUsecase _syncWallet;
  final RestartSwapWatcherUsecase _restartSwaps;

  late final AppLifecycleListener _lifecycleListener;
  bool _isAppResumed = true;

  /// Tracks whether the app entered `paused` or `hidden` since the last
  /// `resumed` transition. Flutter inserts `hidden → inactive` between
  /// `paused` and `resumed`, so a direct `paused→resumed` transition never
  /// fires — we use this flag to detect a foregrounding regardless of the
  /// exact intermediate path.
  bool _wasBackgrounded = false;

  final Queue<SyncKind> _queue = Queue<SyncKind>();
  final Set<SyncKind> _enqueued = <SyncKind>{};
  SyncKind? _running;
  bool _draining = false;
  Future<Map<SyncKind, Object>>? _activeDrain;
  final Map<SyncKind, Object> _lastErrors = <SyncKind, Object>{};
  final Map<SyncKind, DateTime> _lastSuccessAt = <SyncKind, DateTime>{};

  final StreamController<SyncCoordinatorState> _stateController =
      StreamController<SyncCoordinatorState>.broadcast();

  Stream<SyncCoordinatorState> get stream => _stateController.stream;

  SyncCoordinatorState get state => SyncCoordinatorState(
    running: _running,
    queued: Set.unmodifiable(_enqueued),
    errors: Map.unmodifiable(_lastErrors),
  );

  /// Schedule `kinds` (or all kinds when `only` is null) and resolve once the
  /// queue has drained. Iteration order follows the [SyncKind] enum
  /// declaration (bitcoin → liquid → swaps) regardless of how callers
  /// constructed `only`.
  ///
  /// Pass `force: true` to bypass the per-kind throttle — reserved for
  /// explicit user gestures (pull-to-refresh). Default callers (route-aware
  /// triggers, lifecycle resumption) should leave `force` at `false`.
  ///
  /// Returns immediately if the app is paused/hidden or every requested kind
  /// was deduped/throttled. Throws [SyncCoordinatorException] when any
  /// requested kind failed during the drain pass that satisfied this call.
  Future<void> sync({Set<SyncKind>? only, bool force = false}) async {
    final requested = SyncKind.values
        .where((k) => only?.contains(k) ?? true)
        .toList(growable: false);
    log.fine(
      '[SyncCoordinator] sync requested kinds=$requested force=$force running=$_running queued=${_queue.toList()} draining=$_draining hasActiveDrain=${_activeDrain != null}',
    );
    for (final kind in requested) {
      _enqueue(kind, force: force);
    }
    final settledErrors = await _drain();
    log.fine(
      '[SyncCoordinator] sync settled kinds=$requested errors=${settledErrors.keys.toList()}',
    );
    final failures = <SyncKind, Object>{
      for (final kind in requested)
        if (settledErrors[kind] != null) kind: settledErrors[kind]!,
    };
    if (failures.isNotEmpty) {
      log.warning(
        '[SyncCoordinator] sync failures kinds=${failures.keys.toList()}',
      );
      throw SyncCoordinatorException(failures);
    }
    log.fine('[SyncCoordinator] sync completed kinds=$requested');
  }

  void _enqueue(SyncKind kind, {required bool force}) {
    if (!_isAppResumed) {
      log.fine('[SyncCoordinator] skip $kind: app not resumed');
      return;
    }
    if (!force) {
      final last = _lastSuccessAt[kind];
      if (last != null &&
          DateTime.now().difference(last) < _minSyncInterval) {
        log.fine('[SyncCoordinator] throttle $kind: ran recently');
        return;
      }
    }
    if (_running == kind || _enqueued.contains(kind)) {
      log.fine('[SyncCoordinator] drop $kind: already pending');
      return;
    }
    _enqueued.add(kind);
    _queue.add(kind);
    log.fine('[SyncCoordinator] enqueued $kind queue=${_queue.toList()}');
    _emit();
  }

  Future<Map<SyncKind, Object>> _drain() {
    final inFlight = _activeDrain;
    if (inFlight != null) {
      log.fine('[SyncCoordinator] join in-flight drain');
      return inFlight;
    }
    log.fine('[SyncCoordinator] start drain pass');
    final future = _drainOnce();
    _activeDrain = future;
    return future.whenComplete(() {
      if (identical(_activeDrain, future)) {
        _activeDrain = null;
      }
      if (_queue.isNotEmpty && !_draining) {
        log.fine('[SyncCoordinator] follow-up drain scheduled');
        unawaited(_drain());
      }
    });
  }

  Future<Map<SyncKind, Object>> _drainOnce() async {
    _draining = true;
    _lastErrors.clear();
    log.fine('[SyncCoordinator] drain pass begin queue=${_queue.toList()}');
    try {
      while (_queue.isNotEmpty) {
        final kind = _queue.removeFirst();
        _enqueued.remove(kind);
        _running = kind;
        log.fine('[SyncCoordinator] run $kind remainingQueue=${_queue.toList()}');
        _emit();
        try {
          await _runTask(kind);
          _lastSuccessAt[kind] = DateTime.now();
          log.fine('[SyncCoordinator] success $kind');
        } catch (e, st) {
          _lastErrors[kind] = e;
          // Sanitize: substitute a synthetic error carrying only the kind
          // and the runtimeType so wallet identifiers that exception
          // messages may embed don't flow to Sentry.
          log.severe(
            message: '[SyncCoordinator] $kind sync failed',
            error: StateError('$kind sync threw ${e.runtimeType}'),
            trace: st,
          );
        }
        _running = null;
      }
      log.fine(
        '[SyncCoordinator] drain pass end errors=${_lastErrors.keys.toList()}',
      );
      final errors = Map<SyncKind, Object>.of(_lastErrors);
      return errors;
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
    }
    _isAppResumed =
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden;
    if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      // sync() may throw SyncCoordinatorException; ignore here — the drain
      // path already logged a sanitized SEVERE for any failed kind, and the
      // lifecycle-triggered refresh is best-effort with no awaiting caller.
      sync().ignore();
    }
  }

  void _emit() => _stateController.add(state);

  void dispose() {
    _lifecycleListener.dispose();
    _stateController.close();
  }
}
