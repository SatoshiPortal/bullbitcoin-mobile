import 'package:decimal/decimal.dart';

abstract class FiatCurrenciesRepository {
  Future<List<String>> getAvailableCurrencies();
  Future<Decimal> getBitcoinPrice(String currencyCode);
  Future<void> setCurrency(String currencyCode);
  Future<String> getCurrency();
}
