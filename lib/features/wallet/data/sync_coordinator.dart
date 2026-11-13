import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/read_wallet_usecase.dart';
import 'package:transaction_sync/read.dart';
import 'package:transaction_sync/transaction_sync.dart'
    show SyncReason, TransactionSyncBusyFailure;
import 'package:bb_mobile/features/wallet/domain/wallet_failure_log_code.dart';
import 'dart:async';
import 'package:bb_mobile/features/wallet/domain/wallet_discovery_failure.dart';
import 'dart:collection';

import 'package:bb_mobile/core/sync/sync_kind.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState, WidgetsBinding;

/// Foreground sync orchestrator.
///
/// Schedules per-kind sync work (bitcoin and liquid) so that:
///  - the same kind is **never** run concurrently — duplicate requests are
///    dropped while one is queued or running;
///  - different kinds are **queued** and executed sequentially in FIFO order
///    (matching the [SyncKind] enum declaration), avoiding concurrent writes
///    to the shared drift database, avoiding "database is locked" errors;
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
    this._syncSwaps,
    this._syncSwapsOutcome,
    this._syncSp,
    this._refreshRevisions,
    this._readNetwork,
    this._readWalletUsecase,
    DateTime Function()? now,
  }) : _getWallets = getWalletsUsecase,
       _syncWallet = syncWalletUsecase,
       _now = now ?? DateTime.now {
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

  /// Minimum time between automatic Bitcoin discovery attempts in one
  /// environment. Routine passes query revealed scripts only, so funds sent
  /// to an address this device never revealed stay invisible until a
  /// discovery pass. A pull always discovers; the first eligible automatic
  /// pass of the process discovers too, then at most one per window. Every
  /// discovery attempt opens the window when it is queued, failed ones and
  /// pulls included; a throttled or gated call opens nothing. This is not a
  /// timer: nothing runs without a sync call.
  static const Duration _automaticDiscoveryInterval = Duration(minutes: 10);

  final DateTime Function() _now;
  final Map<Environment, DateTime> _automaticDiscoveryAttemptAt = {};

  final Future<Environment> Function()? _readNetwork;
  final ReadWalletUsecase? _readWalletUsecase;
  final GetWalletsUsecase _getWallets;
  final SyncWalletUsecase _syncWallet;
  final Future<void> Function()? _syncSwaps;
  // The SP side of a sync tick: resume the chain scan when the SP feature's
  // policy allows it. Passed as a lazy closure from the composition root, like
  // the swap callbacks, so this core orchestrator never imports the SP feature
  // (rule #7).
  final Future<void> Function()? _syncSp;
  final Future<void> Function()? _refreshRevisions;
  final Future<SyncOutcome> Function()? _syncSwapsOutcome;

  SyncOutcome? lastSwapSyncOutcome;

  late final AppLifecycleListener _lifecycleListener;
  bool _isAppResumed = true;

  /// Tracks whether the app left the foreground-resumed state — to any of
  /// `inactive`/`hidden`/`paused`/`detached` — since the last `resumed`. Used
  /// to replay a catch-up sync on return, so a sync requested while the gate
  /// was closed is never lost.
  bool _wasAway = false;

  final Queue<_SyncPass> _queue = Queue<_SyncPass>();
  final Map<SyncKind, _SyncPass> _enqueued = {};
  final Map<String, _SyncPass> _manualPasses = {};
  _SyncPass? _running;
  bool _draining = false;
  final _activity = StreamController<bool>.broadcast(sync: true);

  Future<void>? _activeDrain;
  final Map<SyncKind, String> _lastOutcome = {};
  final Map<SyncKind, DateTime> _lastSuccessAt = <SyncKind, DateTime>{};

  /// Covers the whole foreground queue, including discovery and queued kinds.
  bool get isSyncPassActive => _draining;
  Stream<bool> get syncPassActivity => _activity.stream;

  /// Schedule `kinds` (or the trigger's default kinds when `only` is null) and
  /// resolve once every requested kind that actually runs has settled. Resolution tracks
  /// this call's own kinds (via per-kind completers), so it is correct even
  /// when those kinds are drained by a pass another caller started. Execution
  /// order follows the [SyncKind] enum declaration (bitcoin → liquid → swaps → sp).
  ///
  /// Pass [SyncTrigger.user] to bypass the per-kind throttle; reserved for
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
    final requestedKinds = only ?? _defaultKinds(trigger);
    final requested = SyncKind.values
        .where(requestedKinds.contains)
        .toList(growable: false);
    final dropped = <String>[];
    final waits = <SyncKind, Future<Object?>>{};
    final discoveryScope = requested.contains(SyncKind.bitcoin)
        ? await _environment()
        : null;
    for (final kind in requested) {
      final discover =
          kind == SyncKind.bitcoin &&
          discoveryScope != null &&
          _discoveryDue(trigger, discoveryScope);
      final (pass, reason) = _enqueue(
        kind,
        trigger: trigger,
        discover: discover,
      );
      if (discover && pass != null && pass.discover) {
        _automaticDiscoveryAttemptAt[discoveryScope] = _now();
      }
      if (pass != null) {
        final completer = Completer<Object?>();
        pass.waiters.add(completer);
        waits[kind] = completer.future;
      } else {
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
    if (failures.isEmpty) return;
    throw SyncCoordinatorException(failures);
  }

  Future<Environment> _environment() async {
    final readNetwork = _readNetwork;
    return readNetwork == null ? Environment.mainnet : await readNetwork();
  }

  bool _discoveryDue(SyncTrigger trigger, Environment scope) {
    if (trigger == SyncTrigger.user) return true;
    final last = _automaticDiscoveryAttemptAt[scope];
    return last == null ||
        _now().difference(last) >= _automaticDiscoveryInterval;
  }

  /// Explicit recovery is wallet-scoped, bypasses throttling and shares the
  /// foreground FIFO. It cannot join an already-running routine pass.
  Future<Result<void, WalletDiscoveryFailure>> discoverWallet(
    String walletId,
  ) async {
    if (!_isAppResumed) return const Err(WalletDiscoveryUnavailableFailure());
    try {
      var pass = _manualPasses[walletId];
      if (pass == null) {
        final result = await _getWallets.execute();
        if (result case Err()) {
          return const Err(WalletDiscoveryUnavailableFailure());
        }
        final wallets = switch (result) {
          Ok(:final value) => value,
          Err() => <Wallet>[],
        };
        final wallet = wallets
            .where((wallet) => wallet.id == walletId)
            .firstOrNull;
        if (wallet == null || !_isAppResumed) {
          return const Err(WalletDiscoveryUnavailableFailure());
        }
        final kind = wallet.isLiquid ? SyncKind.liquid : SyncKind.bitcoin;
        // Admission can yield; another caller may have queued the same wallet.
        pass = _manualPasses[walletId];
        if (pass == null) {
          pass = _SyncPass(
            kind,
            wallet.isBitcoin,
            SyncTrigger.user,
            walletId: walletId,
            walletNetwork: wallet.network,
          );
          _manualPasses[walletId] = pass;
          _queue.add(pass);
        }
      }
      final waiter = Completer<Object?>();
      pass.waiters.add(waiter);
      unawaited(_drain());
      final failure = await waiter.future;
      return switch (failure) {
        null => const Ok(null),
        WalletDiscoveryFailure() => Err(failure),
        _ => const Err(WalletDiscoverySyncFailure()),
      };
    } on Exception {
      return const Err(WalletDiscoverySyncFailure());
    }
  }

  /// Screen polling has its own cadence, independent of the global throttle.
  /// Await covered work in the FIFO without upgrading or duplicating it.
  Future<void> pollWallet(
    String walletId, {
    required bool Function() isActive,
  }) async {
    if (!_isAppResumed || !isActive()) return;
    final wallet = await _readPollingWallet(walletId);
    if (!_isAppResumed || !isActive()) return;
    if (wallet != null) {
      final kind = wallet.isLiquid ? SyncKind.liquid : SyncKind.bitcoin;
      bool covers(_SyncPass pass) =>
          pass.walletId == walletId ||
          (pass.walletId == null && pass.kind == kind);
      final running = _running;
      final covered = running != null && covers(running)
          ? running
          : _queue
                .where(
                  (pass) => covers(pass) && (pass.isActive?.call() ?? true),
                )
                .firstOrNull;
      if (covered != null) {
        final waiter = Completer<Object?>();
        covered.waiters.add(waiter);
        await waiter.future;
        // A queued screen request may have expired while we were waiting.
        // Its skipped admission is not the new screen's immediate sync.
        if (covered.wallets == 0 &&
            covered.isActive?.call() == false &&
            _isAppResumed &&
            isActive()) {
          await pollWallet(walletId, isActive: isActive);
        }
        return;
      }
      final pass = _SyncPass(
        kind,
        false,
        SyncTrigger.automatic,
        walletId: walletId,
        walletNetwork: wallet.network,
        isActive: isActive,
      );
      final waiter = Completer<Object?>();
      pass.waiters.add(waiter);
      _queue.add(pass);
      unawaited(_drain());
      // The pass and native boundary own diagnostics, including quiet busy.
      await waiter.future;
    }
  }

  Future<Wallet?> _readPollingWallet(String walletId) async {
    // Polling must not hydrate unrelated wallets just to select its target.
    final result = await _readWalletUsecase?.execute(walletId);
    if (result case Ok(:final value)) {
      final readNetwork = _readNetwork;
      final environment = readNetwork == null
          ? Environment.mainnet
          : await readNetwork();
      final walletEnvironment = switch (value.network) {
        Network.bitcoinMainnet || Network.liquidMainnet => Environment.mainnet,
        Network.bitcoinTestnet || Network.liquidTestnet => Environment.testnet,
      };
      if (walletEnvironment == environment) return value;
    }
    return null;
  }

  /// The sp kind only resumes the SP chain scan, which a user gesture must not
  /// start: the SP side of a pull-to-refresh is the snapshot read the wallet
  /// does right after.
  static Set<SyncKind> _defaultKinds(SyncTrigger trigger) => switch (trigger) {
    SyncTrigger.user => const {SyncKind.bitcoin, SyncKind.liquid},
    SyncTrigger.automatic => const {
      SyncKind.bitcoin,
      SyncKind.liquid,
      SyncKind.sp,
    },
  };

  /// An active routine pass cannot satisfy discovery. Keep its waiters separate
  /// from the discovery pass queued behind it; queued passes can be upgraded.
  (_SyncPass?, String?) _enqueue(
    SyncKind kind, {
    required SyncTrigger trigger,
    required bool discover,
  }) {
    if (!_isAppResumed) return (null, 'gated');
    final queued = _enqueued[kind];
    if (queued != null) {
      queued.discover |= discover;
      if (trigger == SyncTrigger.user) queued.trigger = trigger;
      return (queued, null);
    }
    final running = _running;
    if (running != null &&
        running.kind == kind &&
        running.walletId == null &&
        (!discover || running.discover)) {
      return (running, null);
    }
    if (trigger == SyncTrigger.automatic) {
      final last = _lastSuccessAt[kind];
      if (last != null && _now().difference(last) < _minSyncInterval) {
        return (null, 'throttled');
      }
    }
    final pass = _SyncPass(kind, discover, trigger);
    _enqueued[kind] = pass;
    _queue.add(pass);
    return (pass, null);
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
    if (_queue.isEmpty) return;
    _draining = true;
    _activity.add(true);
    try {
      while (_queue.isNotEmpty) {
        final pass = _queue.removeFirst();
        final kind = pass.kind;
        if (pass.walletId == null) _enqueued.remove(kind);
        _running = pass;
        pass.clock.start();
        try {
          // A wallet read failure fails the round without being thrown: it is
          // settled as the error and, like a throw, never stamps
          // _lastSuccessAt.
          final failure = await _runTask(pass);
          if (failure != null) {
            _settle(pass, failure);
            continue;
          }
          if (pass.walletId == null) _lastSuccessAt[kind] = _now();
          _settle(pass, null);
        } catch (e) {
          // The pass owns the summary, independently of its waiter count.
          _settle(pass, e);
        } finally {
          _running = null;
        }
      }
    } finally {
      _draining = false;
      if (!_activity.isClosed) _activity.add(false);
    }
  }

  void _settle(_SyncPass pass, Object? error) {
    final busy =
        error is WalletSnapshotException &&
        error.failure is TransactionSyncBusyFailure;
    final walletId = pass.walletId;
    if (walletId != null && pass.isActive == null) {
      _manualPasses.remove(walletId);
      log.fine(
        'Wallet discovery finished reason=manual outcome=${busy
            ? 'busy'
            : error == null
            ? 'settled'
            : 'failed'}',
      );
      for (final waiter in pass.waiters) {
        waiter.complete(error);
      }
      pass.waiters.clear();
      return;
    }
    if (error is NoWalletsFoundFailure) pass.wallets = 0;
    final outcome = error is NoWalletsFoundFailure || pass.wallets == 0
        ? 'no_wallets'
        : busy
        ? 'busy'
        : error == null
        ? 'settled'
        : 'failed';
    final category = busy
        ? 'busy'
        : error is WalletSnapshotException
        ? error.failure.logCode
        : error is WalletFailure
        ? error.logCode
        : error == null
        ? 'none'
        : 'operation';
    // Native and repository boundaries own failures. This row describes the
    // completed queue pass; legacy void sync cannot prove a native success.
    if (outcome != 'no_wallets' || _lastOutcome[pass.kind] != outcome) {
      log.fine(
        'Sync pass finished kind=${pass.kind.name} reason=${pass.reason.name} outcome=$outcome wallets=${pass.wallets ?? 'unknown'} category=$category elapsed_ms=${pass.clock.elapsedMilliseconds}',
      );
    }
    _lastOutcome[pass.kind] = outcome;
    for (final completer in pass.waiters) {
      if (!completer.isCompleted) completer.complete(error);
    }
    pass.waiters.clear();
  }

  /// Syncs every wallet the read returns, or returns the read's failure so
  /// the round fails.
  ///
  /// Deliberately not degraded to an empty list: `_drainOnce` stamps
  /// `_lastSuccessAt` for any round that completes normally, so a swallowed
  /// read failure would both report a successful sync to pull-to-refresh and
  /// count toward the throttle — suppressing the retries that would recover
  /// from a transient failure.
  Future<WalletFailure?> _syncAll(
    Future<Result<List<Wallet>, WalletFailure>> read, {
    required _SyncPass pass,
  }) async {
    switch (await read) {
      case Ok(:final value):
        pass.wallets = value.length;
        for (final wallet in value) {
          await _syncWallet.execute(
            wallet,
            discover: pass.discover,
            reason: pass.reason,
          );
        }
        return null;
      case Err(:final failure):
        return failure;
    }
  }

  /// The wallet read failure that failed the round, or null. Any other failure
  /// is thrown, as before.
  Future<Object?> _runTask(_SyncPass pass) async {
    final walletId = pass.walletId;
    if (walletId != null) {
      final isActive = pass.isActive;
      if (isActive != null) {
        pass.wallets = 0;
        if (!_isAppResumed || !isActive()) return null;
        final wallet = await _readPollingWallet(walletId);
        if (!_isAppResumed ||
            !isActive() ||
            wallet == null ||
            wallet.network != pass.walletNetwork) {
          return null;
        }
        pass.wallets = 1;
        // Receive must not bootstrap an unscanned Bitcoin wallet.
        await _syncWallet.execute(
          wallet,
          discover: false,
          allowInitialScan: false,
          reason: pass.reason,
        );
        return null;
      }
      log.fine('Wallet discovery started reason=manual');
      if (!_isAppResumed) return const WalletDiscoveryUnavailableFailure();
      // Re-resolve from the active environment after waiting in the queue.
      switch (await _getWallets.execute()) {
        case Err():
          return const WalletDiscoveryUnavailableFailure();
        case Ok(:final value):
          final wallet = value
              .where((wallet) => wallet.id == walletId)
              .firstOrNull;
          if (wallet == null || wallet.network != pass.walletNetwork) {
            return const WalletDiscoveryUnavailableFailure();
          }
          await _syncWallet.execute(
            wallet,
            discover: wallet.isBitcoin,
            reason: pass.reason,
          );
          return null;
      }
    }
    switch (pass.kind) {
      case SyncKind.bitcoin:
        return _syncAll(_getWallets.execute(onlyBitcoin: true), pass: pass);
      case SyncKind.liquid:
        return _syncAll(_getWallets.execute(onlyLiquid: true), pass: pass);
      case SyncKind.swaps:
        final outcomeCallback = _syncSwapsOutcome;
        if (outcomeCallback != null) {
          final outcome = await outcomeCallback();
          lastSwapSyncOutcome = outcome;
          if (outcome.failure != null) throw outcome.failure!;
        } else {
          await _syncSwaps!();
        }
      case SyncKind.sp:
        await _syncSp?.call();
    }
    return null;
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
      unawaited(_refreshPersistedRevisions());
      // Each pass records its outcome; underlying boundaries own failures.
      // Lifecycle refresh is best-effort with no awaiting caller.
      sync().ignore();
    }
  }

  Future<void> _refreshPersistedRevisions() async {
    try {
      await _refreshRevisions?.call();
    } on Exception {
      log.warning(
        'Wallet resume revision read unavailable category=revision_read',
      );
    }
  }

  void dispose() {
    _lifecycleListener.dispose();
    unawaited(_activity.close());
  }
}

enum SyncOutcomeKind { active, idle, rateLimited }

class SyncOutcome {
  const SyncOutcome._(this.kind, {this.retryAfter, this.failure});

  const SyncOutcome.active() : this._(SyncOutcomeKind.active);
  const SyncOutcome.idle() : this._(SyncOutcomeKind.idle);
  const SyncOutcome.rateLimited({Duration? retryAfter, Object? failure})
    : this._(
        SyncOutcomeKind.rateLimited,
        retryAfter: retryAfter,
        failure: failure,
      );

  final SyncOutcomeKind kind;
  final Duration? retryAfter;
  final Object? failure;
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

final class _SyncPass {
  final SyncKind kind;
  final String? walletId;
  final Network? walletNetwork;
  final bool Function()? isActive;
  bool discover;
  SyncTrigger trigger;
  int? wallets;
  final Stopwatch clock = Stopwatch();
  final List<Completer<Object?>> waiters = [];

  _SyncPass(
    this.kind,
    this.discover,
    this.trigger, {
    this.walletId,
    this.walletNetwork,
    this.isActive,
  });

  // Queued passes follow the user-trigger upgrade; joined running passes keep their original reason.
  SyncReason get reason => walletId != null && isActive == null
      ? SyncReason.manual
      : trigger == SyncTrigger.user
      ? SyncReason.pull
      : SyncReason.auto;
}
