import 'package:freezed_annotation/freezed_annotation.dart';

part 'auto_swap.freezed.dart';
part 'auto_swap.g.dart';

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
