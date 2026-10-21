import 'package:bb_mobile/core/price/data/datasources/bullbitcoin_price_datasource.dart';
import 'package:bb_mobile/core/price/domain/repositories/bitcoin_price_repository.dart';
import 'package:clock/clock.dart';

class BitcoinPriceRepositoryImpl implements BitcoinPriceRepository {
  /// The pricer serves every user: while this app holds a price fetched less
  /// than a minute ago, it does not ask again for that currency, whatever the
  /// number of screens and use cases reading it.
  static const priceMaxAge = Duration(seconds: 60);

  /// A pricer that has not answered by then has failed: reads are not left
  /// waiting on it, and the next read asks again.
  static const priceTimeout = Duration(seconds: 10);

  /// What the datasource reports when the pricer cannot give a rate. A read
  /// gets it rather than a price older than [priceMaxAge]: an old price shown
  /// as current is worse than no price.
  static const _unavailable = 0.0;

  final BullbitcoinPriceDatasource _bullbitcoinPrice;

  /// Time that only moves forward. Ages are the larger of this and the wall
  /// clock, so a wall clock set back cannot keep an old price fresh, and time
  /// spent asleep, which a monotonic clock may not count, still ages it.
  final Duration Function() _monotonicElapsed;

  final Map<String, ({double rate, DateTime fetchedAt, Duration fetchedAtTick})>
  _prices = {};
  final Map<String, Future<double>> _pricesInFlight = {};

  BitcoinPriceRepositoryImpl({
    required BullbitcoinPriceDatasource bullbitcoinPriceDatasource,
    Duration Function()? monotonicElapsed,
  }) : _bullbitcoinPrice = bullbitcoinPriceDatasource,
       _monotonicElapsed = monotonicElapsed ?? _startStopwatch();

  static Duration Function() _startStopwatch() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  /// The BTC price in [currency], from a successful fetch less than a minute
  /// old when there is one. Reads arriving while a fetch is out share it; a
  /// failed fetch is not kept, so the next read asks again.
  Future<double> _price(String currency) {
    final key = currency.toUpperCase();
    final cached = _prices[key];
    if (cached != null && _isFresh(cached.fetchedAt, cached.fetchedAtTick)) {
      return Future.value(cached.rate);
    }
    _prices.remove(key);
    return _pricesInFlight[key] ??= _fetchPrice(key);
  }

  bool _isFresh(DateTime fetchedAt, Duration fetchedAtTick) {
    final wallAge = clock.now().difference(fetchedAt);
    if (wallAge.isNegative) return false;
    final tickAge = _monotonicElapsed() - fetchedAtTick;
    final age = wallAge > tickAge ? wallAge : tickAge;
    return age < priceMaxAge;
  }

  Future<double> _fetchPrice(String key) async {
    try {
      final rate = await _bullbitcoinPrice
          .getPrice(key)
          .timeout(priceTimeout, onTimeout: () => _unavailable);
      if (rate.isFinite && rate > 0) {
        _prices[key] = (
          rate: rate,
          fetchedAt: clock.now(),
          fetchedAtTick: _monotonicElapsed(),
        );
        return rate;
      }
      return _unavailable;
    } finally {
      _pricesInFlight.remove(key);
    }
  }

  @override
  DateTime? priceFetchedAt(String currency) =>
      _prices[currency.toUpperCase()]?.fetchedAt;

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
