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

  factory Currency.fromJson(Map<String, dynamic> json) =>
      _$CurrencyFromJson(json);
  const Currency._();

  static int get satsInBtc => 100000000;
  static int get btcDecimalPoints => 8;
  static int get fiatDecimalPoints => 2;

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
      case 'inr':
        return '₹';
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
      case 'INR':
        return 'Indian Rupee';
      default:
        return '';
    }
  }
}
