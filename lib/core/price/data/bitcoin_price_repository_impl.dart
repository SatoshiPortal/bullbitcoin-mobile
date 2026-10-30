import 'package:bb_mobile/core/price/domain/repositories/bitcoin_price_repository.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:primitives/primitives.dart';

typedef IndexPriceSource =
    Future<Result<BitcoinPrice, PricerFailure>> Function({
      required BitcoinNetwork network,
      required SupportedCurrency currency,
    });

class BitcoinPriceRepositoryImpl implements BitcoinPriceRepository {
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
  Future<Result<double, PricerFailure>> _price(String currency) async {
    final supportedCurrency = SupportedCurrency.tryFromCode(currency);
    if (supportedCurrency == null) {
      return Err(PricerUnexpectedFailure('Unsupported currency $currency'));
    }

    switch (await _indexPrice(network: _network, currency: supportedCurrency)) {
      case Ok(:final value):
        _fetchedAt[supportedCurrency] = value.fetchedAt;
        return Ok(value.fiatAmount);
      case Err(:final failure):
        _fetchedAt.remove(supportedCurrency);
        return Err(failure);
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
  Future<Result<double, PricerFailure>> getCurrencyValue({
    required BigInt amountSat,
    required String currency,
  }) async {
    final price = await _price(currency);
    final amountBtc = amountSat / BigInt.from(100000000);
    return price.map((price) => amountBtc * price);
  }

  @override
  Future<Result<BigInt, PricerFailure>> getSatsValue({
    required double amountFiat,
    required String currency,
  }) async {
    final price = await _price(currency);
    return price.map(
      (price) => BigInt.from((amountFiat / price * 100000000).truncate()),
    );
  }

  // NOTE: not used anywhere as of now
  @override
  Future<Result<double, PricerFailure>> convertFiatToFiat({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    // No conversion needed if same currency
    if (fromCurrency == toCurrency) return Ok(amount);

    // Skip API calls for zero amounts
    if (amount == 0) return const Ok(0);

    // Get BTC prices in both currencies
    final double btcInFrom;
    switch (await _price(fromCurrency)) {
      case Ok(:final value):
        btcInFrom = value;
      case Err(:final failure):
        return Err(failure);
    }
    final btcInTo = await _price(toCurrency);

    // Convert: targetValue = sourceValue * (btcPriceInTarget / btcPriceInSource)
    return btcInTo.map((btcInTo) => amount * (btcInTo / btcInFrom));
  }
}
