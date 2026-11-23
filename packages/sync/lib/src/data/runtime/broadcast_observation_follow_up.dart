import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:clock/clock.dart';
import 'package:primitives/primitives.dart';

import '../../../sync.dart'
    show
        BitcoinSpendStatus,
        SignedBitcoinTransaction,
        SignedPsbt,
        SignedTransaction,
        SpendOwner,
        SpendReceipt,
        SyncFailure,
        UnsignedSpend;

typedef BroadcastSpend = Future<Result<SpendReceipt, SyncFailure>> Function(
  String walletId,
  SignedTransaction transaction, {
  required Network network,
  UnsignedSpend? built,
  SpendOwner? owner,
  String? replacing,
});

/// After an accepted Bitcoin broadcast, the spend gate stays closed until a
/// sync pass observes the payment. The pass started right after the broadcast
/// can miss it (the server may not list it yet), and nothing else may sync
/// while the user stays on one screen. This asks for a few bounded follow-up
/// syncs of that wallet until the gate reports ready. It never touches the
/// gate and never reports anything about the broadcast itself.
final class BroadcastObservationFollowUp {
  /// Deadlines from the accepted broadcast. At most one request per deadline,
  /// none after the last; a deadline that passed during a slow request is
  /// skipped, never caught up.
  static const deadlines = [
    Duration(seconds: 3),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(seconds: 90),
  ];

  final Future<BitcoinSpendStatus> Function(String walletId) _spendStatus;
  final Future<void> Function(
    String walletId, {
    required bool Function() isActive,
  })
  _pollWallet;
  final _runs = <String, _Run>{};
  bool _disposed = false;

  BroadcastObservationFollowUp({
    required this._spendStatus,
    required this._pollWallet,
  });

  /// Wraps [broadcast] with the follow-up started after an accepted Bitcoin
  /// broadcast only: Liquid has no guard to wait for. The result is
  /// returned unchanged.
  BroadcastSpend wrap(BroadcastSpend broadcast) =>
      (
        walletId,
        transaction, {
        required network,
        built,
        owner,
        replacing,
      }) async {
        final result = await broadcast(
          walletId,
          transaction,
          network: network,
          built: built,
          owner: owner,
          replacing: replacing,
        );
        if (result is Ok &&
            (transaction is SignedPsbt ||
                transaction is SignedBitcoinTransaction)) {
          start(walletId);
        }
        return result;
      };

  /// Starts a follow-up for [walletId], replacing the one in progress.
  void start(
    String walletId, {
    bool guarded = true,
    bool pollImmediately = false,
  }) {
    if (_disposed) return;
    _runs.remove(walletId)?.cancel();
    final run = _Run();
    _runs[walletId] = run;
    unawaited(
      _follow(
        walletId,
        run,
        guarded: guarded,
        pollImmediately: pollImmediately,
      ).catchError((Object error) {
        log.warning(
          'Broadcast observation follow-up stopped error=${error.runtimeType}',
        );
      }),
    );
  }

  void dispose() {
    _disposed = true;
    for (final run in _runs.values) {
      run.cancel();
    }
    _runs.clear();
  }

  bool _isCurrent(String walletId, _Run run) =>
      !_disposed && !run.cancelled && identical(_runs[walletId], run);

  Future<void> _follow(
    String walletId,
    _Run run, {
    required bool guarded,
    required bool pollImmediately,
  }) async {
    final elapsed = clock.stopwatch()..start();
    // No new request after the last deadline, even when a late timer or a
    // slow status read lands past it; a request already started may finish.
    bool withinBudget() => elapsed.elapsed <= deadlines.last;
    try {
      if (pollImmediately) {
        try {
          await _pollWallet(
            walletId,
            isActive: () => _isCurrent(walletId, run),
          );
        } on Exception catch (error) {
          log.warning(
            'Post-broadcast sync request failed error=${error.runtimeType}',
          );
        }
      }
      if (!guarded || !_isCurrent(walletId, run)) return;
      for (final deadline in deadlines) {
        final wait = deadline - elapsed.elapsed;
        if (wait.isNegative) continue;
        await run.sleep(wait);
        if (!_isCurrent(walletId, run) || !withinBudget()) return;
        try {
          // Busy, pending and unavailable all mean "not observed yet": only
          // ready ends the follow-up early.
          if (await _spendStatus(walletId) == BitcoinSpendStatus.ready) return;
          if (!_isCurrent(walletId, run) || !withinBudget()) return;
          log.fine(
            'Broadcast observation follow-up sync requested '
            'deadline_s=${deadline.inSeconds}',
          );
          await _pollWallet(
            walletId,
            isActive: () => _isCurrent(walletId, run),
          );
        } on Exception catch (error) {
          log.warning(
            'Broadcast observation follow-up attempt failed '
            'error=${error.runtimeType}',
          );
        }
        if (!_isCurrent(walletId, run)) return;
      }
    } finally {
      if (identical(_runs[walletId], run)) _runs.remove(walletId);
    }
  }
}

final class _Run {
  bool cancelled = false;
  Timer? _timer;
  Completer<void>? _wake;

  Future<void> sleep(Duration duration) {
    final wake = Completer<void>();
    _wake = wake;
    _timer = Timer(duration, () {
      if (!wake.isCompleted) wake.complete();
    });
    return wake.future;
  }

  void cancel() {
    cancelled = true;
    _timer?.cancel();
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }
}
