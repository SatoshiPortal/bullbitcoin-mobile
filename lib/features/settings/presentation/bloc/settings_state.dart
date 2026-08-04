part of 'settings_cubit.dart';

@freezed
sealed class SettingsState with _$SettingsState {
  const factory SettingsState({
    SettingsEntity? storedSettings,
    String? appVersion,
  }) = _SettingsState;
  const SettingsState._();

  Environment? get environment => storedSettings?.environment;
  BitcoinUnit? get bitcoinUnit => storedSettings?.bitcoinUnit;
  Language? get language => storedSettings?.language;
  String? get currencyCode => storedSettings?.currencyCode;
  bool? get hideAmounts => storedSettings?.hideAmounts;
  bool? get isSuperuser => storedSettings?.isSuperuser;
  bool? get isDevModeEnabled => storedSettings?.isDevModeEnabled;
  bool get isErrorReportingEnabled =>
      storedSettings?.isErrorReportingEnabled ?? false;
  String? get exchangeTestnetBasicAuthUsername =>
      storedSettings?.exchangeTestnetBasicAuthUsername;
  String? get exchangeTestnetBasicAuthPassword =>
      storedSettings?.exchangeTestnetBasicAuthPassword;
  bool get isPayjoinEnabled => storedSettings?.isPayjoinEnabled ?? false;
  int get payjoinMinAmountSat =>
      storedSettings?.payjoinMinAmountSat ??
      PayjoinConstants.defaultMinAmountSat;
  int get payjoinExpireAfterSec =>
      storedSettings?.payjoinExpireAfterSec ??
      PayjoinConstants.defaultExpireAfterSec;
}
