import 'package:bb_mobile/features/settings/data/settings_model.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';

SettingsEntity settingsEntityFromModel(SettingsModel s) => SettingsEntity(
  environment: s.environment,
  bitcoinUnit: s.bitcoinUnit,
  startAmountsInFiat: s.startAmountsInFiat,
  currencyCode: s.currency,
  language: s.language,
  hideAmounts: s.hideAmounts,
  isSuperuser: s.isSuperuser,
  isDevModeEnabled: s.isDevModeEnabled,
  useTorProxy: s.useTorProxy,
  torProxyPort: s.torProxyPort,
  torTransportMode: s.torTransportMode,
  lastSuccessfulTorTransport: s.lastSuccessfulTorTransport,
  themeMode: s.themeMode,
  isErrorReportingEnabled: s.isErrorReportingEnabled,
  screenCaptureProtectionEnabled: s.screenCaptureProtectionEnabled,
  exchangeTestnetBasicAuthUsername: s.exchangeTestnetBasicAuthUsername,
  exchangeTestnetBasicAuthPassword: s.exchangeTestnetBasicAuthPassword,
);
