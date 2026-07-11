import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sp_state.freezed.dart';

/// The two phases of an SP scan, reported separately by bwk: the receive
/// (output) scan, then the spend (input) sweep.
enum SpScanPhase { receive, spend }

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
    @Default([]) List<SpPayment> history,
    @Default([]) List<SpCoin> coins,
    SpNetwork? network,
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

    // Receive tab (persists across navigation)
    @Default(0) int receiveTabIndex,
  }) = _SpState;
  const SpState._();

  BigInt get totalBalance => balance?.totalUnifiedSat ?? BigInt.zero;

  double get scanProgress {
    final from = scanFrom;
    final current = scanCurrent;
    final to = scanTo;
    if (from == null || to == null || to <= from) return 0.0;
    // Clamp: a phase's current can briefly sit outside [from, to] at a
    // transition, which must never render a negative or >100% bar.
    return (((current ?? from) - from) / (to - from)).clamp(0.0, 1.0);
  }

  /// True once a scan has recorded progress; the chooser is only offered before
  /// the first scan.
  bool get hasScannedBefore => lastScannedHeight != null;

  /// Height the next resume scan would begin at (last scanned + 1).
  int? get nextScanStart {
    final last = lastScannedHeight;
    return last == null ? null : last + 1;
  }

  /// True when the next scan would start past the tip (nothing left to scan).
  bool get isCaughtUp {
    final next = nextScanStart;
    final tip = chainTip;
    return next != null && tip != null && next > tip;
  }
}
