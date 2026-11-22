part of 'bitcoin_price_bloc.dart';

sealed class BitcoinPriceEvent {
  const BitcoinPriceEvent();
}

class BitcoinPriceStarted extends BitcoinPriceEvent {
  // A currency to use for the bitcoin price different than the one saved in the settings
  final String? currency;

  // Pass a currency if you want to use another currency than the one saved in the settings
  const BitcoinPriceStarted({this.currency});
}

class BitcoinPriceFetched extends BitcoinPriceEvent {
  final bool onlyIfUnavailable;
  final Completer<Result<void, BitcoinPriceFailure>>? completion;

  const BitcoinPriceFetched({this.onlyIfUnavailable = false, this.completion});
}

class BitcoinPriceCurrencyChanged extends BitcoinPriceEvent {
  final String currencyCode;

  final Completer<Result<void, BitcoinPriceFailure>>? completion;

  const BitcoinPriceCurrencyChanged({
    required this.currencyCode,
    this.completion,
  });
}

final class _BitcoinPriceAmountDisplayChanged extends BitcoinPriceEvent {
  final AmountDisplayPreferences? preferences;

  const _BitcoinPriceAmountDisplayChanged(this.preferences);
}
