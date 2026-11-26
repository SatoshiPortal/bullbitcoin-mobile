import 'package:preferences/src/domain/settings_entity.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

import 'owner_settings_table.drift.dart';

import 'package:bull_tor/tor.dart';

class SettingsModel {
  final int id;
  final Environment environment;
  final BitcoinUnit bitcoinUnit;
  final bool startAmountsInFiat;
  final Language language;
  final String currency;
  final bool hideAmounts;
  final bool isSuperuser;
  final bool isDevModeEnabled;
  final bool useTorProxy;
  final int torProxyPort;
  final TorTransportMode torTransportMode;
  final TorTransport? lastSuccessfulTorTransport;
  final AppThemeMode themeMode;
  final bool isErrorReportingEnabled;
  final bool screenCaptureProtectionEnabled;
  final bool showPaymentAnimations;

  const SettingsModel({
    required this.id,
    required this.environment,
    required this.bitcoinUnit,
    this.startAmountsInFiat = false,
    required this.language,
    required this.currency,
    required this.hideAmounts,
    required this.isSuperuser,
    required this.isDevModeEnabled,
    required this.useTorProxy,
    required this.torProxyPort,
    required this.torTransportMode,
    this.lastSuccessfulTorTransport,
    required this.themeMode,
    required this.isErrorReportingEnabled,
    required this.screenCaptureProtectionEnabled,
    this.showPaymentAnimations = true,
  });

  factory SettingsModel.fromSqlite(OwnerSettingsRow row) {
    return SettingsModel(
      id: row.id,
      environment: Environment.fromName(row.environment),
      bitcoinUnit: BitcoinUnit.fromName(row.bitcoinUnit),
      startAmountsInFiat: row.startAmountsInFiat,
      language: Language.fromName(row.language),
      currency: row.currency,
      hideAmounts: row.hideAmounts,
      isSuperuser: row.isSuperuser,
      isDevModeEnabled: row.isDevModeEnabled,
      useTorProxy: row.useTorProxy,
      torProxyPort: row.torProxyPort,
      torTransportMode: TorTransportMode.values.firstWhere(
        (mode) => mode.name == row.torTransportMode,
        orElse: () => TorTransportMode.automatic,
      ),
      lastSuccessfulTorTransport: switch (row.lastSuccessfulTorTransport) {
        'direct' => TorTransport.direct,
        'snowflake' => TorTransport.snowflake,
        _ => null,
      },
      themeMode: AppThemeMode.fromName(row.themeMode),
      isErrorReportingEnabled: row.isErrorReportingEnabled,
      screenCaptureProtectionEnabled: row.screenCaptureProtectionEnabled,
      showPaymentAnimations: row.showPaymentAnimations,
    );
  }
}
