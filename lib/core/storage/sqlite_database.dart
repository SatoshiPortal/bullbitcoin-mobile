import 'package:bb_mobile/core/storage/migrations/004_legacy/migrate_v4_legacy_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/entities/new_seed_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/entities/new_wallet_metadata_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/new_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/new_wallet_metadata_service.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_seed.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_wallet.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_hive_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_wallet_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/secure_storage_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/core/storage/tables/electrum_servers_table.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/core/storage/tables/payjoin_receivers_table.dart';
import 'package:bb_mobile/core/storage/tables/payjoin_senders_table.dart';
import 'package:bb_mobile/core/storage/tables/settings_table.dart';
import 'package:bb_mobile/core/storage/tables/swaps_table.dart';
import 'package:bb_mobile/core/storage/tables/transactions_table.dart';
import 'package:bb_mobile/core/storage/tables/v5_migrate_wallet_metadata_table.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
part 'sqlite_database.g.dart';

@DriftDatabase(
  tables: [
    Transactions,
    V5MigrateWalletMetadatas,
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        // 0.4 to 0.5 migration
        await m.createAll();
        final newSeedRepository = NewSeedRepository(
          MigrationSecureStorageDatasource(),
        );
        final oldSeedRepository = OldSeedRepository(
          MigrationSecureStorageDatasource(),
        );
        // create an instance of MigrateToV5HiveToSqliteToUsecase
        final oldHiveBox = await OldHiveDatasource.getBox();
        final oldWalletRepository = OldWalletRepository(
          OldHiveDatasource(oldHiveBox),
        );
        final legacyMigrationUsecase = MigrateToV4LegacyUsecase(
          MigrationSecureStorageDatasource(),
        );
        final isLegacy = await legacyMigrationUsecase.execute();
        if (isLegacy) {
          final oldWallets = await oldWalletRepository.fetch();
          if (oldWallets.isEmpty) return;
          final oldFingerprints =
              oldWallets.map((e) => e.mnemonicFingerprint).toSet().toList();
          debugPrint('oldFingerprints: ${oldFingerprints.length}');
          final mainWallets =
              oldWallets.where((e) => e.type == OldBBWalletType.main).toList();
          debugPrint('mainWallets: ${mainWallets.length}');
          // ignore: unused_local_variable
          final externalWallets =
              oldWallets.where((e) => e.type != OldBBWalletType.main).toList();
          // ignore: unnecessary_null_comparison
          if (oldWallets == null) return;

          for (final oldWallet in oldWallets) {
            // Derive and store the wallet metadata
            OldSeed oldSeed;
            try {
              oldSeed = await oldSeedRepository.fetch(
                fingerprint: oldWallet.mnemonicFingerprint,
              );
            } catch (e) {
              debugPrint('Could not find seed. Likely a watch only wallet: $e');
              return;
            }

            final hasPassphrase = oldSeed.passphrases.isNotEmpty;
            if (hasPassphrase) {
              for (final passphrase in oldSeed.passphrases) {
                final seed = NewSeedEntity.mnemonic(
                  mnemonicWords: oldSeed.mnemonicList(),
                  passphrase: passphrase.passphrase,
                );
                await newSeedRepository.store(
                  fingerprint: seed.masterFingerprint,
                  seed: seed,
                );
              }
            }
            final seed = NewSeedEntity.mnemonic(
              mnemonicWords: oldSeed.mnemonicList(),
            );
            await newSeedRepository.store(
              fingerprint: seed.masterFingerprint,
              seed: seed,
            );
            final network =
                oldWallet.baseWalletType == OldBaseWalletType.Bitcoin
                    ? (oldWallet.isTestnet()
                        ? NewNetwork.bitcoinTestnet
                        : NewNetwork.bitcoinMainnet)
                    : (oldWallet.isTestnet()
                        ? NewNetwork.liquidTestnet
                        : NewNetwork.liquidMainnet);

            final scriptType = switch (oldWallet.scriptType) {
              OldScriptType.bip84 => NewScriptType.bip84,
              OldScriptType.bip49 => NewScriptType.bip49,
              OldScriptType.bip44 => NewScriptType.bip44,
            };

            if (oldWallet.type == OldBBWalletType.main) {
              final metadata = await NewWalletMetadataService.deriveFromSeed(
                seed: seed,
                network: network,
                scriptType: scriptType,
                isDefault: true,
                label:
                    oldWallet.baseWalletType == OldBaseWalletType.Bitcoin
                        ? 'Secure Bitcoin'
                        : 'Instant Payments',
              );
              await managers.walletMetadatas.create(
                (f) => f(
                  id: metadata.id,
                  label: metadata.label,
                  isDefault: metadata.isDefault,
                  isPhysicalBackupTested: metadata.isPhysicalBackupTested,
                  isEncryptedVaultTested: metadata.isEncryptedVaultTested,
                  externalPublicDescriptor: metadata.externalPublicDescriptor,
                  internalPublicDescriptor: metadata.internalPublicDescriptor,
                  masterFingerprint: metadata.masterFingerprint,
                  source: metadata.source.name,
                  xpub: metadata.xpub,
                  xpubFingerprint: metadata.xpubFingerprint,
                  syncedAt: Value(metadata.syncedAt),
                  latestEncryptedBackup: Value(metadata.latestEncryptedBackup),
                  latestPhysicalBackup: Value(metadata.latestPhysicalBackup),
                ),
              );
            } else {
              final metadata = await NewWalletMetadataService.deriveFromSeed(
                seed: seed,
                network: network,
                scriptType: scriptType,
                isDefault: false,
                label: oldWallet.name ?? oldWallet.sourceFingerprint,
              );
              await managers.walletMetadatas.create(
                (f) => f(
                  id: metadata.id,
                  label: metadata.label,
                  isDefault: metadata.isDefault,
                  isPhysicalBackupTested: metadata.isPhysicalBackupTested,
                  isEncryptedVaultTested: metadata.isEncryptedVaultTested,
                  externalPublicDescriptor: metadata.externalPublicDescriptor,
                  internalPublicDescriptor: metadata.internalPublicDescriptor,
                  masterFingerprint: metadata.masterFingerprint,
                  source: metadata.source.name,
                  xpub: metadata.xpub,
                  xpubFingerprint: metadata.xpubFingerprint,
                  syncedAt: Value(metadata.syncedAt),
                  latestEncryptedBackup: Value(metadata.latestEncryptedBackup),
                  latestPhysicalBackup: Value(metadata.latestPhysicalBackup),
                ),
              );
            }
          }
        }
      },
      onUpgrade: stepByStep(
        from1To2: (m, schema) async {
          await m.createTable(schema.walletMetadatas);

          // copy data from old table to new table
          final v5WalletMetadata =
              await managers.v5MigrateWalletMetadatas.get();

          for (final v5WalletMetadata in v5WalletMetadata) {
            await managers.walletMetadatas.create(
              (f) => f(
                id: v5WalletMetadata.id,
                label: v5WalletMetadata.label,
                isDefault: v5WalletMetadata.isDefault,
                isPhysicalBackupTested: v5WalletMetadata.isPhysicalBackupTested,
                isEncryptedVaultTested: v5WalletMetadata.isEncryptedVaultTested,
                externalPublicDescriptor:
                    v5WalletMetadata.externalPublicDescriptor,
                internalPublicDescriptor:
                    v5WalletMetadata.internalPublicDescriptor,
                masterFingerprint: v5WalletMetadata.masterFingerprint,
                source: v5WalletMetadata.source.name,
                xpub: v5WalletMetadata.xpub,
                xpubFingerprint: v5WalletMetadata.xpubFingerprint,
                syncedAt: Value(v5WalletMetadata.syncedAt),
                latestEncryptedBackup: Value(
                  v5WalletMetadata.latestEncryptedBackup,
                ),
                latestPhysicalBackup: Value(
                  v5WalletMetadata.latestPhysicalBackup,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'bullbitcoin_sqlite',
      native: const DriftNativeOptions(),
    );
  }

  Future<void> clearCacheTables() async {
    final cacheTables = [transactions];

    for (final table in cacheTables) {
      await delete(table).go();
    }
  }
}
