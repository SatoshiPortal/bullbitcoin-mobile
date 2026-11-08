import 'dart:async';

import 'package:bull_pricer/src/data/models/price_model.dart';
import 'package:bull_pricer/src/data/models/price_point_model.dart';
import 'package:bull_pricer/src/data/models/price_response_model.dart';
import 'package:bull_pricer/src/data/datasources/pricer_cache_datasource.dart';
import 'package:bull_pricer/src/data/datasources/pricer_api_datasource.dart';
import 'package:bull_pricer/src/domain/entities/bitcoin_price.dart';
import 'package:bull_pricer/src/domain/entities/price_history_interval.dart';
import 'package:bull_pricer/src/domain/entities/price_point.dart';
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
    switch (await _call(request)) {
      case Ok(:final value):
        response = value;
      case Err(:final failure):
        return Err(failure);
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

  /// The price history of a chart, oldest first: the daily points of the
  /// last 90 days and those of the last 15 minutes. When one of the two is
  /// unavailable, the other alone; a failure only when neither is.
  @useResult
  Future<Result<List<PricePoint>, PricerFailure>> priceHistory({
    required BitcoinNetwork network,
    required SupportedCurrency currency,
  }) async {
    final (day, fifteenMinutes) = await (
      intervalHistory(
        network: network,
        currency: currency,
        interval: PriceHistoryInterval.day,
      ),
      intervalHistory(
        network: network,
        currency: currency,
        interval: PriceHistoryInterval.fifteenMinutes,
      ),
    ).wait;
    return switch ((day, fifteenMinutes)) {
      (Err(:final failure), Err()) => Err(failure),
      (Ok(:final value), Err()) || (Err(), Ok(:final value)) => Ok(value),
      (Ok(value: final days), Ok(value: final minutes)) => Ok(
        [...days, ...minutes]..sort((a, b) => a.time.compareTo(b.time)),
      ),
    };
  }

  /// The price history of one interval, oldest first, fetched and stored.
  /// When the fetch fails or brings no points, the stored one; a failure only
  /// when nothing is stored either. Public for the tests of each interval:
  /// [priceHistory] is the one callers use.
  @visibleForTesting
  @useResult
  Future<Result<List<PricePoint>, PricerFailure>> intervalHistory({
    required BitcoinNetwork network,
    required SupportedCurrency currency,
    required PriceHistoryInterval interval,
  }) async {
    final now = clock.now().toUtc();
    final from = now.subtract(interval.window);
    final List<PricePointModel> points;
    switch (await _call(
      () => _pricerApiDatasource.indexPriceHistory(
        network,
        currency,
        interval,
        from: from,
        to: now,
      ),
    )) {
      case Ok(:final value):
        points = [
          for (final point in value.points)
            if (!point.time.isBefore(from))
              PricePointModel(
                network: network,
                currency: currency,
                interval: interval,
                time: point.time,
                fiatAmount: point.fiatAmount,
              ),
        ];
      case Err(:final failure):
        final stored = await _readHistory(
          network,
          currency,
          interval,
          from: from,
        );
        if (stored.isEmpty) return Err(failure);
        return Ok(_entities(stored));
    }

    // An answer without points leaves the stored history as it is.
    if (points.isEmpty) {
      return Ok(
        _entities(await _readHistory(network, currency, interval, from: from)),
      );
    }

    try {
      await _pricerCacheDatasource.replaceHistory(
        network,
        currency,
        interval,
        points,
      );
    } on Exception {
      // An unwritable cache only costs the fallback on a later failure.
    }
    return Ok(_entities(points));
  }

  Future<List<PricePointModel>> _readHistory(
    BitcoinNetwork network,
    SupportedCurrency currency,
    PriceHistoryInterval interval, {
    required DateTime from,
  }) async {
    try {
      return await _pricerCacheDatasource.findHistory(
        network,
        currency,
        interval,
        from: from,
      );
    } on Exception {
      // An unreadable cache only means there is nothing to fall back on.
      return const [];
    }
  }

  List<PricePoint> _entities(List<PricePointModel> points) => [
    for (final point in points) point.toEntity(),
  ];

  Future<Result<T, PricerFailure>> _call<T>(
    Future<T> Function() request,
  ) async {
    try {
      return Ok(await request());
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
