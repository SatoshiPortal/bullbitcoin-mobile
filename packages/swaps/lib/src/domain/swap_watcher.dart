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

  final List<StreamSubscription<Swap>> _updates = [];
  Timer? _heartbeatTimer;
  final Map<String, Future<void>> _inFlight = {};
  bool _stopped = false;
  final Map<String, ({int attempts, DateTime nextAttemptAt})> _retrySchedule =
      {};
  static const _maxRetryDelay = Duration(minutes: 30);

  SwapWatcher({
    required this._store,
    required this._resolvers,
    this._heartbeat = const Duration(minutes: 3),
  });

  /// Arms the heartbeat and the live-update listeners if they are not
  /// running yet. Called wherever a swap is created, funded or rescued, so a
  /// session that never ran [start] (the app launched before a wallet
  /// existed) still drives every swap it touches.
  void ensureRunning() {
    _stopped = false;
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
  Future<void> start() async {
    try {
      // Heartbeat and event subscriptions are armed FIRST: if anything in
      // the initial verify/sweep throws, the periodic driver must already
      // exist or the session would run with no recovery at all.
      ensureRunning();
      for (final resolver in _resolvers.values) {
        if (await resolver.verifyCompletions() case Err(:final failure)) {
          swapsLog.warning('SWAPS: completions not verified: $failure');
        }
      }
      await _sweep();
    } catch (e) {
      swapsLog.warning('SWAPS: watcher start failed (${e.runtimeType})');
    }
  }

  /// Stops driving and waits for actions already running, so nothing acts
  /// on a swap after this returns.
  Future<void> stop() async {
    _stopped = true;
    for (final subscription in _updates) {
      await subscription.cancel();
    }
    _updates.clear();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await Future.wait(_inFlight.values.toList());
  }

  /// Explicit "look now": clears backoffs (a user-triggered sync is a retry
  /// lever, not an event replay to be suppressed) and re-sweeps.
  Future<void> restart() async {
    _retrySchedule.clear();
    await _sweep();
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
      await _sweep();
    } catch (e) {
      swapsLog.warning('SWAPS: heartbeat failed (${e.runtimeType})');
    }
  }

  Future<void> _sweep() async {
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
      for (final MapEntry(key: provider, value: resolver)
          in _resolvers.entries) {
        final ids = [
          for (final swap in before)
            if (swap.provider == provider) swap.id,
        ];
        if (ids.isEmpty) continue;
        resolver.listen(ids);
        if (await resolver.reconcile(ids) case Err(:final failure)) {
          swapsLog.warning('SWAPS: reconcile failed, driving stored: $failure');
        }
      }
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
    if (_stopped || !_shouldAttempt(swap.id)) return;
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
  /// Runs after any action already in flight for the swap, never beside it.
  Future<Result<Swap, SwapsFailure>> retry(Swap swap) async {
    final resolver = _resolvers[swap.provider];
    if (resolver == null) {
      return Err(SwapsUnexpectedFailure('no resolver for ${swap.provider}'));
    }
    await _inFlight[swap.id];
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
