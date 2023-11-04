import 'package:bb_mobile/_model/currency.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'settings_state.freezed.dart';
part 'settings_state.g.dart';

@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default(false) bool unitsInSats,
    @Default(false) bool notifications,
    @Default(false) bool privacyView,
    Currency? currency,
    List<Currency>? currencyList,
    DateTime? lastUpdatedCurrency,
    @Default(false) bool loadingCurrency,
    @Default('') String errLoadingCurrency,
    @Default(20) int reloadWalletTimer,
    String? language,
    List<String>? languageList,
    @Default(false) bool loadingLanguage,
    @Default('') String errLoadingLanguage,
    @Default(true) bool defaultRBF,
  }) = _SettingsState;
  const SettingsState._();

  factory SettingsState.fromJson(Map<String, dynamic> json) => _$SettingsStateFromJson(json);

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

  String calculateFiatPriceForFees({
    required int feeRate,
    Currency? curr,
  }) {
    final selectedCurrency = curr ?? currency;
    if (selectedCurrency == null || selectedCurrency.price == null) return '';

    final btcAmt = (140 * feeRate) / 100000000;
    final amt = (btcAmt * selectedCurrency.price!).toStringAsFixed(2);

    final currencyStr = selectedCurrency.shortName;
    return '~ $amt $currencyStr';
  }
}

extension StringRegEx on String {
  String removeTrailingZero() {
    if (!contains('.')) {
      return this;
    }

    final String trimmed = replaceAll(RegExp(r'0*$'), '');
    if (!trimmed.endsWith('.')) {
      return trimmed;
    }
    try {
      return trimmed.substring(0, length - 1);
    } catch (e) {
      return trimmed;
    }
  }
}
