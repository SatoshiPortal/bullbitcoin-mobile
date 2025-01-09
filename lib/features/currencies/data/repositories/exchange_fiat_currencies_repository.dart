import 'package:bb_mobile/core/datasources/exchange_data_source.dart';
import 'package:bb_mobile/core/models/fiat_currency_model.dart';
import 'package:bb_mobile/features/currencies/domain/repositories/fiat_currencies_repository.dart';
import 'package:decimal/decimal.dart';

class ExchangeFiatCurrenciesRepository implements FiatCurrenciesRepository {
  final ExchangeDataSource _exchangeDataSource;

  ExchangeFiatCurrenciesRepository(this._exchangeDataSource);

  @override
  Future<List<FiatCurrencyModel>> getAvailableCurrencies() {
    return _exchangeDataSource.getAvailableCurrencies();
  }

  @override
  Future<Decimal> getBitcoinPrice(String currencyCode) {
    return _exchangeDataSource.getBitcoinPrice(currencyCode);
  }
}
