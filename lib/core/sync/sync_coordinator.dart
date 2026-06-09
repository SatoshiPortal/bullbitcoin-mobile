import 'dart:async';
import 'dart:collection';

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
///  - sync requests issued while the app is not foreground-`resumed` (i.e.
///    `inactive`/`hidden`/`paused`/`detached`) are dropped — there is no point
///    burning bandwidth/CPU for a UI no-one is interacting with;
///  - returning to `resumed` triggers a fresh catch-up sync, replaying any
///    sync that was gated off while away (tracked via a single "was away since
///    last resumed" flag, independent of the exact intermediate state path);
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
    // Gate syncs to the foreground-resumed state only. Default to allowed for
    // the brief startup window before the first lifecycle event arrives
    // (lifecycleState is null then) so the cold-start sync isn't gated off.
    _isAppResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onLifecycleChange,
    );
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

  /// Tracks whether the app left the foreground-resumed state — to any of
  /// `inactive`/`hidden`/`paused`/`detached` — since the last `resumed`. Used
  /// to replay a catch-up sync on return, so a sync requested while the gate
  /// was closed is never lost.
  bool _wasAway = false;

  final Queue<SyncKind> _queue = Queue<SyncKind>();
  final Set<SyncKind> _enqueued = <SyncKind>{};
  SyncKind? _running;
  bool _draining = false;
  Future<Map<SyncKind, Object>>? _activeDrain;
  final Map<SyncKind, Object> _lastErrors = <SyncKind, Object>{};
  final Map<SyncKind, DateTime> _lastSuccessAt = <SyncKind, DateTime>{};

  /// Schedule `kinds` (or all kinds when `only` is null) and resolve once the
  /// queue has drained. Iteration order follows the [SyncKind] enum
  /// declaration (bitcoin → liquid → swaps) regardless of how callers
  /// constructed `only`.
  ///
  /// Pass `force: true` to bypass the per-kind throttle — reserved for
  /// explicit user gestures (pull-to-refresh). Default callers (route-aware
  /// triggers, lifecycle resumption) should leave `force` at `false`.
  ///
  /// Returns immediately if the app is not foreground-resumed or every
  /// requested kind was deduped/throttled. Throws [SyncCoordinatorException]
  /// when any requested kind failed during the drain pass that satisfied this
  /// call.
  Future<void> sync({Set<SyncKind>? only, bool force = false}) async {
    final requested = SyncKind.values
        .where((k) => only?.contains(k) ?? true)
        .toList(growable: false);
    final started = DateTime.now();
    final dropped = <String>[];
    for (final kind in requested) {
      final reason = _enqueue(kind, force: force);
      if (reason != null) dropped.add('${kind.name}:$reason');
    }
    if (dropped.isNotEmpty) {
      log.info('[SyncCoordinator] sync dropped (${dropped.join(', ')})');
    }
    final settledErrors = await _drain();
    final failures = <SyncKind, Object>{
      for (final kind in requested)
        if (settledErrors[kind] != null) kind: settledErrors[kind]!,
    };
    final elapsedMs = DateTime.now().difference(started).inMilliseconds;
    final kinds = requested.map((k) => k.name).join(', ');
    if (failures.isEmpty) {
      log.fine('[SyncCoordinator] sync ok ($kinds) in ${elapsedMs}ms');
      return;
    }
    // One sanitized summary (kind:runtimeType only — no wallet identifiers
    // reach Sentry). severe keeps failures visible in monitoring.
    final failed = failures.entries
        .map((e) => '${e.key.name}:${e.value.runtimeType}')
        .join(', ');
    log.severe(
      message: '[SyncCoordinator] sync failed ($failed) in ${elapsedMs}ms',
      error: SyncCoordinatorException(failures),
      trace: StackTrace.current,
    );
    throw SyncCoordinatorException(failures);
  }

  /// Returns null when the kind was enqueued, or a short reason it was dropped:
  /// 'gated' (app not resumed), 'throttled' (synced within [_minSyncInterval]),
  /// or 'pending' (already running or queued).
  String? _enqueue(SyncKind kind, {required bool force}) {
    if (!_isAppResumed) return 'gated';
    if (!force) {
      final last = _lastSuccessAt[kind];
      if (last != null && DateTime.now().difference(last) < _minSyncInterval) {
        return 'throttled';
      }
    }
    if (_running == kind || _enqueued.contains(kind)) return 'pending';
    _enqueued.add(kind);
    _queue.add(kind);
    return null;
  }

  Future<Map<SyncKind, Object>> _drain() {
    final inFlight = _activeDrain;
    if (inFlight != null) return inFlight;
    final future = _drainOnce();
    _activeDrain = future;
    return future.whenComplete(() {
      if (identical(_activeDrain, future)) {
        _activeDrain = null;
      }
      if (_queue.isNotEmpty && !_draining) {
        unawaited(_drain());
      }
    });
  }

  Future<Map<SyncKind, Object>> _drainOnce() async {
    _draining = true;
    _lastErrors.clear();
    try {
      while (_queue.isNotEmpty) {
        final kind = _queue.removeFirst();
        _enqueued.remove(kind);
        _running = kind;
        try {
          await _runTask(kind);
          _lastSuccessAt[kind] = DateTime.now();
        } catch (e) {
          // Stored for the single sanitized summary logged by sync().
          _lastErrors[kind] = e;
        }
        _running = null;
      }
      return Map<SyncKind, Object>.of(_lastErrors);
    } finally {
      _draining = false;
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
    final isResumed = state == AppLifecycleState.resumed;
    // Leaving resumed for any reason (inactive/hidden/paused/detached) closes
    // the gate; remember it so the return-to-resumed below replays any sync
    // that was gated off while away.
    if (!isResumed) _wasAway = true;
    _isAppResumed = isResumed;
    if (isResumed && _wasAway) {
      _wasAway = false;
      // sync() may throw SyncCoordinatorException; ignore here — the drain
      // path already logged a sanitized SEVERE for any failed kind, and the
      // lifecycle-triggered refresh is best-effort with no awaiting caller.
      sync().ignore();
    }
  }

  void dispose() {
    _lifecycleListener.dispose();
  }
}

/// Thrown by [SyncCoordinator.sync] when any of the requested kinds failed
/// during the drain pass that satisfied the call.
class SyncCoordinatorException implements Exception {
  const SyncCoordinatorException(this.failures);

  final Map<SyncKind, Object> failures;

  @override
  String toString() =>
      'SyncCoordinatorException(${failures.entries.map((e) => '${e.key}: ${e.value.runtimeType}').join(', ')})';
}
