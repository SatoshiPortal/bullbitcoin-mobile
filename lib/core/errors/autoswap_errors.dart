import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';

class MinimumAmountThresholdException extends BullException {
  final int minimumThresholdSats;
  final BitcoinUnit bitcoinUnit;

  MinimumAmountThresholdException(this.minimumThresholdSats, this.bitcoinUnit)
    : super(
        'Minimum balance threshold is $minimumThresholdSats ${bitcoinUnit.code}',
      );

  String displayMessage() {
    if (bitcoinUnit == BitcoinUnit.btc) {
      final btcAmount = ConvertAmount.satsToBtc(minimumThresholdSats);
      return 'Minimum balance threshold is $btcAmount BTC';
    }
    return 'Minimum balance threshold is $minimumThresholdSats sats';
  }
}

class MaximumFeeThresholdException extends BullException {
  final int maximumThreshold;

  MaximumFeeThresholdException(this.maximumThreshold)
    : super('Maximum fee threshold is $maximumThreshold%');

  String displayMessage() => 'Maximum fee threshold is $maximumThreshold%';
}

class AutoSwapProcessException extends BullException {
  final Object? error;

  AutoSwapProcessException(super.message, {this.error});

  @override
  String toString() => error != null ? '$message: $error' : message;
}

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
