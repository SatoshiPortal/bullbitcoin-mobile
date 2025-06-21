import 'package:freezed_annotation/freezed_annotation.dart';

part 'auto_swap.freezed.dart';
part 'auto_swap.g.dart';

@freezed
sealed class AutoSwap with _$AutoSwap {
  const factory AutoSwap({
    @Default(false) bool enabled,
    @Default(1000000) int amountThresholdSats,
    @Default(3) int feeThreshold,
  }) = _AutoSwap;

  const AutoSwap._();

  factory AutoSwap.fromJson(Map<String, dynamic> json) =>
      _$AutoSwapFromJson(json);

  bool amountThresholdExceeded(int balanceSat) {
    return balanceSat >= amountThresholdSats * 2 && enabled;
  }

  bool withinFeeThreshold(double currentFeeRatio) {
    return feeThreshold.toDouble() >= currentFeeRatio;
  }

  int swapAmount(int balanceSat) {
    return balanceSat - amountThresholdSats;
  }
}
