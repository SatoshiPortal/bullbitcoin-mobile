import 'package:bb_mobile/_model/currency.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'currency_state.freezed.dart';
part 'currency_state.g.dart';

@freezed
class CurrencyState with _$CurrencyState {
  const factory CurrencyState({
    @Default(false) bool unitsInSats,
    @Default(false) bool fiatSelected,
    Currency? currency,
    Currency? defaultFiatCurrency,
    List<Currency>? currencyList,
    DateTime? lastUpdatedCurrency,
    @Default(false) bool loadingCurrency,
    @Default('') String errLoadingCurrency,
    @Default(0) double fiatAmt,
    @Default(0) int amount,
    String? tempAmount,
    @Default('') String errAmount,
  }) = _CurrencyState;
  const CurrencyState._();

  factory CurrencyState.fromJson(Map<String, dynamic> json) => _$CurrencyStateFromJson(json);

  String satsFormatting(String satsAmount) {
    final currency = NumberFormat('#,##0', 'en_US');
    return currency.format(
      double.parse(satsAmount),
    );
  }

  String fiatFormatting(String fiatAmount) {
    final currency = NumberFormat('#,##0.00', 'en_US');
    return currency.format(
      double.parse(fiatAmount),
    );
  }

  String btcFormatting(String btcAmount) {
    final currency = NumberFormat.currency(
      locale: 'en_US',
      customPattern: '#,##0.####,###0',
      decimalDigits: 8,
    );
    return currency
        .format(
          double.parse(btcAmount),
        )
        .replaceAll('', ' ');
  }

  String getAmountInUnits(
    int amount, {
    bool? isSats,
    bool removeText = false,
    bool hideZero = false,
    bool removeEndZeros = false,
  }) {
    String amt = '';
    if (isSats ?? unitsInSats)
      amt = satsFormatting(amount.toString()) + ' sats';
    else {
      String b = '';
      if (!removeEndZeros)
        b = (amount / 100000000).toStringAsFixed(8);
      else
        b = (amount / 100000000).toStringAsFixed(8);
      amt = b + ' BTC';
    }

    if (removeText) {
      amt = amt.replaceAll(' sats', '');
      amt = amt.replaceAll(' BTC', '');
    }

    if (hideZero && amount == 0) amt = '';

    amt.replaceAll('-', '');

    return amt;
  }

  String getUnitString() {
    if (unitsInSats) return 'sats';
    return 'BTC';
  }

  int getSatsAmount(String amount, bool? unitsInSatss) {
    if (unitsInSatss ?? unitsInSats) return int.tryParse(amount) ?? 0;
    return ((double.tryParse(amount) ?? 0) * 100000000).toInt();
  }

  List<Currency> updatedCurrencyList() {
    final list = [
      const Currency(name: 'btc', price: 0, shortName: 'BTC'),
      const Currency(name: 'sats', price: 0, shortName: 'sats'),
      ...currencyList ?? <Currency>[],
    ];

    return list;
  }
}
