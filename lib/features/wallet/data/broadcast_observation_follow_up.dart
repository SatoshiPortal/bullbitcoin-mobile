import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:clock/clock.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/write.dart'
    show BitcoinBroadcastReceipt, BitcoinSpendStatus;

import '../domain/wallet_spend_failure.dart';

typedef BroadcastBitcoin =
    Future<Result<BitcoinBroadcastReceipt, WalletSpendFailure>> Function(
      String walletId,
      BitcoinNetwork network,
      Future<String> Function() broadcast,
    );

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

  /// [broadcast] with the follow-up started on success only. The result is
  /// returned unchanged.
  BroadcastBitcoin wrap(BroadcastBitcoin broadcast) =>
      (walletId, network, send) async {
        final result = await broadcast(walletId, network, send);
        if (result is Ok) start(walletId);
        return result;
      };

  /// Starts a follow-up for [walletId], replacing the one in progress.
  void start(String walletId) {
    if (_disposed) return;
    _runs.remove(walletId)?.cancel();
    final run = _Run();
    _runs[walletId] = run;
    unawaited(
      _follow(walletId, run).catchError((Object error) {
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

  Future<void> _follow(String walletId, _Run run) async {
    final elapsed = clock.stopwatch()..start();
    try {
      for (final deadline in deadlines) {
        final wait = deadline - elapsed.elapsed;
        if (wait.isNegative) continue;
        await run.sleep(wait);
        if (!_isCurrent(walletId, run)) return;
        try {
          // Busy, pending and unavailable all mean "not observed yet": only
          // ready ends the follow-up early.
          if (await _spendStatus(walletId) == BitcoinSpendStatus.ready) return;
          if (!_isCurrent(walletId, run)) return;
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
