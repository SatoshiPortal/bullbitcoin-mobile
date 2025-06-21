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
