import 'package:bitcoin_price/src/domain/bitcoin_price_failure.dart';
import 'package:bitcoin_price/src/l10n/bitcoin_price_localizations_x.dart';
import 'package:flutter/widgets.dart';

extension BitcoinPriceFailureL10n on BitcoinPriceFailure {
  String toTranslated(BuildContext context) => switch (this) {
    BitcoinPriceNetworkFailure() || BitcoinPriceRateUnavailableFailure() =>
      context.loc.bitcoinPriceExchangeRateUnavailable,
    BitcoinPricePreferencesFailure() ||
    BitcoinPriceUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
    PriceChartLoadFailure() => context.loc.priceChartLoadFailed,
  };
}
