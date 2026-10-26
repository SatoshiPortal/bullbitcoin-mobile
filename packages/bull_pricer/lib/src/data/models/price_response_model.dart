import 'dart:math' show pow;

/// The `element` of a price API answer.
final class PriceResponseModel {
  final num rawIndexPrice;
  final int precision;

  const PriceResponseModel({
    required this.rawIndexPrice,
    required this.precision,
  });

  factory PriceResponseModel.fromJson(Map<String, dynamic> json) {
    final indexPrice = json['indexPrice'];
    final precision = json['precision'] ?? 2;
    if (indexPrice is! num || indexPrice <= 0 || precision is! int) {
      throw FormatException('Price answer has no usable indexPrice', json);
    }
    return PriceResponseModel(rawIndexPrice: indexPrice, precision: precision);
  }

  double indexPrice() => rawIndexPrice / pow(10, precision);
}
