import 'package:bb_mobile/core/price/data/datasources/bullbitcoin_price_datasource.dart';
import 'package:bb_mobile/core/price/domain/repositories/bitcoin_price_repository.dart';
import 'package:clock/clock.dart';

class BitcoinPriceRepositoryImpl implements BitcoinPriceRepository {
  /// The pricer serves every user: per currency, this app asks it at most once
  /// a minute, whatever the number of screens and use cases reading the price,
  /// and whether the attempt succeeded or not.
  static const priceMaxAge = Duration(seconds: 60);

  /// What the datasource reports when the pricer cannot give a rate, and what
  /// a read gets while the last attempt is a recent failure. Never a lapsed
  /// rate: an old price shown as current is worse than no price.
  static const _unavailable = 0.0;

  final BullbitcoinPriceDatasource _bullbitcoinPrice;
  final Map<String, ({double rate, DateTime fetchedAt})> _prices = {};
  final Map<String, DateTime> _failedAt = {};
  final Map<String, Future<double>> _pricesInFlight = {};

  BitcoinPriceRepositoryImpl({
    required BullbitcoinPriceDatasource bullbitcoinPriceDatasource,
  }) : _bullbitcoinPrice = bullbitcoinPriceDatasource;

  /// The BTC price in [currency], from the last minute's successful fetch
  /// when there is one. Reads arriving while a fetch is out share it. Within a
  /// minute of a failed fetch, reads fail too, without asking the pricer.
  Future<double> _price(String currency) {
    final key = currency.toUpperCase();
    final now = clock.now();
    final cached = _prices[key];
    if (cached != null && now.difference(cached.fetchedAt) < priceMaxAge) {
      return Future.value(cached.rate);
    }
    final failedAt = _failedAt[key];
    if (failedAt != null && now.difference(failedAt) < priceMaxAge) {
      return Future.value(_unavailable);
    }
    return _pricesInFlight[key] ??= _fetchPrice(key);
  }

  Future<double> _fetchPrice(String key) async {
    try {
      final rate = await _bullbitcoinPrice.getPrice(key);
      if (rate.isFinite && rate > 0) {
        _prices[key] = (rate: rate, fetchedAt: clock.now());
        _failedAt.remove(key);
      } else {
        _prices.remove(key);
        _failedAt[key] = clock.now();
      }
      return rate;
    } catch (_) {
      _prices.remove(key);
      _failedAt[key] = clock.now();
      rethrow;
    } finally {
      _pricesInFlight.remove(key);
    }
  }

  @override
  Future<List<String>> get availableCurrencies =>
      _bullbitcoinPrice.availableCurrencies;

  @override
  Future<double> getCurrencyValue({
    required BigInt amountSat,
    required String currency,
  }) async {
    final price = await _price(currency);
    final amountBtc = amountSat / BigInt.from(100000000);
    return amountBtc * price;
  }

  @override
  Future<BigInt> getSatsValue({
    required double amountFiat,
    required String currency,
  }) async {
    final price = await _price(currency);
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
    final btcInFrom = await _price(fromCurrency);
    final btcInTo = await _price(toCurrency);

    // Convert: targetValue = sourceValue * (btcPriceInTarget / btcPriceInSource)
    return amount * (btcInTo / btcInFrom);
  }
}
