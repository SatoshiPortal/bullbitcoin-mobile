import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';

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

  @override
  Future<double> convertFiatToFiat({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    // No conversion needed if same currency
    if (fromCurrency == toCurrency) return amount;

    // Skip API calls for zero amounts
    if (amount == 0) return 0;

    // Get BTC prices in both currencies
    final btcInFrom = await _bitcoinPrice.getPrice(fromCurrency);
    final btcInTo = await _bitcoinPrice.getPrice(toCurrency);

    // Convert: targetValue = sourceValue * (btcPriceInTarget / btcPriceInSource)
    return amount * (btcInTo / btcInFrom);
  }
}
