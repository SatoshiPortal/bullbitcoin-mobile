import 'dart:math' show pow;

import 'package:bb_mobile/core/exchange/data/models/rate_history_request_model.dart';
import 'package:bb_mobile/core/exchange/data/models/rate_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/rate.dart';
import 'package:dio/dio.dart';

abstract class PriceRemoteDatasource {
  Future<List<RateModel>> getPriceHistory({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    DateTime? fromDate,
    DateTime? toDate,
  });
}

class BullbitcoinPriceRemoteDatasource implements PriceRemoteDatasource {
  final Dio _http;
  final _pricePath = '/public/price';

  BullbitcoinPriceRemoteDatasource({required Dio bullbitcoinApiHttpClient})
    : _http = bullbitcoinApiHttpClient;

  @override
  Future<List<RateModel>> getPriceHistory({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final requestModel = RateHistoryRequestModel(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        interval: interval.enumValue,
        fromDate: fromDate,
        toDate: toDate,
      );

      final requestParams = requestModel.toApiParams();

      final resp = await _http.post(
        _pricePath,
        data: {
          'id': 1,
          'jsonrpc': '2.0',
          'method': 'getIndexRateHistory',
          'params': requestParams,
        },
      );

      if (resp.statusCode == null ||
          resp.statusCode == null ||
          resp.statusCode != 200) {
        return [];
      }

      final data = resp.data as Map<String, dynamic>;

      if (data.containsKey('error')) {
        return [];
      }

      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) {
        return [];
      }

      final element = result['element'] as Map<String, dynamic>?;
      if (element == null) {
        return [];
      }

      final intervalStr = element['interval'] as String? ?? 'week';
      final precision = element['precision'] as int? ?? 2;
      final fromCurrencyValue =
          element['fromCurrency'] as String? ?? fromCurrency;
      final toCurrencyValue = element['toCurrency'] as String? ?? toCurrency;

      final ratesList = element['rates'] as List<dynamic>?;
      if (ratesList == null || ratesList.isEmpty) {
        return [];
      }

      final precisionDivisor = pow(10, precision).toDouble();

      final models = <RateModel>[];
      for (var i = 0; i < ratesList.length; i++) {
        try {
          final rateItem = ratesList[i];
          final rateData = rateItem as Map<String, dynamic>;

          final periodStart = rateData['periodStart'] as String?;
          final createdAt = rateData['createdAt'] as String?;
          final dateStr = periodStart ?? createdAt;

          if (dateStr == null) {
            continue;
          }

          final indexPriceValue = rateData['indexPrice'];
          final indexPriceInt = indexPriceValue is int ? indexPriceValue : null;
          final indexPriceDouble = indexPriceValue is double
              ? indexPriceValue
              : null;
          final indexPrice = indexPriceInt != null
              ? indexPriceInt / precisionDivisor
              : indexPriceDouble;

          final model = RateModel(
            fromCurrency: fromCurrencyValue,
            toCurrency: toCurrencyValue,
            interval: intervalStr,
            createdAt: dateStr,
            marketPrice: null,
            price: null,
            priceCurrency: null,
            precision: precision,
            indexPrice: indexPrice,
            userPrice: null,
          );

          models.add(model);
        } catch (e) {
          continue;
        }
      }

      return models;
    } catch (e) {
      return [];
    }
  }
}
