import 'dart:math' show pow;

import 'package:bb_mobile/core/exchange/domain/entity/rate.dart';

class RateHistoryModel {
  final List<Rate> elements;

  RateHistoryModel({required this.elements});

  factory RateHistoryModel.fromJson(Map<String, dynamic> json) {
    final rates = json['rates'] as List<dynamic>?;

    if (rates == null || rates.isEmpty) {
      return RateHistoryModel(elements: []);
    }

    try {
      final intervalStr = json['interval'] as String?;
      final precision = json['precision'] as int? ?? 2;
      final fromCurrency = json['fromCurrency'] as String? ?? 'BTC';
      final toCurrency = json['toCurrency'] as String? ?? 'CAD';

      final precisionDivisor = pow(10, precision).toDouble();

      final parsedRates =
          rates.map((e) {
            try {
              final data = e as Map<String, dynamic>;

              final periodStart = data['periodStart'] as String?;
              final createdAt = data['createdAt'] as String?;
              final dateStr = periodStart ?? createdAt;

              if (dateStr == null) {
                throw Exception(
                  'Missing periodStart or createdAt in rate data',
                );
              }

              final indexPriceInt = data['indexPrice'] as int?;
              final indexPrice =
                  indexPriceInt != null
                      ? indexPriceInt / precisionDivisor
                      : null;

              final rate = Rate(
                fromCurrency: fromCurrency,
                toCurrency: toCurrency,
                interval: RateTimelineInterval.fromValue(intervalStr ?? 'week'),
                createdAt: DateTime.parse(dateStr),
                marketPrice: null,
                price: null,
                priceCurrency: null,
                precision: precision,
                indexPrice: indexPrice,
                userPrice: null,
              );

              return rate;
            } catch (e) {
              rethrow;
            }
          }).toList();

      return RateHistoryModel(elements: parsedRates);
    } catch (e) {
      return RateHistoryModel(elements: []);
    }
  }
}
