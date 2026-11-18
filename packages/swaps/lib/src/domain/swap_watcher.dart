import 'dart:async';
import 'dart:math';

import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_resolver.dart';
import 'package:swaps/src/domain/swap_store.dart';
import 'package:swaps/src/log.dart';

/// The one driver in the system: makes sure every swap reaches a terminal
/// state. Blocs never move a swap — they read; the watcher acts, through the
/// [SwapResolver] of the swap's provider.
///
/// On [start]: retract unproven completions, then sweep every ongoing swap,
/// subscribe to live events and reconcile against each provider (events are
/// never trusted to replay). A heartbeat repeats the full sweep while
/// ongoing swaps exist — a websocket can be connected yet mute, timers
/// freeze under app suspension, and a provider can be down while electrum
/// still works, so recovery never depends on any of them.
class SwapWatcher {
  final SwapStore _store;
  final Map<SwapProvider, SwapResolver> _resolvers;
  final Duration _heartbeat;
  final Duration _requestBudget;

  final List<StreamSubscription<Swap>> _updates = [];
  Timer? _heartbeatTimer;
  final Map<String, Future<void>> _inFlight = {};
  bool _stopped = false;
  bool _suspended = false;
  bool _draining = false;
  Future<void>? _drain;
  Future<void>? _startup;
  Future<void>? _sweepWork;
  Future<void>? _providerWork;
  final Map<String, ({int attempts, DateTime nextAttemptAt})> _retrySchedule =
      {};
  static const _maxRetryDelay = Duration(minutes: 30);
  static const _timelockRetryDelay = Duration(hours: 1);

  SwapWatcher({
    required this._store,
    required this._resolvers,
    this._heartbeat = const Duration(minutes: 3),
    this._requestBudget = const Duration(milliseconds: 100),
  });

  bool get isRunning =>
      !_stopped && !_suspended && !_draining && _heartbeatTimer != null;

  /// Ownership is retained after a Busy response until this future completes.
  Future<void> get drained => _drain ?? Future<void>.value();

  /// A transition cannot be undone by a late creation's ensureRunning call.
  void suspend() {
    _suspended = true;
    _stopAdmission();
  }

  void _stopAdmission() {
    _stopped = true;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    for (final resolver in _resolvers.values) {
      resolver.suspendEffects();
    }
  }

  /// Arms the heartbeat and the live-update listeners if they are not
  /// running yet. Called wherever a swap is created, funded or rescued, so a
  /// session that never ran [start] (the app launched before a wallet
  /// existed) still drives every swap it touches.
  void ensureRunning() {
    if (_draining || _suspended) return;
    _stopped = false;
    for (final resolver in _resolvers.values) {
      resolver.resumeEffects();
    }
    _heartbeatTimer ??= Timer.periodic(
      _heartbeat,
      (_) => unawaited(_onHeartbeat()),
    );
    if (_updates.isEmpty) {
      for (final resolver in _resolvers.values) {
        _updates.add(
          resolver.updates.listen(
            (swap) => unawaited(processSwap(swap)),
            onError: (Object e) =>
                swapsLog.warning('SWAPS: updates error (${e.runtimeType})'),
            cancelOnError: false,
          ),
        );
      }
    }
  }

  /// Never throws — the watcher must not break startup.
  Future<void> start() {
    if (_draining) return Future<void>.value();
    final existing = _startup;
    if (existing != null) return existing;
    _suspended = false;
    late final Future<void> work;
    work = _start().whenComplete(() {
      if (identical(_startup, work)) _startup = null;
    });
    _startup = work;
    return work;
  }

  Future<void> _start() async {
    try {
      // Heartbeat and event subscriptions are armed FIRST: if anything in
      // the initial verify/sweep throws, the periodic driver must already
      // exist or the session would run with no recovery at all.
      ensureRunning();
      for (final resolver in _resolvers.values) {
        if (_stopped) return;
        if (await resolver.verifyCompletions() case Err(:final failure)) {
          swapsLog.warning('SWAPS: completions not verified: $failure');
        }
      }
      await _runSweep();
    } catch (e) {
      swapsLog.warning('SWAPS: watcher start failed (${e.runtimeType})');
    }
  }

  /// Stops admission immediately. Ok means quiescent; Busy retains the drain
  /// owner and [drained], and never authorizes a replacement signer.
  Future<Result<void, SwapsFailure>> stop() {
    _stopAdmission();
    if (!_draining) {
      _draining = true;
      final subscriptions = _updates.toList();
      _updates.clear();
      _drain = _joinOwnedWork(subscriptions).whenComplete(() {
        _draining = false;
      });
    }
    final drain = drained;
    return Future.any([
      drain.then<Result<void, SwapsFailure>>((_) => const Ok(null)),
      Future<Result<void, SwapsFailure>>.delayed(
        _requestBudget,
        () => const Err(SwapsBusyFailure()),
      ),
    ]);
  }

  Future<void> _joinOwnedWork(
    List<StreamSubscription<Swap>> subscriptions,
  ) async {
    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );
    while (true) {
      final work = <Future<void>>{
        ?_startup,
        ?_sweepWork,
        ?_providerWork,
        ..._inFlight.values,
      };
      if (work.isEmpty) return;
      await Future.wait(work);
    }
  }

  /// Explicit "look now": clears backoffs (a user-triggered sync is a retry
  /// lever, not an event replay to be suppressed) and re-sweeps.
  Future<void> restart() async {
    if (_stopped) return;
    _retrySchedule.clear();
    if (_sweeping) return;
    await _runSweep();
  }

  bool _sweeping = false;

  /// The heartbeat is a full sweep, not just a reconcile: reconciliation
  /// needs the provider, but claim/refund/coop-sign work through electrum,
  /// so a mid-session retry of a failed action must not depend on the
  /// provider re-emitting the swap. Backoff gating in [processSwap] keeps
  /// this from hot-looping.
  Future<void> _onHeartbeat() async {
    if (_sweeping) return;
    try {
      await _runSweep();
    } catch (e) {
      swapsLog.warning('SWAPS: heartbeat failed (${e.runtimeType})');
    }
  }

  Future<void> _runSweep({bool reconcile = true}) {
    if (_stopped || _suspended || _draining) return Future<void>.value();
    final existing = _sweepWork;
    if (existing != null) return existing;
    late final Future<void> work;
    work = _sweep(reconcile: reconcile).whenComplete(() {
      if (identical(_sweepWork, work)) _sweepWork = null;
    });
    _sweepWork = work;
    return work;
  }

  void _reconcileProviders(List<Swap> swaps) {
    if (_providerWork != null || _stopped) return;
    late final Future<void> work;
    work = _pollProviders(swaps).whenComplete(() {
      if (identical(_providerWork, work)) _providerWork = null;
    });
    _providerWork = work;
    unawaited(work);
  }

  Future<void> _pollProviders(List<Swap> swaps) async {
    try {
      for (final MapEntry(key: provider, value: resolver)
          in _resolvers.entries) {
        if (_stopped) return;
        final ids = [
          for (final swap in swaps)
            if (swap.provider == provider) swap.id,
        ];
        if (ids.isEmpty) continue;
        resolver.listen(ids);
        if (await resolver.reconcile(ids) case Err(:final failure)) {
          swapsLog.warning('SWAPS: reconcile failed, driving stored: $failure');
        }
      }
    } catch (error) {
      swapsLog.warning(
        'SWAPS: provider reconciliation failed (${error.runtimeType})',
      );
    }
  }

  Future<void> _sweep({required bool reconcile}) async {
    _sweeping = true;
    try {
      final List<Swap> before;
      switch (await _store.ongoing()) {
        case Ok(:final value):
          before = value;
        case Err(:final failure):
          swapsLog.warning('SWAPS: ongoing swaps unreadable: $failure');
          return;
      }
      if (before.isEmpty) {
        swapsLog.fine('SWAPS: no ongoing swaps to drive');
        return;
      }
      swapsLog.fine(
        'SWAPS: driving ${before.length} ongoing swap(s): '
        '${before.map((s) => s.id).join(',')}',
      );
      if (_stopped) return;
      if (reconcile) _reconcileProviders(before);
      // Reconcile may have moved statuses — act on the fresh rows.
      final ongoing = switch (await _store.ongoing()) {
        Ok(:final value) => value,
        Err() => before,
      };
      for (final swap in ongoing) {
        if (_stopped) break;
        await processSwap(swap);
      }
      await swapsLog.flush();
    } finally {
      _sweeping = false;
    }
  }

  /// Hands [swap] to its provider's resolver. Safe to call repeatedly:
  /// resolution is idempotent on recorded txids, concurrent calls for the
  /// same swap coalesce, and failures back off exponentially.
  Future<void> processSwap(Swap swap) async {
    if (_stopped || _draining || _suspended || !_shouldAttempt(swap.id)) return;
    final resolver = _resolvers[swap.provider];
    if (resolver == null) return;
    if (_inFlight.containsKey(swap.id)) {
      swapsLog.fine('SWAPS: ${swap.id} action already in flight — coalesced');
      return;
    }
    final action = _resolve(swap, resolver.resolve);
    _inFlight[swap.id] = action;
    try {
      await action;
    } finally {
      _inFlight.remove(swap.id);
    }
  }

  /// User-triggered retry on the script path only, without the provider.
  /// Reports Busy while another action owns the swap, never beside it.
  Future<Result<Swap, SwapsFailure>> retry(Swap swap) async {
    if (_stopped || _draining || _suspended || _inFlight.containsKey(swap.id)) {
      return const Err(SwapsBusyFailure());
    }
    final resolver = _resolvers[swap.provider];
    if (resolver == null) {
      return Err(SwapsUnexpectedFailure('no resolver for ${swap.provider}'));
    }
    final completer = Completer<void>();
    _inFlight[swap.id] = completer.future;
    try {
      final result = await resolver.resolveScriptPath(swap);
      if (result case Ok()) _clearRetries(swap.id);
      return result;
    } finally {
      _inFlight.remove(swap.id);
      completer.complete();
    }
  }

  Future<void> _resolve(
    Swap swap,
    Future<Result<Swap, SwapsFailure>> Function(Swap) resolve,
  ) async {
    switch (await resolve(swap)) {
      case Ok():
        _clearRetries(swap.id);
      case Err(failure: SwapsRefundNotFinalFailure()):
        _retrySchedule[swap.id] = (
          attempts: 0,
          nextAttemptAt: DateTime.now().add(_timelockRetryDelay),
        );
        swapsLog.fine(
          'SWAPS: ${swap.id} refund waits for its timelock; '
          'next try after $_timelockRetryDelay',
        );
      case Err(:final failure):
        _recordFailure(swap.id);
        swapsLog.warning(
          'SWAPS: action failed for ${swap.id} (${swap.status.name}): '
          '$failure',
        );
    }
  }

  bool _shouldAttempt(String swapId) {
    final schedule = _retrySchedule[swapId];
    return schedule == null || DateTime.now().isAfter(schedule.nextAttemptAt);
  }

  void _recordFailure(String swapId) {
    final attempts = (_retrySchedule[swapId]?.attempts ?? 0) + 1;
    final delay = Duration(minutes: min(1 << min(attempts, 5), 30));
    final clamped = delay > _maxRetryDelay ? _maxRetryDelay : delay;
    _retrySchedule[swapId] = (
      attempts: attempts,
      nextAttemptAt: DateTime.now().add(clamped),
    );
    swapsLog.fine(
      'SWAPS: $swapId attempt $attempts failed; next after $clamped',
    );
  }

  void _clearRetries(String swapId) => _retrySchedule.remove(swapId);
}
