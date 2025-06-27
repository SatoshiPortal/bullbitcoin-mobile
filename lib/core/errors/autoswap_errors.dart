import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';

class MinimumAmountThresholdException implements Exception {
  final int minimumThresholdSats;
  final BitcoinUnit bitcoinUnit;

  MinimumAmountThresholdException(this.minimumThresholdSats, this.bitcoinUnit);

  String displayMessage() {
    if (bitcoinUnit == BitcoinUnit.btc) {
      final btcAmount = ConvertAmount.satsToBtc(minimumThresholdSats);
      return 'Minimum balance threshold is $btcAmount BTC';
    }
    return 'Minimum balance threshold is $minimumThresholdSats sats';
  }
}

class MaximumFeeThresholdException implements Exception {
  final int maximumThreshold;

  MaximumFeeThresholdException(this.maximumThreshold);

  String displayMessage() => 'Maximum fee threshold is $maximumThreshold%';
}

class AutoSwapProcessException implements Exception {
  final String message;
  final Object? error;

  AutoSwapProcessException(this.message, {this.error});

  @override
  String toString() => error != null ? '$message: $error' : message;
}

class FeeBlockException implements Exception {
  final double currentFeePercent;
  final double thresholdPercent;

  FeeBlockException({
    required this.currentFeePercent,
    required this.thresholdPercent,
  });

  @override
  String toString() {
    return 'Fee threshold exceeded: current ${currentFeePercent.toStringAsFixed(2)}%, limit ${thresholdPercent.toStringAsFixed(2)}%';
  }
}

class BalanceThresholdException implements Exception {
  final int currentBalance;
  final int requiredBalance;

  BalanceThresholdException({
    required this.currentBalance,
    required this.requiredBalance,
  });

  @override
  String toString() {
    return 'Balance threshold not exceeded: current $currentBalance sats, required $requiredBalance sats';
  }
}

class AutoSwapDisabledException implements Exception {
  final String message;

  AutoSwapDisabledException(this.message);

  @override
  String toString() => message;
}
