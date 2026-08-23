part of 'settings_cubit.dart';

@freezed
sealed class SettingsState with _$SettingsState {
  const factory SettingsState({
    SettingsEntity? storedSettings,
    PayjoinPolicy? payjoinPolicy,
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
  bool get isPayjoinEnabled => payjoinPolicy?.enabled ?? false;
  bool get isPayjoinTradingEnabled => payjoinPolicy?.tradingEnabled ?? true;
  bool get isPayjoinSendEnabled => payjoinPolicy?.sendEnabled ?? true;
  int get payjoinMinAmountSat =>
      payjoinPolicy?.minimumAmount.value.toInt() ??
      PayjoinPolicy.defaults().minimumAmount.value.toInt();
  int get payjoinExpireAfterSec =>
      payjoinPolicy?.sessionLifetime.inSeconds ??
      PayjoinPolicy.defaults().sessionLifetime.inSeconds;
}
