import 'package:freezed_annotation/freezed_annotation.dart';

part 'currency_new.freezed.dart';
part 'currency_new.g.dart';

const SATS_IN_BTC = 100000000;

@freezed
class CurrencyNew with _$CurrencyNew {
  const factory CurrencyNew({
    required String name,
    required double? price,
    required String code,
    required bool isFiat,
  }) = _CurrencyNew;
  const CurrencyNew._();

  factory CurrencyNew.fromJson(Map<String, dynamic> json) =>
      _$CurrencyNewFromJson(json);
}

double calcualteSats(double price, CurrencyNew currency) {
  double sats;

  if (currency.isFiat) {
    final double oneBTCInFiat = currency.price ?? 0.0;
    final double btcValue = price / oneBTCInFiat;
    sats = btcValue * SATS_IN_BTC;
  } else {
    if (currency.code == 'BTC') {
      sats = price * SATS_IN_BTC;
    } else {
      // Should be sats
      sats = price;
    }
  }

  return sats;
}

double getFiatValueFromSats(double sats, CurrencyNew fiatCurrency) {
  final double oneBTCInFiat = fiatCurrency.price ?? 0.0;
  final double oneSatInFiat = oneBTCInFiat / SATS_IN_BTC;
  final double fiatValue = sats * oneSatInFiat;

  return fiatValue;
}

const btcCurrency =
    CurrencyNew(name: 'Bitcoin', price: 0, code: 'BTC', isFiat: false);
const satsCurrency =
    CurrencyNew(name: 'Sats', price: 0, code: 'sats', isFiat: false);
