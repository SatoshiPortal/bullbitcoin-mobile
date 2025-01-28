import 'package:decimal/decimal.dart';

abstract class ExchangeDataSource {
  Future<List<String>> getAvailableCurrencies();
  Future<Decimal> getBitcoinPrice(String currencyCode);
}
