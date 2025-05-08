import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/migrate_labels.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/migrate_settings.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/migrate_wallets_metadatas.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_bip329.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:flutter/foundation.dart';

extension MigrateHiveToSqlite on SqliteDatabase {
  Future<void> migrateFromHiveToSqlite() async {
    try {
      final settings = await managers.settings.get();
      if (settings.isNotEmpty) return;

      final (secure, hive) = await setupStorage();

      final oldSettings = fetchOldSettings(hive);
      debugPrint(
        'settings: ${oldSettings.unitInSats} | ${oldSettings.currencyCode} | ${oldSettings.hideAmount}',
      );

      await _storeNewSettings(
        unitInSats: oldSettings.unitInSats,
        currencyCode: oldSettings.currencyCode,
        hideAmount: oldSettings.hideAmount,
        isTestnet: oldSettings.isTestnet,
      );

      final labels = await fetchOldLabels(hive);
      debugPrint('labels: $labels');

      _storeNewLabels(labels);

      final metadatas = fetchOldWalletMetadatas(hive);
      debugPrint('metadatas: $metadatas');
    } catch (e) {
      debugPrint('Error during migrations: $e');
    }
  }
}

extension MigrateFromHive on SqliteDatabase {
  Future<void> _storeNewSettings({
    bool? unitInSats,
    String? currencyCode,
    bool? hideAmount,
    bool? isTestnet,
  }) async {
    await into(settings).insert(
      SettingsRow(
        id: 1,
        environment: isTestnet == true ? 'testnet' : 'mainnet',
        bitcoinUnit: unitInSats == true ? 'sats' : 'btc',
        language: 'unitedStatesEnglish',
        currency: currencyCode ?? 'USD',
        hideAmounts: hideAmount ?? false,
      ),
    );
  }

  void _storeNewLabels(List<Bip329Label> oldLabels) {
    for (final label in oldLabels) {
      if (label.label == null) continue;

      LabelableEntity type;
      try {
        type = LabelableEntity.from(label.type.name);
      } catch (_) {
        continue;
      }

      into(labels).insert(
        LabelRow(
          label: label.label!,
          ref: label.ref,
          type: type,
          origin: label.origin,
          spendable: label.spendable,
        ),
      );
    }
  }
}
