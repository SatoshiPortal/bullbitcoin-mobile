import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/bitcoin_price_failure.dart';
import 'package:flutter/widgets.dart';

extension BitcoinPriceFailureL10n on BitcoinPriceFailure {
  String toTranslated(BuildContext context) => switch (this) {
    BitcoinPriceInvalidRateFailure() =>
      context.loc.bitcoinPriceExchangeRateUnavailable,
    BitcoinPriceUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}

extension PriceChartFailureL10n on PriceChartFailure {
  String toTranslated(BuildContext context) => switch (this) {
    PriceChartLoadFailure() => context.loc.priceChartLoadFailed,
    PriceChartUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
