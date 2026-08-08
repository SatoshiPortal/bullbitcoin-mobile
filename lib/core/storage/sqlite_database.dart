import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/storage/migrations/migrations.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/report.dart';
import 'package:bb_mobile/core/storage/tables/auto_swap.dart';
import 'package:bb_mobile/core/storage/tables/bip85_derivations_table.dart';
import 'package:bb_mobile/core/storage/tables/dismissed_announcements_table.dart';
import 'package:bb_mobile/core/storage/tables/electrum_servers_table.dart';
import 'package:bb_mobile/core/storage/tables/electrum_settings_table.dart';
import 'package:bb_mobile/core/storage/tables/frozen_utxos_table.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/core/storage/tables/order_swaps_table.dart';
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
import 'package:sqlite3/sqlite3.dart' as sqlite;

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
    FrozenUtxos,
    DismissedAnnouncements,
    OrderSwaps,
  ],
)
class SqliteDatabase extends _$SqliteDatabase {
  static const name = 'bullbitcoin_sqlite';

  static Future<DriftIsolate> createIsolateWithSpawn(String key) async {
    final token = RootIsolateToken.instance!;
    return await DriftIsolate.spawn(() {
      BackgroundIsolateBinaryMessenger.ensureInitialized(token);

      return LazyDatabase(() async {
        final dbFolder = await getApplicationDocumentsDirectory();
        final dbPath = p.join(dbFolder.path, '${SqliteDatabase.name}.sqlite');
        return NativeDatabase(
          File(dbPath),
          setup: (database) {
            _setupEncryptedConnection(database, key);
            // busy_timeout MUST be set FIRST so the subsequent
            // `journal_mode = WAL` switch retries (instead of
            // returning `database is locked, errno=261` —
            // SQLITE_BUSY_RECOVERY — and surfacing as the
            // "database is locked (code 261)" the production logs
            // showed) if the main isolate holds the file when this
            // BG-spawned isolate opens it. The busy handler is
            // connection-scoped (sqlite3_busy_timeout) and applies
            // to every operation issued on this connection
            // afterwards, including PRAGMA writes that wait for an
            // exclusive lock to flip journal modes. 2000ms gives
            // 2× headroom over typical FG write durations (<1s);
            // longer values risk wedging this BG isolate behind a
            // hung FG transaction.
            database.execute('PRAGMA busy_timeout = 2000;');
            // With write-ahead logging (WAL) enabled, a single writer
            // and multiple readers can operate on the database in
            // parallel.
            database.execute('PRAGMA journal_mode = WAL;');
            // Maximum durability: fsync before and after every write.
            database.execute('PRAGMA synchronous = FULL;');
          },
        );
      });
    });
  }

  /// Takes an already-built [executor]. There is deliberately no constructor
  /// that opens the on-disk database without a key, so no call site can end
  /// up on a plaintext file.
  SqliteDatabase(super.executor);

  SqliteDatabase.encrypted(String key) : super(_openConnection(key));

  static Future<SqliteDatabase> openEncrypted(String key) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final databaseFile = File(p.join(dbFolder.path, '$name.sqlite'));
    await _encryptExistingDatabase(databaseFile, key);
    return SqliteDatabase.encrypted(key);
  }

  /// Current drift schema version. Bump in lockstep with adding a new
  /// `Schema<N-1>To<N>.migrate` step in [migration] and regenerating the
  /// schema snapshots (`make drift-migrations`).
  static const int currentSchemaVersion = 15;

  @override
  int get schemaVersion => currentSchemaVersion;

  static QueryExecutor _openConnection(String key) {
    return driftDatabase(
      name: name,
      native: DriftNativeOptions(
        databaseDirectory: getApplicationDocumentsDirectory,

        /// When using a shared instance, stream queries synchronize across the two
        /// isolates. Also, drift then manages concurrent access to the database,
        /// preventing "database is locked" errors due to concurrent transactions.
        shareAcrossIsolates: true,
        setup: (database) {
          // Keying runs before every other statement on this connection.
          _setupEncryptedConnection(database as sqlite.Database, key);
          // busy_timeout MUST be set FIRST so subsequent PRAGMA
          // writes that require an exclusive lock (notably
          // `journal_mode = WAL`) retry instead of returning
          // `SQLITE_BUSY_RECOVERY` (extended errno 261 — the
          // "database is locked (code 261)" we saw in production
          // logs) when another isolate or the BG-spawned drift
          // isolate is holding the file. 2000ms is held conservative
          // for the FG path: a UI-thread query blocked on the timeout
          // freezes the app, and the FG `_openConnection` runs at
          // startup before any BG isolate exists so contention here
          // is essentially zero anyway.
          database.execute('PRAGMA busy_timeout = 2000;');
          // With write-ahead logging (WAL) enabled, a single writer and
          // multiple readers can operate on the database in parallel.
          // Required to avoid cross-isolate "database locked" errors.
          database.execute('PRAGMA journal_mode = WAL;');
          // Ensure maximum durability: fsync before and after every write.
          database.execute('PRAGMA synchronous = FULL;');
        },
      ),
    );
  }

  static void _setupEncryptedConnection(sqlite.Database database, String key) {
    if (database.select('PRAGMA cipher;').isEmpty) {
      throw StateError('Encrypted SQLite binary is unavailable');
    }
    database.execute("PRAGMA key = '${_escape(key)}';");
  }

  static Future<void> _encryptExistingDatabase(
    File databaseFile,
    String key,
  ) async {
    final temporary = File('${databaseFile.path}.encryption-tmp');
    final backup = File('${databaseFile.path}.plaintext-backup');
    await _recoverEncryptionMigration(
      databaseFile: databaseFile,
      temporary: temporary,
      backup: backup,
      key: key,
    );

    if (!await databaseFile.exists() ||
        !await _hasPlaintextSqliteHeader(databaseFile)) {
      return;
    }

    final plaintext = sqlite.sqlite3.open(databaseFile.path);
    try {
      plaintext.execute('PRAGMA busy_timeout = 2000;');
      plaintext.execute('PRAGMA wal_checkpoint(TRUNCATE);');
      plaintext.execute("VACUUM INTO '${_escape(temporary.path)}';");
    } finally {
      plaintext.close();
    }

    final encrypted = sqlite.sqlite3.open(temporary.path);
    try {
      if (encrypted.select('PRAGMA cipher;').isEmpty) {
        throw StateError('Encrypted SQLite binary is unavailable');
      }
      encrypted.execute("PRAGMA rekey = '${_escape(key)}';");
    } finally {
      encrypted.close();
    }

    await _verifyEncryptedDatabase(temporary, key);
    for (final suffix in ['-wal', '-shm']) {
      final sidecar = File('${databaseFile.path}$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }
    await databaseFile.rename(backup.path);
    try {
      await temporary.rename(databaseFile.path);
      await _verifyEncryptedDatabase(databaseFile, key);
    } catch (_) {
      if (await databaseFile.exists()) {
        await databaseFile.delete();
      }
      if (await backup.exists()) {
        await backup.rename(databaseFile.path);
      }
      rethrow;
    }
    await backup.delete();
  }

  static Future<void> _recoverEncryptionMigration({
    required File databaseFile,
    required File temporary,
    required File backup,
    required String key,
  }) async {
    final databaseExists = await databaseFile.exists();
    final temporaryExists = await temporary.exists();
    final backupExists = await backup.exists();

    if (!backupExists) {
      if (temporaryExists) {
        if (!databaseExists) {
          throw StateError('Incomplete database encryption migration');
        }
        await temporary.delete();
      }
      return;
    }

    if (databaseExists) {
      if (await _hasPlaintextSqliteHeader(databaseFile)) {
        throw StateError('Incomplete database encryption migration');
      }
      await _verifyEncryptedDatabase(databaseFile, key);
      if (temporaryExists) await temporary.delete();
      await backup.delete();
      return;
    }

    if (temporaryExists) {
      try {
        await _verifyEncryptedDatabase(temporary, key);
        await temporary.rename(databaseFile.path);
        await _verifyEncryptedDatabase(databaseFile, key);
        await backup.delete();
        return;
      } catch (_) {
        if (await databaseFile.exists()) await databaseFile.delete();
        if (await temporary.exists()) await temporary.delete();
      }
    }

    await backup.rename(databaseFile.path);
  }

  static Future<void> _verifyEncryptedDatabase(File file, String key) async {
    final database = sqlite.sqlite3.open(file.path);
    try {
      _setupEncryptedConnection(database, key);
      final result = database.select('PRAGMA quick_check;');
      if (result.length != 1 || result.single.values.single != 'ok') {
        throw StateError('Encrypted database integrity check failed');
      }
    } finally {
      database.close();
    }
  }

  static Future<bool> _hasPlaintextSqliteHeader(File file) async {
    final handle = await file.open();
    try {
      final header = await handle.read(16);
      return utf8.decode(header, allowMalformed: true) ==
          'SQLite format 3\u0000';
    } finally {
      await handle.close();
    }
  }

  static String _escape(String value) => value.replaceAll("'", "''");

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: _reportingOnCreate(Schema0To1.onCreate),
      onUpgrade: stepByStep(
        from1To2: _reportingMigration('from1To2', Schema1To2.migrate),
        from2To3: _reportingMigration('from2To3', Schema2To3.migrate),
        from3To4: _reportingMigration('from3To4', Schema3To4.migrate),
        from4To5: _reportingMigration('from4To5', Schema4To5.migrate),
        from5To6: _reportingMigration('from5To6', Schema5To6.migrate),
        from6To7: _reportingMigration('from6To7', Schema6To7.migrate),
        from7To8: _reportingMigration('from7To8', Schema7To8.migrate),
        from8To9: _reportingMigration('from8To9', Schema8To9.migrate),
        from9To10: _reportingMigration('from9To10', Schema9To10.migrate),
        from10To11: _reportingMigration('from10To11', Schema10To11.migrate),
        from11To12: _reportingMigration('from11To12', Schema11To12.migrate),
        from12To13: _reportingMigration('from12To13', Schema12To13.migrate),
        from13To14: _reportingMigration('from13To14', Schema13To14.migrate),
        from14To15: _reportingMigration('from14To15', Schema14To15.migrate),
      ),
      // Backfills `Report.fromVersion` for installs that predate the
      // `_lastVersionKey` SharedPreferences marker (added in v6.6.0).
      // Drift sets `versionBefore` to the on-disk schema before any
      // step runs, so this fires once on the first launch after a
      // pre-v6.6.0 → v6.6.0+ upgrade and is a no-op otherwise.
      beforeOpen: (details) async {
        if (details.versionBefore != null &&
            details.versionBefore != details.versionNow) {
          Report.recordSchemaUpgrade(from: details.versionBefore!);
        }
      },
    );
  }

  /// Wraps a per-version drift migration step so a failure is surfaced to
  /// Sentry (consent-gated, tagged `category=migration`) before the
  /// rethrow aborts init. Drift migrations run lazily on first query,
  /// so wrapping the step fn (not the constructor) is what actually
  /// catches failures.
  static Future<void> Function(Migrator, Schema) _reportingMigration<Schema>(
    String name,
    Future<void> Function(Migrator, Schema) fn,
  ) {
    return (m, schema) async {
      try {
        await fn(m, schema);
      } catch (e, s) {
        log.severe(
          message: 'drift migration step $name failed',
          error: e,
          trace: s,
          category: ReportCategory.migration,
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
        log.severe(
          message: 'drift onCreate failed',
          error: e,
          trace: s,
          category: ReportCategory.migration,
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
