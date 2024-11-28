import 'package:bb_mobile/_model/currency.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'currency_new.freezed.dart';
part 'currency_new.g.dart';

@freezed
class CurrencyNew with _$CurrencyNew {
  const factory CurrencyNew({
    required String name,
    required double price,
    required String code,
    required bool isFiat,
    @Default('') String? logoPath,
  }) = _CurrencyNew;
  const CurrencyNew._();

  factory CurrencyNew.fromJson(Map<String, dynamic> json) =>
      _$CurrencyNewFromJson(json);
}

int calcualteSats(double price, CurrencyNew currency) {
  int sats;

  if (currency.isFiat) {
    final int oneBTCInSmallFiatUnit = ((currency.price) * 100).toInt();
    final int totalFiatSmallUnitsInvested = (price * 100).toInt();

    final double btcBought =
        totalFiatSmallUnitsInvested / oneBTCInSmallFiatUnit;
    sats = (btcBought * Currency.SATS_IN_BTC).toInt();
  } else {
    if (currency.code == btcCurrency.code ||
        currency.code == lbtcCurrency.code) {
      sats = (price * Currency.SATS_IN_BTC).toInt();
    } else {
      // Should be sats
      sats = price.toInt();
    }
  }

  return sats;
}

double getFiatValueFromSats(int sats, CurrencyNew fiatCurrency) {
  final double oneBTCInFiat = fiatCurrency.price;
  final double oneSatInFiat = oneBTCInFiat / Currency.SATS_IN_BTC;
  final double fiatValue = sats * oneSatInFiat;

  return fiatValue;
}

const btcCurrency = CurrencyNew(
  name: 'Bitcoin',
  price: 0,
  code: 'BTC',
  isFiat: false,
  logoPath: 'assets/images/icon_btc.png',
);
const satsCurrency = CurrencyNew(
  name: 'Sats',
  price: 0,
  code: 'sats',
  isFiat: false,
  logoPath: 'assets/images/icon_btc.png',
);

const lbtcCurrency = CurrencyNew(
  name: 'Liquid Bitcoin',
  price: 0,
  code: 'L-BTC',
  isFiat: false,
  logoPath: 'assets/images/icon_lbtc.png',
);
const lsatsCurrency = CurrencyNew(
  name: 'Liquid Sats',
  price: 0,
  code: 'L-sats',
  isFiat: false,
  logoPath: 'assets/images/icon_lbtc.png',
);
