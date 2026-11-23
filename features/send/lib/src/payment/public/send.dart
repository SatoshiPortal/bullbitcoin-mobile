import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import '../domain/send_failure.dart';
import '../domain/usecases/get_send_amount_quotes_usecase.dart';
import '../domain/usecases/get_send_exchange_rate_usecase.dart';

/// Fiat quotes for the send journey on the configured network.
abstract interface class Send {
  factory Send.open({
    required Preferences preferences,
    IndexPriceReader readPrice = Pricer.getIndexPrice,
    IndexPricesReader readPrices = Pricer.getIndexPrices,
  }) => _Send(
    GetSendExchangeRateUsecase(
      getSettingsUsecase: preferences,
      getIndexPrice: readPrice,
    ),
    GetSendAmountQuotesUsecase(settings: preferences, read: readPrices),
  );

  @useResult
  Future<Result<double, SendFailure>> exchangeRate({String? currencyCode});

  @useResult
  Future<Result<Map<SupportedCurrency, BitcoinPrice>, SendFailure>>
  amountQuotes();
}

final class _Send implements Send {
  final GetSendExchangeRateUsecase _exchangeRate;
  final GetSendAmountQuotesUsecase _amountQuotes;

  const _Send(this._exchangeRate, this._amountQuotes);

  @override
  Future<Result<double, SendFailure>> exchangeRate({String? currencyCode}) =>
      _exchangeRate.execute(currencyCode: currencyCode);

  @override
  Future<Result<Map<SupportedCurrency, BitcoinPrice>, SendFailure>>
  amountQuotes() => _amountQuotes.execute();
}
