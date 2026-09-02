import 'dart:collection';

import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/sp_scan_policy.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sp_state.freezed.dart';

/// The two phases of an SP scan, reported separately by bwk: the receive
/// (output) scan, then the spend (input) sweep.
enum SpScanPhase { receive, spend }

/// `reconnecting` is a transient initial-sync failure the cubit is retrying.
/// `failed` means the retries ran out, or the stored chain itself is bad.
enum SpHeaderValidationStatus { idle, validating, reconnecting, valid, failed }

@freezed
sealed class SpState with _$SpState {
  const factory SpState({
    SpFailure? error,
    @Default(false) bool isLoading,

    // Wallet data (populated in load()). Domain types only.
    SpBalance? balance,
    @Default('') String spAddress,
    // Last taproot address revealed via an explicit "generate" action.
    // Empty until the user taps generate; each tap reveals a fresh address
    // (never re-displays a prior one, no address reuse).
    @Default('') String taprootReceiveAddress,
    @Default(false) bool isGeneratingAddress,
    // True while a revoke is tearing the wallet down, so the screens can block
    // the actions (a backend-config save) that would run a second teardown
    // against the same session.
    @Default(false) bool isRevoking,
    @Default([]) List<SpPayment> history,
    @Default([]) List<SpCoin> coins,
    BitcoinNetwork? network,
    @Default(false) bool backendOnline,

    // Scan progress
    @Default(false) bool isScanning,
    // Which phase the current scan is in (receive then spend); null when idle.
    SpScanPhase? scanPhase,
    // Start of the current scan (for the live elapsed timer); null when idle.
    DateTime? scanStartTime,
    // Estimated seconds remaining (null until the estimator warms up).
    int? scanEtaSecs,
    // Total duration of the just-finished scan; shown on the post-scan view.
    int? scanLastDurationSecs,
    int? lastScannedHeight,
    int? scanFrom,
    int? scanTo,
    int? scanCurrent,
    // Chain tip + earliest scannable height; bound the start-height chooser.
    int? chainTip,
    int? minBirthdayHeight,
    // Whether the wallet may resume scanning without being asked.
    @Default(true) bool isAutoScanEnabled,
    @Default(SpHeaderValidationStatus.idle)
    SpHeaderValidationStatus headerValidationStatus,
    SpHeaderValidationPhase? headerValidationPhase,
    int? headerValidationFrom,
    int? headerValidationTo,
    int? headerValidationCurrent,
  }) = _SpState;
  const SpState._();

  Sats get totalBalance => balance?.totalUnifiedSat ?? Sats.zero;

  double get scanProgress =>
      // A phase's current can briefly sit outside [from, to] at a transition,
      // so the shared helper clamps.
      blockRangeProgress(from: scanFrom, current: scanCurrent, to: scanTo);

  /// True once a scan has recorded progress; the chooser is only offered before
  /// the first scan.
  bool get hasScannedBefore => lastScannedHeight != null;

  /// Height the next resume scan would begin at (last scanned + 1).
  int? get nextScanStart {
    final last = lastScannedHeight;
    return last == null ? null : last + 1;
  }

  /// True when the wallet is behind and nothing will catch it up without the
  /// user, so the screens show a nudge.
  bool get needsScanNudge => !isScanning && _scanPolicy.needsUser;

  SpScanPolicy get _scanPolicy => SpScanPolicy(
    lastScannedHeight: lastScannedHeight,
    chainTip: chainTip,
    isAutoScanEnabled: isAutoScanEnabled,
  );

  /// True when the next scan would start past the tip (nothing left to scan).
  bool get isCaughtUp {
    final next = nextScanStart;
    final tip = chainTip;
    return next != null && tip != null && next > tip;
  }

  /// History grouped by day, newest day first and newest payment first inside
  /// each day, keyed by the day's epoch milliseconds.
  Map<int, List<SpPayment>> get historyByDay {
    final grouped = <int, List<SpPayment>>{};

    for (final payment in history) {
      final timestamp = payment.timestamp;
      // An unconfirmed payment has no day yet, so it goes in a bucket that
      // always sorts above every real day.
      final day = timestamp == null
          ? _pendingDayKey
          : _dayStart(_paymentDate(timestamp));
      grouped.putIfAbsent(day, () => []).add(payment);
    }

    for (final payments in grouped.values) {
      payments.sort((a, b) => _sortDate(b).compareTo(_sortDate(a)));
    }

    final sorted = SplayTreeMap<int, List<SpPayment>>.from(
      grouped,
      (a, b) => b.compareTo(a),
    );
    return LinkedHashMap<int, List<SpPayment>>.from(sorted);
  }

  DateTime _sortDate(SpPayment payment) => payment.timestamp == null
      ? DateTime.fromMillisecondsSinceEpoch(0)
      : _paymentDate(payment.timestamp!);

  int _dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;

  DateTime _paymentDate(BigInt timestamp) =>
      DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * _millisPerSecond);

  double get headerValidationProgress => blockRangeProgress(
    from: headerValidationFrom,
    current: headerValidationCurrent,
    to: headerValidationTo,
  );
}

/// Max milliseconds value for [DateTime], the bucket key pending payments get
/// so they sort above every real day.
const int _pendingDayKey = 8640000000000000;

const int _millisPerSecond = 1000;

/// Fraction of an inclusive block range `[from, to]` that `current` covers.
///
/// Inclusive on purpose: reaching the first block of a range is progress, so a
/// just-started scan reads above zero rather than sitting at 0% until the
/// second block. Returns 0 when the range is unknown or empty, and clamps, so a
/// `current` that briefly steps outside the range at a phase transition can
/// never render a negative or past-100% bar.
double blockRangeProgress({
  required int? from,
  required int? current,
  required int? to,
}) {
  if (from == null || to == null || to < from) return 0;
  // Inclusive, so a single-block range is 1 and never divides by zero.
  final total = to - from + 1;
  final done = (current ?? from) - from + 1;
  return (done / total).clamp(0.0, 1.0);
}
