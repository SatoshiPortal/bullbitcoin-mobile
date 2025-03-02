import 'package:bb_mobile/core/data/datasources/exchange_data_source.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/repositories/bitcoin_price_repository.dart';
import 'package:decimal/decimal.dart';

class BitcoinPriceRepositoryImpl implements BitcoinPriceRepository {
  final ExchangeDataSource _exchange;

  BitcoinPriceRepositoryImpl({
    required ExchangeDataSource exchange,
  }) : _exchange = exchange;

  @override
  Future<List<String>> getAvailableCurrencies() {
    return _exchange.getAvailableCurrencies();
  }

  @override
  Future<Decimal> getBitcoinPrice(String currencyCode) {
    return _exchange.getBitcoinPrice(currencyCode);
  }
}
