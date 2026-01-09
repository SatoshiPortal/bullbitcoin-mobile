import 'package:bb_mobile/core/exchange/domain/entity/rate.dart';

class RateModel {
  final String fromCurrency;
  final String toCurrency;
  final String interval;
  final String createdAt;
  final double? marketPrice;
  final double? price;
  final String? priceCurrency;
  final int? precision;
  final double? indexPrice;
  final double? userPrice;

  RateModel({
    required this.fromCurrency,
    required this.toCurrency,
    required this.interval,
    required this.createdAt,
    this.marketPrice,
    this.price,
    this.priceCurrency,
    this.precision,
    this.indexPrice,
    this.userPrice,
  });

  factory RateModel.fromJson(Map<String, dynamic> json) {
    final indexPriceValue = json['indexPrice'];
    final indexPrice = indexPriceValue is int
        ? indexPriceValue.toDouble()
        : indexPriceValue as double?;

    return RateModel(
      fromCurrency: json['fromCurrency'] as String? ?? 'BTC',
      toCurrency: json['toCurrency'] as String? ?? 'CAD',
      interval: json['interval'] as String? ?? 'week',
      createdAt:
          json['createdAt'] as String? ??
          json['periodStart'] as String? ??
          DateTime.now().toIso8601String(),
      marketPrice: json['marketPrice'] as double?,
      price: json['price'] as double?,
      priceCurrency: json['priceCurrency'] as String?,
      precision: json['precision'] as int?,
      indexPrice: indexPrice,
      userPrice: json['userPrice'] as double?,
    );
  }

  Rate toEntity() {
    return Rate(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      interval: RateTimelineInterval.fromValue(interval),
      createdAt: DateTime.parse(createdAt),
      marketPrice: marketPrice,
      price: price,
      priceCurrency: priceCurrency,
      precision: precision,
      indexPrice: indexPrice,
      userPrice: userPrice,
    );
  }
}
