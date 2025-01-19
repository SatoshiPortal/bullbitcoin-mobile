import 'package:bb_mobile/core/data/models/fiat_currency_model.dart';
import 'package:decimal/decimal.dart';

abstract class ExchangeDataSource {
  Future<List<FiatCurrencyModel>> getAvailableCurrencies();
  Future<Decimal> getBitcoinPrice(String currencyCode);
}
