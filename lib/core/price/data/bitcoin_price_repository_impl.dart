import 'package:bb_mobile/core/price/data/datasources/bullbitcoin_price_datasource.dart';
import 'package:bb_mobile/core/price/domain/repositories/bitcoin_price_repository.dart';

class BitcoinPriceRepositoryImpl implements BitcoinPriceRepository {
  final BullbitcoinPriceDatasource _bullbitcoinPrice;

  BitcoinPriceRepositoryImpl({
    required BullbitcoinPriceDatasource bullbitcoinPriceDatasource,
  }) : _bullbitcoinPrice = bullbitcoinPriceDatasource;

  @override
  Future<List<String>> get availableCurrencies =>
      _bullbitcoinPrice.availableCurrencies;

  @override
  Future<double> getCurrencyValue({
    required BigInt amountSat,
    required String currency,
  }) async {
    final price = await _bullbitcoinPrice.getPrice(currency);
    final amountBtc = amountSat / BigInt.from(100000000);
    return amountBtc * price;
  }

  @override
  Future<BigInt> getSatsValue({
    required double amountFiat,
    required String currency,
  }) async {
    final price = await _bullbitcoinPrice.getPrice(currency);
    final amountBtc = amountFiat / price;
    return BigInt.from((amountBtc * 100000000).truncate());
  }

  // NOTE: not used anywhere as of now
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
    final btcInFrom = await _bullbitcoinPrice.getPrice(fromCurrency);
    final btcInTo = await _bullbitcoinPrice.getPrice(toCurrency);

    // Convert: targetValue = sourceValue * (btcPriceInTarget / btcPriceInSource)
    return amount * (btcInTo / btcInFrom);
  }
}
