import 'dart:math' show pow;

import 'package:bb_mobile/core_deprecated/exchange/data/models/rate_model.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/entity/rate.dart';

class RateHistoryModel {
  final String fromCurrency;
  final String toCurrency;
  final String interval;
  final int precision;
  final List<RateModel> rates;

  RateHistoryModel({
    required this.fromCurrency,
    required this.toCurrency,
    required this.interval,
    required this.precision,
    required this.rates,
  });

  factory RateHistoryModel.fromJson(Map<String, dynamic> json) {
    final intervalStr = json['interval'] as String? ?? 'week';
    final precision = json['precision'] as int? ?? 2;
    final fromCurrency = json['fromCurrency'] as String? ?? 'BTC';
    final toCurrency = json['toCurrency'] as String? ?? 'CAD';

    final elements = json['elements'] as List<dynamic>?;

    if (elements == null || elements.isEmpty) {
      return RateHistoryModel(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        interval: intervalStr,
        precision: precision,
        rates: [],
      );
    }

    try {
      final precisionDivisor = pow(10, precision).toDouble();

      final parsedRates = elements.map((e) {
        try {
          final data = e as Map<String, dynamic>;

          final periodStart = data['periodStart'] as String?;
          final createdAt = data['createdAt'] as String?;
          final dateStr = periodStart ?? createdAt;

          if (dateStr == null) {
            throw Exception('Missing periodStart or createdAt in rate data');
          }

          final indexPriceInt = data['indexPrice'] as int?;
          final indexPriceDouble = data['indexPrice'] as double?;
          final indexPrice = indexPriceInt != null
              ? indexPriceInt / precisionDivisor
              : indexPriceDouble;

          return RateModel(
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
            interval: intervalStr,
            createdAt: dateStr,
            marketPrice: null,
            price: null,
            priceCurrency: null,
            precision: precision,
            indexPrice: indexPrice,
            userPrice: null,
          );
        } catch (e) {
          rethrow;
        }
      }).toList();

      return RateHistoryModel(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        interval: intervalStr,
        precision: precision,
        rates: parsedRates,
      );
    } catch (e) {
      return RateHistoryModel(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        interval: intervalStr,
        precision: precision,
        rates: [],
      );
    }
  }

  List<Rate> toEntityList() {
    return rates.map((rateModel) => rateModel.toEntity()).toList();
  }
}
