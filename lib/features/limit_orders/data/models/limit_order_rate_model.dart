import 'dart:math';

import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_rate.dart';

final class LimitOrderRateModel {
  final String currencyCode;
  final num indexPrice;
  final num userPrice;
  final int precision;

  const LimitOrderRateModel({
    required this.currencyCode,
    required this.indexPrice,
    required this.userPrice,
    required this.precision,
  });

  factory LimitOrderRateModel.fromJson(Map<String, dynamic> json) {
    return LimitOrderRateModel(
      currencyCode: json['fromCurrency'] as String? ?? '',
      indexPrice: json['indexPrice'] as num,
      userPrice: json['userPrice'] as num,
      precision: json['precision'] as int? ?? 2,
    );
  }

  LimitOrderRate toEntity() {
    final divisor = pow(10, precision);
    return LimitOrderRate(
      currencyCode: currencyCode,
      indexPrice: indexPrice / divisor,
      userPrice: userPrice / divisor,
    );
  }
}
