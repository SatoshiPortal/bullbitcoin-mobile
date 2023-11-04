import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'settings_state.freezed.dart';
part 'settings_state.g.dart';

@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default(false) bool notifications,
    @Default(false) bool privacyView,
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
