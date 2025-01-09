import 'package:bb_mobile/core/models/fiat_currency_model.dart';
import 'package:decimal/decimal.dart';

abstract class FiatCurrenciesRepository {
  Future<List<FiatCurrencyModel>> getAvailableCurrencies();
  Future<Decimal> getBitcoinPrice(String currencyCode);
}
