import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/json.dart';
import 'package:meta/meta.dart';

/// The user's exchange rate as `public/price` returns it. Prices are integers
/// in units of 10^-[precision] of the quote currency.
@immutable
class UserRate {
  final String? fromCurrency;
  final num indexPrice;
  final num userPrice;
  final int? precision;

  const UserRate({
    this.fromCurrency,
    required this.indexPrice,
    required this.userPrice,
    this.precision,
  });

  /// Throws a [BbxApiFormatException] naming the first invalid field.
  factory UserRate.fromJson(Map<String, dynamic> json) => UserRate(
    fromCurrency: read<String?>(json['fromCurrency'], 'fromCurrency'),
    indexPrice: read<num>(json['indexPrice'], 'indexPrice'),
    userPrice: read<num>(json['userPrice'], 'userPrice'),
    precision: read<int?>(json['precision'], 'precision'),
  );
}
