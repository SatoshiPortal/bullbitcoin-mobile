import 'dart:async';

import 'package:bull_pricer/src/data/models/price_model.dart';
import 'package:bull_pricer/src/data/models/price_response_model.dart';
import 'package:bull_pricer/src/data/datasources/pricer_cache_datasource.dart';
import 'package:bull_pricer/src/data/datasources/pricer_api_datasource.dart';
import 'package:bull_pricer/src/domain/entities/bitcoin_price.dart';
import 'package:bull_pricer/src/domain/entities/supported_currency.dart';
import 'package:bull_pricer/src/domain/pricer_failure.dart';
import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

typedef _PriceKey = (BitcoinNetwork, SupportedCurrency);

final class PricerRepository {
  static const _maxAge = Duration(seconds: 60);

  final PricerApiDatasource _pricerApiDatasource = const PricerApiDatasource();
  final PricerCacheDatasource _pricerCacheDatasource;
  final Map<_PriceKey, Future<Result<BitcoinPrice, PricerFailure>>> _lookups =
      {};

  PricerRepository({required this._pricerCacheDatasource});

  @useResult
  Future<Result<BitcoinPrice, PricerFailure>> indexPrice({
    required BitcoinNetwork network,
    required SupportedCurrency currency,
  }) {
    return _price(
      network: network,
      currency: currency,
      request: () => _pricerApiDatasource.indexPrice(network, currency),
    );
  }

  Future<Result<BitcoinPrice, PricerFailure>> _price({
    required BitcoinNetwork network,
    required SupportedCurrency currency,
    required Future<PriceResponseModel> Function() request,
  }) {
    final key = (network, currency);

    // Someone already asked for this price: wait for the same answer.
    final running = _lookups[key];
    if (running != null) return running;

    // First caller: start the lookup, and forget it once it has finished,
    // so the next caller checks the cache again.
    final lookup = _lookup(key, request).whenComplete(() {
      _lookups.remove(key);
    });
    _lookups[key] = lookup;
    return lookup;
  }

  Future<Result<BitcoinPrice, PricerFailure>> _lookup(
    _PriceKey key,
    Future<PriceResponseModel> Function() request,
  ) async {
    final (network, currency) = key;
    final cached = await _readCache(network, currency);
    if (cached != null && _isFresh(cached)) return Ok(cached.toEntity());
    return _fetch(key, request);
  }

  Future<Result<BitcoinPrice, PricerFailure>> _fetch(
    _PriceKey key,
    Future<PriceResponseModel> Function() request,
  ) async {
    final (network, currency) = key;
    final PriceResponseModel response;
    try {
      response = await request();
    } on PricerUnsupportedNetworkException catch (e) {
      return Err(
        PricerUnsupportedNetworkFailure(
          'No price service for ${e.network.name}',
        ),
      );
    } on DioException catch (e) {
      return Err(switch (e.response?.statusCode) {
        429 => PricerRateLimitedFailure(e.message),
        null || >= 500 => PricerNetworkFailure(e.message),
        final status => PricerUnexpectedFailure('HTTP $status'),
      });
    } on TimeoutException {
      return const Err(PricerNetworkFailure('Timed out'));
    } on FormatException catch (e) {
      return Err(PricerUnexpectedFailure(e.message));
    }

    final price = PriceModel(
      network: network,
      currency: currency,
      fiatAmount: response.indexPrice(),
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        clock.now().millisecondsSinceEpoch,
        isUtc: true,
      ),
    );

    await _writeCache(price);

    return Ok(price.toEntity());
  }

  bool _isFresh(PriceModel price) {
    final age = clock.now().difference(price.fetchedAt);
    return !age.isNegative && age < _maxAge;
  }

  Future<PriceModel?> _readCache(
    BitcoinNetwork network,
    SupportedCurrency currency,
  ) async {
    try {
      return await _pricerCacheDatasource.find(network, currency);
    } on Exception {
      return null;
    }
  }

  Future<void> _writeCache(PriceModel price) async {
    try {
      await _pricerCacheDatasource.save(price);
    } on Exception {
      // An unwritable cache only costs the next request.
    }
  }
}
