import 'package:bb_mobile/core/price/domain/repositories/bitcoin_price_repository.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:bull_pricer/bull_pricer.dart';
import 'package:primitives/primitives.dart';

typedef IndexPriceSource =
    Future<Result<BitcoinPrice, PricerFailure>> Function({
      required BitcoinNetwork network,
      required SupportedCurrency currency,
    });

class BitcoinPriceRepositoryImpl implements BitcoinPriceRepository {
  /// What a read gets when the pricer cannot give a price: an old price shown
  /// as current is worse than no price.
  static const _unavailable = 0.0;

  final BitcoinNetwork _network;
  final IndexPriceSource _indexPrice;

  /// When the price last served for each currency was fetched, for
  /// [priceFetchedAt]. Dropped when a read fails.
  final Map<SupportedCurrency, DateTime> _fetchedAt = {};

  BitcoinPriceRepositoryImpl({
    required this._network,
    this._indexPrice = _pricerIndexPrice,
  });

  static Future<Result<BitcoinPrice, PricerFailure>> _pricerIndexPrice({
    required BitcoinNetwork network,
    required SupportedCurrency currency,
  }) => Pricer.getIndexPrice(network: network, currency: currency);

  /// The index price of one bitcoin in [currency]. The pricer caches it, so
  /// reads within a minute do not reach the API.
  Future<double> _price(String currency) async {
    final supportedCurrency = SupportedCurrency.tryFromCode(currency);
    if (supportedCurrency == null) return _unavailable;

    switch (await _indexPrice(network: _network, currency: supportedCurrency)) {
      case Ok(:final value):
        _fetchedAt[supportedCurrency] = value.fetchedAt;
        return value.fiatAmount;
      case Err(:final failure):
        _fetchedAt.remove(supportedCurrency);
        log.warning('Price unavailable: ${failure.runtimeType}');
        return _unavailable;
    }
  }

  @override
  DateTime? priceFetchedAt(String currency) {
    final supportedCurrency = SupportedCurrency.tryFromCode(currency);
    return supportedCurrency == null ? null : _fetchedAt[supportedCurrency];
  }

  @override
  Future<List<String>> get availableCurrencies async => [
    for (final currency in SupportedCurrency.values) currency.code,
  ];

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
