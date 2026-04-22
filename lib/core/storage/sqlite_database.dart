import 'dart:io';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/storage/drift_schema_version.dart';
import 'package:bb_mobile/core/storage/migrations/migrations.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/core/utils/logger.dart';
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
        return NativeDatabase(
          File(dbPath),
          setup: (database) {
            database.execute('PRAGMA journal_mode = WAL;');
            database.execute('PRAGMA busy_timeout = 2000;');
            database.execute('PRAGMA synchronous = FULL;');
          },
        );
      });
    });
  }

  SqliteDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  @override
  int get schemaVersion => kDriftSchemaVersion;

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
          database.execute('PRAGMA journal_mode = WAL;');
          // Retry for up to 1 second when the database is locked before failing.
          database.execute('PRAGMA busy_timeout = 2000;');
          // Ensure maximum durability: fsync before and after every write.
          database.execute('PRAGMA synchronous = FULL;');
        },
      ),
    );
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: _reportingOnCreate(Schema0To1.onCreate),
      onUpgrade: stepByStep(
        from1To2: _reportingStep('from1To2', Schema1To2.migrate),
        from2To3: _reportingStep('from2To3', Schema2To3.migrate),
        from3To4: _reportingStep('from3To4', Schema3To4.migrate),
        from4To5: _reportingStep('from4To5', Schema4To5.migrate),
        from5To6: _reportingStep('from5To6', Schema5To6.migrate),
        from6To7: _reportingStep('from6To7', Schema6To7.migrate),
        from7To8: _reportingStep('from7To8', Schema7To8.migrate),
        from8To9: _reportingStep('from8To9', Schema8To9.migrate),
        from9To10: _reportingStep('from9To10', Schema9To10.migrate),
        from10To11: _reportingStep('from10To11', Schema10To11.migrate),
        from11To12: _reportingStep('from11To12', Schema11To12.migrate),
      ),
    );
  }

  /// Wraps a per-version drift migration step so a failure is surfaced to
  /// Sentry via the always-on migration channel before the rethrow aborts
  /// init. Drift migrations run lazily on first query, so wrapping the step
  /// fn (not the constructor) is what actually catches failures.
  static Future<void> Function(Migrator, Schema) _reportingStep<Schema>(
    String name,
    Future<void> Function(Migrator, Schema) fn,
  ) {
    return (m, schema) async {
      try {
        await fn(m, schema);
      } catch (e, s) {
        await log.migration(
          level: Level.SEVERE,
          message: 'drift migration step $name failed',
          exception: e,
          stackTrace: s,
        );
        rethrow;
      }
    };
  }

  static Future<void> Function(Migrator) _reportingOnCreate(
    Future<void> Function(Migrator) fn,
  ) {
    return (m) async {
      try {
        await fn(m);
      } catch (e, s) {
        await log.migration(
          level: Level.SEVERE,
          message: 'drift onCreate failed',
          exception: e,
          stackTrace: s,
        );
        rethrow;
      }
    };
  }

  Future<void> clearCacheTables() async {
    final cacheTables = [transactions];

    for (final table in cacheTables) {
      await delete(table).go();
    }
  }
}
