import 'package:bb_mobile/core/seed/domain/entity/seed.dart' show Seed;
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/migrate_labels.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/migrate_settings.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/migrate_utils.dart'
    show getNetworkFromOldWallet;
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/migrate_wallets_metadatas.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_bip329.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_wallet.dart'
    show OldWallet;
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_wallet_sensitive_storage_repository.dart'
    show OldWalletSensitiveStorageRepository;
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart'
    show ScriptType;
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:flutter/foundation.dart';

extension MigrateHiveToSqlite on SqliteDatabase {
  Future<void> migrateFromHiveToSqlite() async {
    try {
      final settings = await managers.settings.get();
      if (settings.isNotEmpty) return;

      final (oldSecureStorage, oldHive) = await setupStorage();

      final oldSettings = fetchOldSettings(oldHive);

      await _storeNewSettings(
        unitInSats: oldSettings.unitInSats,
        currencyCode: oldSettings.currencyCode,
        hideAmount: oldSettings.hideAmount,
        isTestnet: oldSettings.isTestnet,
      );

      debugPrint(
        'migration: ${oldSettings.unitInSats} | ${oldSettings.currencyCode} | ${oldSettings.hideAmount}',
      );

      final oldLabels = await fetchOldLabels(oldHive);
      final newLabels = await _storeNewLabels(oldLabels);
      debugPrint('migration: ${newLabels.length}/${oldLabels.length} labels');

      final oldWallets = fetchOldWalletMetadatas(oldHive);
      final newMetadatas = await _storeNewWalletMetadatas(
        oldWallets,
        oldSecureStorage,
      );
      debugPrint(
        'migration: ${newMetadatas.length}/${oldWallets.length} wallet metadatas',
      );
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

  Future<List<LabelRow>> _storeNewLabels(List<OldBip329Label> oldLabels) async {
    final rows = <LabelRow>[];

    for (final label in oldLabels) {
      if (label.label == null) continue;

      LabelableEntity type;
      try {
        type = LabelableEntity.from(label.type.name);
      } catch (_) {
        continue;
      }

      rows.add(
        LabelRow(
          label: label.label!,
          ref: label.ref,
          type: type,
          // `label.origin` in v0.4.4 is bugged but fixed in `fetchOldLabels`
          origin: label.origin,
          spendable: label.spendable,
        ),
      );
    }

    for (final row in rows) {
      await into(labels).insert(row);
    }

    return rows;
  }

  Future<List<WalletMetadataRow>> _storeNewWalletMetadatas(
    List<OldWallet> oldWallets,
    OldSecureStorage oldSecureStorage,
  ) async {
    final rows = <WalletMetadataRow>[];

    for (final wallet in oldWallets) {
      try {
        final network = getNetworkFromOldWallet(wallet);
        final scriptType = ScriptType.fromName(wallet.scriptType.name);

        final mnemonic = await OldWalletSensitiveStorageRepository(
          secureStorage: oldSecureStorage,
        ).getMnemonic(fingerprintIndex: wallet.mnemonicFingerprint);
        final seed = Seed.mnemonic(mnemonicWords: mnemonic);

        final walletMetadata = await WalletMetadataService.deriveFromSeed(
          seed: seed,
          network: network,
          scriptType: scriptType,
          label: wallet.name ?? wallet.creationName(),
          isDefault: wallet.isMain(),
        );

        rows.add(walletMetadata.toSqlite());
      } catch (e) {
        debugPrint('SKIP: $e');
        continue;
      }
    }

    for (final row in rows) {
      await into(walletMetadatas).insert(row);
    }
    return rows;
  }
}
