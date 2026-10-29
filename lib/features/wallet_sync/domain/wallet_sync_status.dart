import 'package:transaction_sync/transaction_sync.dart';
import 'wallet_sync_options_failure.dart';

/// Local presentation evidence. Missing chain data remains unknown.
final class WalletSyncStatus {
  final BitcoinSyncSource source;
  final BitcoinSyncProgress? progress;
  final bool recoveryRequired;
  final DateTime? scanDate;
  final DateTime? lastSuccessfulSync;
  final bool torEnabled;
  final bool emptyRecovery;
  final WalletSyncOptionsFailure? failure;
  final int? etaMinutes;
  final DateTime? rateObservedAt;

  const WalletSyncStatus({
    this.source = BitcoinSyncSource.compactBlockFilters,
    this.progress,
    this.recoveryRequired = true,
    this.scanDate,
    this.lastSuccessfulSync,
    this.torEnabled = false,
    this.emptyRecovery = false,
    this.failure,
    this.etaMinutes,
    this.rateObservedAt,
  });

  bool get isPrivate => source == BitcoinSyncSource.compactBlockFilters;
  bool get incomplete => isPrivate && recoveryRequired;
  int? get totalBlocks => switch (progress) {
    BitcoinSyncProgress(startHeight: final start?, targetHeight: final tip?) =>
      (tip - start).clamp(0, tip),
    _ => null,
  };
  int? get checkedBlocks => switch ((progress, totalBlocks)) {
    (
      BitcoinSyncProgress(
        startHeight: final start?,
        reachedHeight: final reached?,
      ),
      final total?,
    ) =>
      (reached - start).clamp(0, total),
    _ => null,
  };

  int? etaAt(DateTime now) {
    final observed = rateObservedAt;
    return failure == null &&
            progress?.phase == BitcoinSyncPhase.checkingBlocks &&
            observed != null &&
            now.difference(observed) <= const Duration(seconds: 10)
        ? etaMinutes
        : null;
  }

  WalletSyncStatus copyWith({
    BitcoinSyncProgress? progress,
    bool? recoveryRequired,
    DateTime? lastSuccessfulSync,
    bool? emptyRecovery,
    bool? torEnabled,
    WalletSyncOptionsFailure? failure,
    bool clearFailure = false,
    int? etaMinutes,
    DateTime? rateObservedAt,
  }) => WalletSyncStatus(
    source: source,
    progress: progress ?? this.progress,
    recoveryRequired: recoveryRequired ?? this.recoveryRequired,
    scanDate: scanDate,
    lastSuccessfulSync: lastSuccessfulSync ?? this.lastSuccessfulSync,
    torEnabled: torEnabled ?? this.torEnabled,
    emptyRecovery: emptyRecovery ?? this.emptyRecovery,
    failure: clearFailure ? null : failure ?? this.failure,
    etaMinutes: etaMinutes,
    rateObservedAt: rateObservedAt,
  );
}

/// An estimate requires thirty seconds of continuous, steady filter progress.
final class RecoveryRate {
  DateTime? _start;
  DateTime? _lastAt;
  double? _first;
  double? _last;
  double? _rate;

  int? observe(double fraction, DateTime now) {
    final first = _first;
    final last = _last;
    final start = _start;
    final lastAt = _lastAt;
    if (first == null ||
        last == null ||
        start == null ||
        lastAt == null ||
        fraction <= last ||
        now.difference(lastAt) > const Duration(seconds: 10)) {
      _start = _lastAt = now;
      _first = _last = fraction;
      _rate = null;
      return null;
    }
    final seconds = now.difference(lastAt).inMilliseconds / 1000;
    if (seconds <= 0) return null;
    final rate = (fraction - last) / seconds;
    final previousRate = _rate;
    if (previousRate != null && rate < previousRate * 0.7) {
      _start = now;
      _first = fraction;
    }
    _last = fraction;
    _lastAt = now;
    _rate = rate;
    final steadyStart = _start;
    final steadyFirst = _first;
    if (steadyStart == null ||
        steadyFirst == null ||
        now.difference(steadyStart) < const Duration(seconds: 30)) {
      return null;
    }
    final average =
        (fraction - steadyFirst) /
        (now.difference(steadyStart).inMilliseconds / 1000);
    if (average <= 0) return null;
    return ((1 - fraction) / average / 60).ceil().clamp(1, 9999);
  }
}
