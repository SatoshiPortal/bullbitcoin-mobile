import 'package:bb_mobile/core/data/datasources/exchange_data_source.dart';
import 'package:bb_mobile/core/data/datasources/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/data/models/fiat_currency_model.dart';
import 'package:bb_mobile/features/fiat_currencies/domain/repositories/fiat_currencies_repository.dart';
import 'package:decimal/decimal.dart';

class FiatCurrenciesRepositoryImpl implements FiatCurrenciesRepository {
  static const _key = 'currency';
  static const _defaultCurrency = 'USD';

  final ExchangeDataSource _exchange;
  final KeyValueStorageDataSource<String> _storage;

  FiatCurrenciesRepositoryImpl({
    required ExchangeDataSource exchange,
    required KeyValueStorageDataSource<String> storage,
  })  : _exchange = exchange,
        _storage = storage;

  @override
  Future<List<FiatCurrencyModel>> getAvailableCurrencies() {
    return _exchange.getAvailableCurrencies();
  }

  @override
  Future<Decimal> getBitcoinPrice(String currencyCode) {
    return _exchange.getBitcoinPrice(currencyCode);
  }

  @override
  Future<void> setCurrency(String currencyCode) async {
    return _storage.saveValue(key: _key, value: currencyCode);
  }

  @override
  Future<String> getCurrency() async {
    final currency = await _storage.getValue(_key) ?? _defaultCurrency;
    return currency;
  }
}
