import 'dart:io';

import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/repositories/ark_account_registry_repository.dart';
import '../domain/ark_failure.dart';
import 'models/ark_account_model.dart';

/// Durable custody references, intentionally more conservative than a balance
/// cache. Turning routing off never deletes a record. A missing existing store
/// refuses inventory, rather than authorizing seed deletion with an empty set.
final class SqliteArkAccountRegistry
    implements ArkAccountRegistryRepository, SeedReferencePort {
  final Database _db;
  bool _closed = false;
  SqliteArkAccountRegistry._(this._db);

  /// Ordinary startup, including foreground, is existing-only. Set
  /// initializeNew only when the host has established this is first setup;
  /// it never overrides an initialized marker whose metadata disappeared.
  static Result<SqliteArkAccountRegistry, ArkFailure> open(
    String path, {
    required bool foreground,
    bool initializeNew = false,
  }) {
    Database? opened;
    try {
      final databaseExists = File(path).existsSync();
      final marker = File('$path.initialized');
      final markerExists = marker.existsSync();
      if ((markerExists &&
              (!databaseExists ||
                  marker.readAsStringSync() != 'ark-accounts:1\n')) ||
          (!markerExists && (!foreground || !initializeNew))) {
        return const Err(ArkFeatureStorageFailure());
      }
      final db = sqlite3.open(
        path,
        mode: foreground ? OpenMode.readWriteCreate : OpenMode.readWrite,
      );
      opened = db;
      db.execute('PRAGMA busy_timeout=0');
      if (db.userVersion == 0 && foreground && initializeNew) {
        if (db
            .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
            )
            .isNotEmpty) {
          db.close();
          opened = null;
          return const Err(ArkFeatureStorageFailure());
        }
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute(
            'CREATE TABLE IF NOT EXISTS ark_accounts (account TEXT PRIMARY KEY,parent TEXT NOT NULL,config TEXT NOT NULL)',
          );
          db.userVersion = 1;
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      } else if (db.userVersion != 1) {
        db.close();
        opened = null;
        return const Err(ArkFeatureStorageFailure());
      }
      if (!markerExists) {
        marker.writeAsStringSync('ark-accounts:1\n', flush: true);
      }
      return Ok(SqliteArkAccountRegistry._(db));
    } on Exception catch (_) {
      opened?.close();
      return const Err(ArkFeatureStorageFailure());
    }
  }

  @override
  Future<Result<void, ArkFailure>> publish(ArkAccountConfig config) async {
    if (_closed) return const Err(ArkFeatureStorageFailure());
    var transaction = false;
    try {
      _db.execute('BEGIN IMMEDIATE');
      transaction = true;
      final model = ArkAccountModel.fromDomain(config);
      final rows = _db.select(
        'SELECT config FROM ark_accounts WHERE account=?',
        [config.id.canonical],
      );
      if (rows.isNotEmpty && rows.single['config'] != model.json) {
        _db.execute('ROLLBACK');
        transaction = false;
        return const Err(ArkInvalidRequestFailure());
      }
      _db.execute(
        'INSERT OR IGNORE INTO ark_accounts(account,parent,config) VALUES(?,?,?)',
        [config.id.canonical, config.id.parent.hex, model.json],
      );
      _db.execute('COMMIT');
      transaction = false;
      return const Ok(null);
    } on Exception catch (_) {
      return const Err(ArkFeatureStorageFailure());
    } finally {
      if (transaction) _db.execute('ROLLBACK');
    }
  }

  @override
  Future<Result<List<ArkAccountConfig>, ArkFailure>> list() async {
    if (_closed) return const Err(ArkFeatureStorageFailure());
    try {
      final accounts = <ArkAccountConfig>[];
      for (final row in _db.select(
        'SELECT account,parent,config FROM ark_accounts ORDER BY account',
      )) {
        final encoded = row['config'];
        if (encoded is! String) return const Err(ArkFeatureStorageFailure());
        final config = ArkAccountModel(encoded).toDomain();
        if (config == null ||
            config.id.canonical != row['account'] ||
            config.id.parent.hex != row['parent']) {
          return const Err(ArkFeatureStorageFailure());
        }
        accounts.add(config);
      }
      return Ok(List.unmodifiable(accounts));
    } on Exception catch (_) {
      return const Err(ArkFeatureStorageFailure());
    }
  }

  @override
  Future<Result<Set<Fingerprint>, Failure>> getCustodyFingerprints() async =>
      (await list()).map(
        (accounts) => accounts.map((c) => c.id.parent).toSet(),
      );
  void close() {
    if (_closed) return;
    _closed = true;
    _db.close();
  }
}
