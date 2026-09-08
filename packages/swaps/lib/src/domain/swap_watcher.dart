import 'dart:async';
import 'dart:math';

import 'package:swaps/src/log.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/swap_repository.dart';

/// The one driver in the system: makes sure every swap reaches a terminal
/// state. Blocs never move a swap — they read; the watcher acts.
///
/// On [start]: retract unproven completions, then sweep every ongoing swap
/// (act by status), subscribe to live events and reconcile against the
/// backend (events are never trusted to replay). A heartbeat repeats the
/// full sweep while ongoing swaps exist — a websocket can be connected yet
/// mute, timers freeze under app suspension, and the Boltz API can be down
/// while electrum still works, so recovery never depends on any of them.
class SwapWatcher {
  final SwapRepository _repo;
  final Duration _heartbeat;

  StreamSubscription<Swap>? _updates;
  Timer? _heartbeatTimer;
  final Set<String> _inFlight = {};
  final Map<String, ({int attempts, DateTime nextAttemptAt})> _retrySchedule =
      {};
  static const _maxRetryDelay = Duration(minutes: 30);

  SwapWatcher({
    required this._repo,
    this._heartbeat = const Duration(minutes: 3),
  });

  /// Never throws — the watcher must not break startup.
  Future<void> start() async {
    try {
      await _repo.verifyCompletions();
      _updates ??= _repo.updates.listen(
        (swap) => unawaited(processSwap(swap)),
        onError: (Object e) => swapsLog.warning('SWAPS: updates error: $e'),
        cancelOnError: false,
      );
      await _sweep();
      _heartbeatTimer ??= Timer.periodic(
        _heartbeat,
        (_) => unawaited(_onHeartbeat()),
      );
    } catch (e) {
      swapsLog.warning('SWAPS: watcher start failed: $e');
    }
  }

  Future<void> stop() async {
    await _updates?.cancel();
    _updates = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Explicit "look now": clears backoffs (a user-triggered sync is a retry
  /// lever, not an event replay to be suppressed) and re-sweeps.
  Future<void> restart() async {
    _retrySchedule.clear();
    await _sweep();
  }

  bool _sweeping = false;

  /// The heartbeat is a full sweep, not just a reconcile: reconciliation
  /// needs the Boltz API, but claim/refund/coop-sign work Boltz-free via
  /// electrum, so a mid-session retry of a failed action must not depend on
  /// the backend re-emitting the swap. Backoff gating in [processSwap] keeps
  /// this from hot-looping.
  Future<void> _onHeartbeat() async {
    if (_sweeping) return;
    try {
      await _sweep();
    } catch (e) {
      swapsLog.warning('SWAPS: heartbeat failed: $e');
    }
  }

  Future<void> _sweep() async {
    _sweeping = true;
    try {
      var ongoing = await _repo.ongoing();
      if (ongoing.isEmpty) {
        swapsLog.fine('SWAPS: no ongoing swaps to drive');
        return;
      }
      swapsLog.fine(
        'SWAPS: driving ${ongoing.length} ongoing swap(s): '
        '${ongoing.map((s) => s.id).join(',')}',
      );
      _repo.listen([for (final s in ongoing) s.id]);
      try {
        await _repo.reconcile([for (final s in ongoing) s.id]);
        // Reconcile may have moved statuses — act on the fresh rows.
        ongoing = await _repo.ongoing();
      } catch (e) {
        swapsLog.warning('SWAPS: reconcile failed, driving stored state: $e');
      }
      for (final swap in ongoing) {
        await processSwap(swap);
      }
      await swapsLog.flush();
    } finally {
      _sweeping = false;
    }
  }

  /// Acts on [swap] according to its status. Safe to call repeatedly: the
  /// resolve operations are idempotent on recorded txids, concurrent calls
  /// for the same swap coalesce, and failures back off exponentially.
  Future<void> processSwap(Swap swap) async {
    if (!_shouldAttempt(swap.id)) return;
    if (_inFlight.contains(swap.id)) {
      swapsLog.fine('SWAPS: ${swap.id} action already in flight — coalesced');
      return;
    }
    _inFlight.add(swap.id);
    try {
      switch (swap.status) {
        case SwapStatus.claimable:
          await _repo.claim(swap);
          _clearRetries(swap.id);
        case SwapStatus.refundable:
          await _repo.refund(swap);
          _clearRetries(swap.id);
        case SwapStatus.canCoop:
          await _repo.coopSign(swap);
          _clearRetries(swap.id);
        case SwapStatus.completed:
          // Completed without a recorded claim means the claim never
          // happened (MRH direct payments excepted) — re-claim.
          final needsReclaim = switch (swap) {
            LnReceiveSwap(:final receiveTxid, :final wasDirectPayment) =>
              receiveTxid == null && !wasDirectPayment,
            ChainSwap(:final receiveTxid, :final refundTxid) =>
              receiveTxid == null && refundTxid == null,
            LnSendSwap() => false,
          };
          if (needsReclaim) {
            await _repo.claim(swap);
            _clearRetries(swap.id);
          }
        case SwapStatus.pending:
        case SwapStatus.paid:
        case SwapStatus.refunded:
        case SwapStatus.expired:
        case SwapStatus.failed:
          break;
      }
    } catch (e) {
      _recordFailure(swap.id);
      swapsLog.warning(
        'SWAPS: action failed for ${swap.id} (${swap.status.name}): $e',
      );
    } finally {
      _inFlight.remove(swap.id);
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
