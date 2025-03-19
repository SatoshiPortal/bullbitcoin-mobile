import 'package:bb_mobile/_core/data/datasources/exchange_datasource.dart';
import 'package:bb_mobile/bitcoin_price/domain/repositories/bitcoin_price_repository.dart';
import 'package:decimal/decimal.dart';

class BitcoinPriceRepositoryImpl implements BitcoinPriceRepository {
  final ExchangeDatasource _exchange;

  BitcoinPriceRepositoryImpl({
    required ExchangeDatasource exchange,
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
