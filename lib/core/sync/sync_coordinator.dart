import 'dart:async';
import 'dart:collection';

import 'package:bb_mobile/core/sync/sync_kind.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';
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
///    [_minSyncInterval] is skipped on the next enqueue for an
///    [SyncTrigger.automatic] request; [SyncTrigger.user] requests
///    (pull-to-refresh and other explicit gestures) bypass the throttle.
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
  /// caller passes [SyncTrigger.user].
  static const Duration _minSyncInterval = Duration(seconds: 2);

  final GetWalletsUsecase _getWallets;
  final SyncWalletUsecase _syncWallet;
  final RestartSwapWatcherUsecase _restartSwaps;
  // Restarts the SP taproot electrum listener on foreground. Wired from the
  // composition root (SpLocator) via [resyncSpListener] so this core
  // orchestrator never imports the SP feature; a no-op until then.
  Future<void> Function() _resyncSp = _noopResync;

  static Future<void> _noopResync() async {}

  /// Register the SP listener resync callback. Called from `SpLocator` so core
  /// stays feature-agnostic (rule #7).
  set resyncSpListener(Future<void> Function() callback) =>
      _resyncSp = callback;

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
  Future<void>? _activeDrain;
  final Map<SyncKind, DateTime> _lastSuccessAt = <SyncKind, DateTime>{};

  /// Per-kind waiters. A [sync] call registers a completer for each kind it
  /// enqueues (or that is already pending) and awaits exactly those, so it
  /// resolves when *its* kinds settle — independent of which drain ran them.
  /// Each completer carries the kind's error (or null on success) as its
  /// value, never via [Completer.completeError].
  final Map<SyncKind, List<Completer<Object?>>> _waiters =
      <SyncKind, List<Completer<Object?>>>{};

  /// Schedule `kinds` (or all kinds when `only` is null) and resolve once
  /// every requested kind that actually runs has settled. Resolution tracks
  /// this call's own kinds (via per-kind completers), so it is correct even
  /// when those kinds are drained by a pass another caller started. Execution
  /// order follows the [SyncKind] enum declaration (bitcoin -> liquid -> swaps).
  ///
  /// Pass [SyncTrigger.user] to bypass the per-kind throttle — reserved for
  /// explicit user gestures (pull-to-refresh). Default callers (route-aware
  /// triggers, lifecycle resumption) use [SyncTrigger.automatic].
  ///
  /// Returns immediately if the app is not foreground-resumed or every
  /// requested kind was deduped/throttled. Throws [SyncCoordinatorException]
  /// when any requested kind failed during the drain pass that satisfied this
  /// call.
  Future<void> sync({
    Set<SyncKind>? only,
    SyncTrigger trigger = SyncTrigger.automatic,
  }) async {
    final requested = SyncKind.values
        .where((k) => only?.contains(k) ?? true)
        .toList(growable: false);
    final started = DateTime.now();
    final dropped = <String>[];
    final waits = <SyncKind, Future<Object?>>{};
    for (final kind in requested) {
      final reason = _enqueue(kind, trigger: trigger);
      if (reason == null || reason == 'pending') {
        // Will run now, or is already running/queued — wait for it to settle.
        final completer = Completer<Object?>();
        (_waiters[kind] ??= <Completer<Object?>>[]).add(completer);
        waits[kind] = completer.future;
      } else {
        // 'gated' or 'throttled': this kind won't run, so don't await it.
        dropped.add('${kind.name}:$reason');
      }
    }
    if (dropped.isNotEmpty) {
      log.info('[SyncCoordinator] sync dropped (${dropped.join(', ')})');
    }
    unawaited(_drain());
    final settled = await Future.wait(
      waits.entries.map((e) async => MapEntry(e.key, await e.value)),
    );
    final failures = <SyncKind, Object>{
      for (final entry in settled)
        if (entry.value != null) entry.key: entry.value!,
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
  String? _enqueue(SyncKind kind, {required SyncTrigger trigger}) {
    if (!_isAppResumed) return 'gated';
    if (trigger == SyncTrigger.automatic) {
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

  Future<void> _drain() {
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

  Future<void> _drainOnce() async {
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final kind = _queue.removeFirst();
        _enqueued.remove(kind);
        _running = kind;
        try {
          await _runTask(kind);
          _lastSuccessAt[kind] = DateTime.now();
          _settle(kind, null);
        } catch (e) {
          // Delivered to any sync() awaiting this kind; the single sanitized
          // summary is logged by sync().
          _settle(kind, e);
        } finally {
          _running = null;
        }
      }
    } finally {
      _draining = false;
    }
  }

  /// Completes (and clears) every waiter registered for [kind] with [error]
  /// (null on success), waking any [sync] call awaiting that kind. The error
  /// is delivered as the completer's value, so awaiting a waiter never throws.
  void _settle(SyncKind kind, Object? error) {
    final waiters = _waiters.remove(kind);
    if (waiters == null) return;
    for (final completer in waiters) {
      if (!completer.isCompleted) completer.complete(error);
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
      case SyncKind.sp:
        await _resyncSp();
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
