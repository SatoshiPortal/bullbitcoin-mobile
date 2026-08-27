import 'package:bb_mobile/core/errors/bull_exception.dart';

class FeeBlockException extends BullException {
  final double currentFeePercent;
  final double thresholdPercent;

  FeeBlockException({
    required this.currentFeePercent,
    required this.thresholdPercent,
  }) : super(
         'Fee threshold exceeded: current ${currentFeePercent.toStringAsFixed(2)}%, limit ${thresholdPercent.toStringAsFixed(2)}%',
       );
}

class BalanceThresholdException extends BullException {
  final int currentBalance;
  final int requiredBalance;

  BalanceThresholdException({
    required this.currentBalance,
    required this.requiredBalance,
  }) : super(
         'Balance threshold not exceeded: current $currentBalance sats, required $requiredBalance sats',
       );
}

class AutoSwapDisabledException extends BullException {
  AutoSwapDisabledException(super.message);
}
