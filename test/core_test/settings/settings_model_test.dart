import 'package:bb_mobile/core/settings/data/settings_model.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:flutter_test/flutter_test.dart';

SettingsModel _buildModel({bool useCompactBlockFiltersByDefault = false}) {
  return SettingsModel(
    id: 1,
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    language: Language.unitedStatesEnglish,
    currency: 'USD',
    hideAmounts: false,
    isSuperuser: false,
    isDevModeEnabled: false,
    useTorProxy: false,
    torProxyPort: 9050,
    themeMode: AppThemeMode.system,
    isErrorReportingEnabled: false,
    useCompactBlockFiltersByDefault: useCompactBlockFiltersByDefault,
  );
}

void main() {
  group('SettingsModel.useCompactBlockFiltersByDefault', () {
    test('defaults to false when omitted', () {
      const model = SettingsModel(
        id: 1,
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        language: Language.unitedStatesEnglish,
        currency: 'USD',
        hideAmounts: false,
        isSuperuser: false,
        isDevModeEnabled: false,
        useTorProxy: false,
        torProxyPort: 9050,
        themeMode: AppThemeMode.system,
        isErrorReportingEnabled: false,
      );
      expect(model.useCompactBlockFiltersByDefault, isFalse);
    });

    test('toSqlite round-trips true through fromSqlite', () {
      final model = _buildModel(useCompactBlockFiltersByDefault: true);
      final row = model.toSqlite();
      expect(row.useCompactBlockFiltersByDefault, isTrue);

      final restored = SettingsModel.fromSqlite(row);
      expect(restored.useCompactBlockFiltersByDefault, isTrue);
    });

    test('toSqlite round-trips false through fromSqlite', () {
      final model = _buildModel();
      final row = model.toSqlite();
      expect(row.useCompactBlockFiltersByDefault, isFalse);

      final restored = SettingsModel.fromSqlite(row);
      expect(restored.useCompactBlockFiltersByDefault, isFalse);
    });
  });
}
