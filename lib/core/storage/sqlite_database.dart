import 'dart:convert';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/migrations/models/wallet_migration_model.dart';
import 'package:bb_mobile/core/storage/tables/electrum_servers_table.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/core/storage/tables/payjoin_receivers_table.dart';
import 'package:bb_mobile/core/storage/tables/payjoin_senders_table.dart';
import 'package:bb_mobile/core/storage/tables/settings_table.dart';
import 'package:bb_mobile/core/storage/tables/swaps_table.dart';
import 'package:bb_mobile/core/storage/tables/transactions_table.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/semantic_versions.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'sqlite_database.g.dart';

@DriftDatabase(
  tables: [
    Transactions,
    WalletMetadatas,
    Labels,
    Settings,
    PayjoinSenders,
    PayjoinReceivers,
    ElectrumServers,
    Swaps,
  ],
)
class SqliteDatabase extends _$SqliteDatabase {
  SqliteDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'bullbitcoin_sqlite',
      native: const DriftNativeOptions(),
    );
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Seed database with default values
        // !Important! If future migrations add columns that require default
        //  values as well, the seeding of that column has to be done in the
        //  migration step as well, since either the onCreate or the migration
        //  steps get executed, not both. Make sure in the migration you only
        //  seed the new columns and don't overwrite any existing data.
        await Future.wait([
          _seedDefaultSettings(),
          _seedDefaultElectrumServers(),
        ]);

        // Migrations from before Sqlite with schema version 1
        await _migrateToV0_5();
      },
    );
  }

  Future<void> _seedDefaultSettings() async {
    debugPrint('[SqliteDatabase] seeding default settings...');
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

  Future<void> _seedDefaultElectrumServers() async {
    final serversData = [
      (ApiServiceConstants.bbElectrumUrl, false, false, 1),
      (ApiServiceConstants.bbLiquidElectrumUrlPath, false, true, 1),
      (ApiServiceConstants.publicElectrumUrl, false, false, 2),
      (ApiServiceConstants.publicLiquidElectrumUrlPath, false, true, 2),
      (ApiServiceConstants.publicElectrumTestUrl, true, false, 2),
      (ApiServiceConstants.publicliquidElectrumTestUrlPath, true, true, 2),
    ];

    for (final (url, isTestnet, isLiquid, priority) in serversData) {
      final server = ElectrumServerRow(
        url: url,
        stopGap: 20,
        timeout: 5,
        retry: 5,
        validateDomain: true,
        isTestnet: isTestnet,
        isLiquid: isLiquid,
        isActive: false,
        priority: priority,
      );

      await into(electrumServers).insertOnConflictUpdate(server);
    }
  }

  Future<void> _migrateToV0_5() async {
    // Get current version
    const secureStorage = FlutterSecureStorage();
    final legacyVersion = await secureStorage.read(key: 'version');
    if (legacyVersion == null) {
      // If the version is null, it means this is the first time the app is
      // being run, so we can skip the migration.
      debugPrint(
        '[SqliteDatabase] Not coming from < v0.5 before Sqlite, '
        'no migration to v0.5 needed',
      );
      return;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(dir.path);
      final hiveEncryptionKey = await secureStorage.read(
        key: 'hiveEncryptionKey',
      );
      if (hiveEncryptionKey == null) {
        debugPrint(
          '[SqliteDatabase] Hive encryption key is null, skip migration to v0.5',
        );
        return;
      }
      final cipher = HiveAesCipher(base64Url.decode(hiveEncryptionKey));
      final box = await Hive.openBox<String>('store', encryptionCipher: cipher);
      final hiveWalletsValue = box.get('wallets');
      if (hiveWalletsValue == null) {
        debugPrint(
          '[SqliteDatabase] No wallets found in Hive, skip migration to v0.5',
        );
        return;
      }
      final hiveWallets = json.decode(hiveWalletsValue) as Map<String, dynamic>;
      final hiveWalletIds = (hiveWallets['wallets'] as List).cast<String>();

      // Depending on the version, the fields in the hive wallets may be different
      List<WalletMigrationModel> walletMigrationModels;
      if (SemanticVersions.isLowerThan(legacyVersion, '0.2.0')) {
        walletMigrationModels = await _v0_1ToWalletMigrationModels(
          hiveWalletIds,
          box: box,
          secureStorage: secureStorage,
        );
      } else {
        walletMigrationModels = await _v0_2V0_3V0_4ToWalletMigrationModels(
          hiveWalletIds,
          box: box,
          secureStorage: secureStorage,
        );
      }

      // Migrate wallets to WalletMetadata models
      final mnemonicWallets = walletMigrationModels.where(
        (model) => model.mnemonic.isNotEmpty,
      );
      for (final model in mnemonicWallets) {
        final seed = SeedModel.mnemonic(
          mnemonicWords: model.mnemonic.split(' '),
          passphrase: model.passphrase.isNotEmpty ? model.passphrase : null,
        );
        // store the seed in the secure storage
        await secureStorage.write(
          key: SeedDatasource.composeSeedStorageKey(seed.masterFingerprint),
          value: json.encode(seed.toJson()),
        );
        // store the wallet in the database

        final walletMetadataModel = await WalletMetadataService.deriveFromSeed(
          seed: seed.toEntity(),
          network: model.network,
          scriptType: model.scriptType,
          label: model.label,
          isDefault: model.isDefault,
        );
        final walletMetadataRow = walletMetadataModel.toSqlite();
        await into(walletMetadatas).insertOnConflictUpdate(walletMetadataRow);
      }
    }
  }

  Future<List<WalletMigrationModel>> _v0_1ToWalletMigrationModels(
    List<String> oldWalletIds, {
    required Box<String> box,
    required FlutterSecureStorage secureStorage,
  }) async {
    final List<WalletMigrationModel> walletMigrations = [];

    String? mainnetMnemonic;
    String? mainnetPassphrase;

    String? testnetMnemonic;
    String? testnetPassphrase;

    for (final id in oldWalletIds) {
      final oldWalletValue = box.get(id);
      if (oldWalletValue == null) continue;
      final oldWallet = json.decode(oldWalletValue) as Map<String, dynamic>;

      final type = oldWallet['type'] as String;
      final networkStr = oldWallet['network'] as String;
      final isMainnet = networkStr == 'Mainnet';
      final isTestnet = networkStr == 'Testnet';

      final mnemonicFingerprint = oldWallet['mnemonicFingerprint'] as String;
      final sourceFingerprint = oldWallet['sourceFingerprint'] as String;

      final seedJson = await secureStorage.read(key: mnemonicFingerprint);
      if (seedJson == null) continue;
      final seedMap = json.decode(seedJson) as Map<String, dynamic>;

      final mnemonic = seedMap['mnemonic'] as String? ?? '';
      final passphrases = seedMap['passphrases'] as List<dynamic>? ?? [];
      final passphrase =
          passphrases.cast<Map<String, dynamic>>().firstWhere(
                (p) => p['sourceFingerprint'] == sourceFingerprint,
                orElse: () => {'passphrase': ''},
              )['passphrase']
              as String;

      final externalDesc = oldWallet['externalPublicDescriptor'] as String;
      final internalDesc = oldWallet['internalPublicDescriptor'] as String;
      final script = oldWallet['scriptType'] as String? ?? 'bip84';
      final label = oldWallet['name'] as String?;
      final isDefault = oldWallet['mainWallet'] == true;

      final source = switch (type) {
        'newSeed' || 'main' || 'words' => WalletSource.mnemonic,
        'xpub' => WalletSource.xpub,
        'descriptors' => WalletSource.descriptors,
        'coldcard' => WalletSource.coldcard,
        _ => WalletSource.mnemonic,
      };

      final scriptType = switch (script) {
        'bip49' => ScriptType.bip49,
        'bip44' => ScriptType.bip44,
        _ => ScriptType.bip84,
      };

      final network = Network.fromEnvironment(
        isTestnet: isTestnet,
        isLiquid: false, // baseWalletType was not present before v0.2.0
      );

      final model = WalletMigrationModel(
        mnemonic: mnemonic,
        passphrase: passphrase,
        externalPublicDescriptor: externalDesc,
        internalPublicDescriptor: internalDesc,
        isDefault: isDefault,
        network: network,
        source: source,
        scriptType: scriptType,
        label: label,
      );

      walletMigrations.add(model);

      if (isDefault && source == WalletSource.mnemonic) {
        if (isMainnet) {
          mainnetMnemonic = mnemonic;
          mainnetPassphrase = passphrase;
        } else if (isTestnet) {
          testnetMnemonic = mnemonic;
          testnetPassphrase = passphrase;
        }
      }
    }

    if (mainnetMnemonic != null) {
      walletMigrations.add(
        WalletMigrationModel(
          mnemonic: mainnetMnemonic,
          passphrase: mainnetPassphrase ?? '',
          isDefault: true,
          network: Network.liquidMainnet,
          source: WalletSource.mnemonic,
          scriptType: ScriptType.bip84,
          label: 'Instant Payments Wallet',
        ),
      );
    }

    if (testnetMnemonic != null) {
      walletMigrations.add(
        WalletMigrationModel(
          mnemonic: testnetMnemonic,
          passphrase: testnetPassphrase ?? '',
          isDefault: true,
          network: Network.liquidTestnet,
          source: WalletSource.mnemonic,
          scriptType: ScriptType.bip84,
          label: 'Instant Payments Wallet',
        ),
      );
    }

    return walletMigrations;
  }

  Future<List<WalletMigrationModel>> _v0_2V0_3V0_4ToWalletMigrationModels(
    List<String> oldWalletIds, {
    required Box<String> box,
    required FlutterSecureStorage secureStorage,
  }) async {
    final walletsToMigrate =
        (await Future.wait(
          oldWalletIds.map((id) async {
            debugPrint('[SqliteDatabase] Migrating wallet with id: $id');
            final oldWalletValue = box.get(id);
            if (oldWalletValue == null) {
              return null;
            }
            final oldWallet =
                json.decode(oldWalletValue) as Map<String, dynamic>;

            final mnemonicFingerprint =
                oldWallet['mnemonicFingerprint'] as String;
            final sourceFingerprint = oldWallet['sourceFingerprint'] as String;

            final String externalPublicDescriptor =
                oldWallet['externalPublicDescriptor'] as String;
            final String internalPublicDescriptor =
                oldWallet['internalPublicDescriptor'] as String;
            final bool isDefault = oldWallet['type'] == 'main';
            final isLiquid = oldWallet['baseWalletType'] == 'Liquid';
            final isTestnet = oldWallet['network'] == 'Testnet';
            final network = Network.fromEnvironment(
              isTestnet: isTestnet,
              isLiquid: isLiquid,
            );
            final source = switch (oldWallet['type']) {
              'main' || 'words' => WalletSource.mnemonic,
              'xpub' => WalletSource.xpub,
              'descriptors' => WalletSource.descriptors,
              'coldcard' => WalletSource.coldcard,
              _ => WalletSource.mnemonic,
            };
            final scriptType =
                oldWallet['scriptType'] == 'bip84'
                    ? ScriptType.bip84
                    : oldWallet['scriptType'] == 'bip49'
                    ? ScriptType.bip49
                    : ScriptType.bip44;
            final label = oldWallet['name'] as String?;

            String mnemonic = '';
            String passphrase = '';
            final oldSeedValue = await secureStorage.read(
              key: mnemonicFingerprint,
            );
            if (oldSeedValue != null) {
              final oldSeed = json.decode(oldSeedValue) as Map<String, dynamic>;
              mnemonic = oldSeed['mnemonic'] as String? ?? '';
              final passphrases =
                  oldSeed['passphrases'] as List<dynamic>? ?? [];
              passphrase =
                  passphrases.cast<Map<String, dynamic>>().firstWhere(
                        (p) => p['sourceFingerprint'] == sourceFingerprint,
                        orElse: () => {'passphrase': ''},
                      )['passphrase']
                      as String;
            }

            final walletMigrationModel = WalletMigrationModel(
              mnemonic: mnemonic,
              passphrase: passphrase,
              externalPublicDescriptor: externalPublicDescriptor,
              internalPublicDescriptor: internalPublicDescriptor,
              isDefault: isDefault,
              network: network,
              source: source,
              scriptType: scriptType,
              label: label,
            );

            return walletMigrationModel;
          }),
        )).whereType<WalletMigrationModel>().toList();

    return walletsToMigrate;
  }

  Future<void> clearCacheTables() async {
    final cacheTables = [transactions];

    for (final table in cacheTables) {
      await delete(table).go();
    }
  }
}
