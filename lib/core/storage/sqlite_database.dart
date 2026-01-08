import 'dart:io';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/storage/migrations/schema_0_to_1.dart';
import 'package:bb_mobile/core/storage/migrations/schema_10_to_11.dart';
import 'package:bb_mobile/core/storage/migrations/schema_1_to_2.dart';
import 'package:bb_mobile/core/storage/migrations/schema_2_to_3.dart';
import 'package:bb_mobile/core/storage/migrations/schema_3_to_4.dart';
import 'package:bb_mobile/core/storage/migrations/schema_4_to_5.dart';
import 'package:bb_mobile/core/storage/migrations/schema_5_to_6.dart';
import 'package:bb_mobile/core/storage/migrations/schema_6_to_7.dart';
import 'package:bb_mobile/core/storage/migrations/schema_7_to_8.dart';
import 'package:bb_mobile/core/storage/migrations/schema_8_to_9.dart';
import 'package:bb_mobile/core/storage/migrations/schema_9_to_10.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/core/storage/tables/auto_swap.dart';
import 'package:bb_mobile/core/storage/tables/bip85_derivations_table.dart';
import 'package:bb_mobile/core/storage/tables/electrum_servers_table.dart';
import 'package:bb_mobile/core/storage/tables/electrum_settings_table.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/core/storage/tables/mempool_servers_table.dart';
import 'package:bb_mobile/core/storage/tables/mempool_settings_table.dart';
import 'package:bb_mobile/core/storage/tables/payjoin_receivers_table.dart';
import 'package:bb_mobile/core/storage/tables/payjoin_senders_table.dart';
import 'package:bb_mobile/core/storage/tables/prices_table.dart';
import 'package:bb_mobile/core/storage/tables/recoverbull_table.dart';
import 'package:bb_mobile/core/storage/tables/settings_table.dart';
import 'package:bb_mobile/core/storage/tables/swaps_table.dart';
import 'package:bb_mobile/core/storage/tables/transactions_table.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/features/seeds/frameworks/drift/seed_usage_table.dart';
import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
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
    ElectrumSettings,
    MempoolServers,
    MempoolSettings,
    Swaps,
    AutoSwap,
    Bip85Derivations,
    Recoverbull,
    Prices,
    SeedUsages,
  ],
)
class SqliteDatabase extends _$SqliteDatabase {
  static const name = 'bullbitcoin_sqlite';

  static Future<DriftIsolate> createIsolateWithSpawn() async {
    final token = RootIsolateToken.instance!;
    return await DriftIsolate.spawn(() {
      BackgroundIsolateBinaryMessenger.ensureInitialized(token);

      return LazyDatabase(() async {
        final dbFolder = await getApplicationDocumentsDirectory();
        final dbPath = p.join(dbFolder.path, '${SqliteDatabase.name}.sqlite');
        return NativeDatabase(File(dbPath));
      });
    });
  }

  SqliteDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 11;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: name,
      native: DriftNativeOptions(
        databaseDirectory: getApplicationDocumentsDirectory,

        /// When using a shared instance, stream queries synchronize across the two
        /// isolates. Also, drift then manages concurrent access to the database,
        /// preventing "database is locked" errors due to concurrent transactions.
        shareAcrossIsolates: true,
        setup: (database) {
          // This is important, as accessing the database across threads otherwise
          // causes "database locked" errors.
          // With write-ahead logging (WAL) enabled, a single writer and multiple
          // readers can operate on the database in parallel.
          database.execute('pragma journal_mode = WAL;');
        },
      ),
    );
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: Schema0To1.onCreate,
      onUpgrade: stepByStep(
        from1To2: Schema1To2.migrate,
        from2To3: Schema2To3.migrate,
        from3To4: Schema3To4.migrate,
        from4To5: Schema4To5.migrate,
        from5To6: Schema5To6.migrate,
        from6To7: Schema6To7.migrate,
        from7To8: Schema7To8.migrate,
        from8To9: Schema8To9.migrate,
        from9To10: Schema9To10.migrate,
        from10To11: Schema10To11.migrate,
      ),
    );
  }

  Future<void> clearCacheTables() async {
    final cacheTables = [transactions];

    for (final table in cacheTables) {
      await delete(table).go();
    }
  }
}
