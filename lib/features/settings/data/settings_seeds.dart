import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/settings/data/settings_table.drift.dart';
import 'package:bull_logger/bull_logger.dart';

class SettingsSeeds {
  static Future<void> seed(SqliteDatabase db) async {
    log.info('[SqliteDatabase] seeding default settings...');
    await db
        .into(db.settings)
        .insert(
          SettingsRow(
            id: 1,
            environment: Environment.mainnet.name,
            bitcoinUnit: BitcoinUnit.sats.name,
            startAmountsInFiat: false,
            language: Language.unitedStatesEnglish.name,
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
