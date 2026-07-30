import 'package:freezed_annotation/freezed_annotation.dart';

part 'auto_swap.freezed.dart';
part 'auto_swap.g.dart';

/// Which rule a set of auto swap settings breaks, in the order they are
/// checked. Callers map this to whatever they show the user.
enum AutoSwapSettingsViolation {
  recipientWalletMissing,
  balanceThresholdTooLow,
  triggerBalanceTooLow,
  feeThresholdTooHigh,
}

@freezed
sealed class AutoSwap with _$AutoSwap {
  const factory AutoSwap({
    @Default(true) bool enabled,
    @Default(1000000) int balanceThresholdSats,
    @Default(2000000) int triggerBalanceSats,
    @Default(3.0) double feeThresholdPercent,
    @Default(false) bool blockTillNextExecution,
    @Default(false) bool alwaysBlock,
    @Default(null) String? recipientWalletId,
    @Default(true) bool showWarning,
  }) = _AutoSwap;

  const AutoSwap._();

  factory AutoSwap.fromJson(Map<String, dynamic> json) =>
      _$AutoSwapFromJson(json);

  /// Below this a swap would move less than it costs in fees.
  static const int minimumBalanceThresholdSats = 50000;

  /// Accepting a fee ceiling above this is almost certainly a mistake.
  static const int maximumFeeThresholdPercent = 10;

  /// Applied when a fee ceiling cannot be determined.
  static const double defaultFeeThresholdPercent = 3.0;

  static bool isBalanceThresholdTooLow(int balanceThresholdSats) =>
      balanceThresholdSats < minimumBalanceThresholdSats;

  /// A swap has to leave the wallet at its target, so the trigger must be at
  /// least twice the target — otherwise a swap would fire and immediately
  /// leave the balance below where it started.
  static bool isTriggerBalanceTooLow({
    required int balanceThresholdSats,
    required int triggerBalanceSats,
  }) => triggerBalanceSats < 2 * balanceThresholdSats;

  static bool isFeeThresholdTooHigh(double feeThresholdPercent) =>
      feeThresholdPercent > maximumFeeThresholdPercent;

  /// The first rule these settings break, or null when they are acceptable.
  ///
  /// Deliberately not enforced in the constructor: these settings are
  /// persisted and deserialized, so a row written by an older version must
  /// still load even if it would no longer be accepted.
  AutoSwapSettingsViolation? get violation {
    // Only required while enabled: switching auto swap off needs no recipient.
    if (enabled && recipientWalletId == null) {
      return AutoSwapSettingsViolation.recipientWalletMissing;
    }
    if (isBalanceThresholdTooLow(balanceThresholdSats)) {
      return AutoSwapSettingsViolation.balanceThresholdTooLow;
    }
    if (isTriggerBalanceTooLow(
      balanceThresholdSats: balanceThresholdSats,
      triggerBalanceSats: triggerBalanceSats,
    )) {
      return AutoSwapSettingsViolation.triggerBalanceTooLow;
    }
    if (isFeeThresholdTooHigh(feeThresholdPercent)) {
      return AutoSwapSettingsViolation.feeThresholdTooHigh;
    }
    return null;
  }

  bool passedRequiredBalance(int balanceSat) {
    return balanceSat >= triggerBalanceSats && enabled;
  }

  bool withinFeeThreshold(double currentFeeRatio) {
    return feeThresholdPercent >= currentFeeRatio;
  }

  int swapAmount(int balanceSat) {
    return balanceSat - balanceThresholdSats;
  }
}
