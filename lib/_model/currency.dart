import 'package:freezed_annotation/freezed_annotation.dart';

part 'currency.freezed.dart';
part 'currency.g.dart';

@freezed
class Currency with _$Currency {
  const factory Currency({
    required String name,
    required double? price,
    required String shortName,
  }) = _Currency;
  const Currency._();

  factory Currency.fromJson(Map<String, dynamic> json) =>
      _$CurrencyFromJson(json);

  String getSymbol() {
    switch (name) {
      case 'usd':
        return '\$';
      case 'cad':
        return '\$';
      case 'crc':
        return '₡';
      case 'eur':
        return '€';
      default:
        return '';
    }
  }

  String getFullName() {
    switch (name) {
      case 'USD':
        return 'US Dollar';
      case 'CAD':
        return 'Canadian Dollar';
      case 'CRC':
        return 'Costa Rican Colón';
      case 'EUR':
        return 'Euro';
      default:
        return '';
    }
  }
}
