import 'package:bb_mobile/core/settings/domain/settings_entity.dart'
    show BitcoinUnit, Environment, Language;
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:flutter/foundation.dart';

extension SqliteDatabaseSeed on SqliteDatabase {
  Future<void> seedTables() async {
    await _settings();
    await _electrumServers();
  }

  Future<void> _settings() async {
    try {
      final s = await managers.settings.filter((f) => f.id(1)).getSingle();
      debugPrint('settings: $s');
    } catch (e) {
      debugPrint('settings: seed default');
      await into(settings).insert(
        SettingsRow(
          id: 1,
          environment: Environment.mainnet.name,
          bitcoinUnit: BitcoinUnit.btc.name,
          language: Language.unitedStatesEnglish.name,
          currency: 'USD',
          hideAmounts: false,
        ),
      );
    }
  }

  Future<void> _electrumServers() async {
    debugPrint('electrum: seed defaults');
    final defaultServers = <ElectrumServerRow>[
      const ElectrumServerRow(
        url: ApiServiceConstants.bbElectrumUrl,
        stopGap: 20,
        timeout: 5,
        retry: 5,
        validateDomain: true,
        isTestnet: false,
        isLiquid: false,
        isActive: false,
        priority: 1,
      ),
      const ElectrumServerRow(
        url: ApiServiceConstants.bbLiquidElectrumUrlPath,
        stopGap: 20,
        timeout: 5,
        retry: 5,
        validateDomain: true,
        isTestnet: false,
        isLiquid: true,
        isActive: false,
        priority: 1,
      ),
      const ElectrumServerRow(
        url: ApiServiceConstants.publicElectrumUrl,
        stopGap: 20,
        timeout: 5,
        retry: 5,
        validateDomain: true,
        isTestnet: false,
        isLiquid: false,
        isActive: false,
        priority: 2,
      ),
      const ElectrumServerRow(
        url: ApiServiceConstants.publicLiquidElectrumUrlPath,
        stopGap: 20,
        timeout: 5,
        retry: 5,
        validateDomain: true,
        isTestnet: false,
        isLiquid: true,
        isActive: false,
        priority: 2,
      ),
      const ElectrumServerRow(
        url: ApiServiceConstants.publicElectrumTestUrl,
        stopGap: 20,
        timeout: 5,
        retry: 5,
        validateDomain: true,
        isTestnet: true,
        isLiquid: false,
        isActive: false,
        priority: 2,
      ),
      const ElectrumServerRow(
        url: ApiServiceConstants.publicliquidElectrumTestUrlPath,
        stopGap: 20,
        timeout: 5,
        retry: 5,
        validateDomain: true,
        isTestnet: true,
        isLiquid: true,
        isActive: false,
        priority: 2,
      ),
    ];

    for (final server in defaultServers) {
      await into(electrumServers).insertOnConflictUpdate(server);
    }
  }
}
