import 'package:bb_mobile/core_deprecated/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/repositories/exchange_rate_repository.dart';

class ExchangeRateRepositoryImpl implements ExchangeRateRepository {
  final BitcoinPriceDatasource _bitcoinPrice;

  ExchangeRateRepositoryImpl({
    required BitcoinPriceDatasource bitcoinPriceDatasource,
  }) : _bitcoinPrice = bitcoinPriceDatasource;

  @override
  Future<List<String>> get availableCurrencies =>
      _bitcoinPrice.availableCurrencies;

  @override
  Future<double> getCurrencyValue({
    required BigInt amountSat,
    required String currency,
  }) async {
    final price = await _bitcoinPrice.getPrice(currency);
    final amountBtc = amountSat / BigInt.from(100000000);
    return amountBtc * price;
  }

  @override
  Future<BigInt> getSatsValue({
    required double amountFiat,
    required String currency,
  }) async {
    final price = await _bitcoinPrice.getPrice(currency);
    final amountBtc = amountFiat / price;
    return BigInt.from((amountBtc * 100000000).truncate());
  }
}
