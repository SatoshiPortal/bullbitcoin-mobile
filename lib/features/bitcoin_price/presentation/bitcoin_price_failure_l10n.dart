import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/bitcoin_price_failure.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter/widgets.dart';

extension PricerFailureL10n on PricerFailure {
  String toTranslated(BuildContext context) => switch (this) {
    PricerNetworkFailure() ||
    PricerRateLimitedFailure() ||
    PricerUnsupportedNetworkFailure() =>
      context.loc.bitcoinPriceExchangeRateUnavailable,
    PricerUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}

extension PriceChartFailureL10n on PriceChartFailure {
  String toTranslated(BuildContext context) => switch (this) {
    PriceChartLoadFailure() => context.loc.priceChartLoadFailed,
    PriceChartUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
