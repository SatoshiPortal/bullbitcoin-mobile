import 'package:bb_mobile/core/exchange/data/models/rate_history_model.dart';
import 'package:bb_mobile/core/exchange/data/models/rate_history_request_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/rate.dart';
import 'package:dio/dio.dart';

abstract class PriceRemoteDatasource {
  Future<List<Rate>> getPriceHistory({
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
  Future<List<Rate>> getPriceHistory({
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

      final rateHistory = RateHistoryModel.fromJson(element);
      return rateHistory.elements;
    } catch (e) {
      return [];
    }
  }
}
