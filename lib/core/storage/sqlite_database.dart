import 'package:bb_mobile/core/storage/migrations/004_legacy/migrate_v4_legacy_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/migrate_v5_hive_to_sqlite_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/new_seed_repository.dart';
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
        // create an instance of MigrateToV5HiveToSqliteToUsecase
        final oldHiveBox = await OldHiveDatasource.getBox();
        final legacyMigrationUsecase = MigrateToV4LegacyUsecase(
          MigrationSecureStorageDatasource(),
        );
        final isLegacy = await legacyMigrationUsecase.execute();
        if (isLegacy) {
          final migrateSeedToV5AndGetHiveToSqliteWalletsUsecase =
              MigrateSeedToV5AndGetHiveToSqliteWalletsUsecase(
                newSeedRepository: NewSeedRepository(
                  MigrationSecureStorageDatasource(),
                ),
                oldSeedRepository: OldSeedRepository(
                  MigrationSecureStorageDatasource(),
                ),
                oldWalletRepository: OldWalletRepository(
                  OldHiveDatasource(oldHiveBox),
                ),
              );
          // ignore: unused_local_variable
          final oldWallets =
              await migrateSeedToV5AndGetHiveToSqliteWalletsUsecase.execute();
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
