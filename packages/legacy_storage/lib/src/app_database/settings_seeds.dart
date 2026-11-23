import 'package:bull_logger/bull_logger.dart';

import 'sqlite_database.dart';
import 'tables/settings_table.drift.dart';

class SettingsSeeds {
  static Future<void> seed(SqliteDatabase db) async {
    log.info('[SqliteDatabase] seeding default settings...');
    await db
        .into(db.settings)
        .insert(
          const SettingsRow(
            id: 1,
            environment: 'mainnet',
            bitcoinUnit: 'sats',
            startAmountsInFiat: false,
            language: 'unitedStatesEnglish',
            currency: 'USD',
            hideAmounts: false,
            isSuperuser: false,
            isDevModeEnabled: false,
            useTorProxy: false,
            torProxyPort: 9050,
            torTransportMode: 'automatic',
            themeMode: 'system',
            isErrorReportingEnabled: false,
            screenCaptureProtectionEnabled: true,
          ),
        );
  }
}
