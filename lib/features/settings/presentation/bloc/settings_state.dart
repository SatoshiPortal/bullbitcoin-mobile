part of 'settings_cubit.dart';

@freezed
sealed class SettingsState with _$SettingsState {
  const factory SettingsState({
    SettingsEntity? storedSettings,
    String? appVersion,
    bool? hasLegacySeeds,
    // Set when `toggleDevMode(false)` could not fully wipe the SP wallet on
    // disk (e.g. file-locked because the SP notification thread still holds the
    // sqlite handle, or iOS document-protection denial). Dev mode is still
    // flipped off in that case because `RevokeSpWalletUsecase` drops a
    // `.revoked` sentinel BEFORE the recursive delete, so the partial-state
    // wallet stays unloadable. A bool (not the raw exception string): the UI
    // renders a generic localized message and the raw cause is logged at the
    // boundary only, never surfaced to the user.
    @Default(false) bool revokeSpFailed,
    // Whether the Silent Payments wallet is set up (gated + sentinel-aware),
    // read through the SP facade. Drives the bitcoin-settings SP setup/settings
    // entry, so the screen reads it here instead of the WalletBloc.
    @Default(false) bool isSpWalletSetup,
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
}
