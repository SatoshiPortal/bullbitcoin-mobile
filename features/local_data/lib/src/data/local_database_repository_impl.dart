import 'package:bull_local_data/src/domain/local_data_failure.dart';
import 'package:bull_local_data/src/domain/local_database.dart';
import 'package:bull_local_data/src/domain/local_database_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sqlite/bull_sqlite.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// The key policy of the app's local databases, over `secrets` (keys) and `bull_sqlite` (files).
///
/// The one rule that matters: a key is created only when no encrypted data exists for it. Whether data exists is read from the files, never inferred from a missing key — `flutter_secure_storage` can report a key absent when it is not, and a key created over existing data would open nothing.
final class LocalDatabaseRepositoryImpl implements LocalDatabaseRepository {
  final Secrets _secrets;
  final LocalDatabasePaths _paths;

  LocalDatabaseRepositoryImpl({required this._secrets, required this._paths});

  /// The keystore names of each database's key, under `com.bullbitcoin.secrets/dek/<module>/<name>`. Persisted: never rename.
  static ({String module, String name}) _keyOf(LocalDatabase database) =>
      switch (database) {
        LocalDatabase.main => (module: 'bb_mobile', name: 'bullbitcoin_sqlite'),
        LocalDatabase.payjoin => (module: 'bull_payjoin', name: 'payjoin'),
      };

  DatabaseKeys _keys(LocalDatabase database) =>
      _secrets.databaseKeys(module: _keyOf(database).module);

  @override
  Future<Result<UnlockedDatabase, LocalDataFailure>> unlock(
    LocalDatabase database,
  ) async {
    final path = _paths.of(database);
    final name = _keyOf(database).name;
    final keys = _keys(database);

    // A reset the user consented to and a crash interrupted: its files are deleted as decided. Its key, if still there, is reused for the new database, which is harmless: nothing it encrypted remains.
    if (EncryptedSqlite.resumeRetirement(path) case Err(:final failure)) {
      return Err(_fromStorage(database, failure));
    }

    final SqliteFileState state;
    switch (EncryptedSqlite.inspect(path)) {
      case Ok(:final value):
        state = value;
      case Err(:final failure):
        return Err(_fromStorage(database, failure));
    }

    switch (state) {
      case SqliteFileState.inconsistent:
        log.warning('Local database ${database.name}: inconsistent files');
        return Err(LocalDataInconsistentFailure(database));

      case SqliteFileState.possiblyEncrypted:
        // Encrypted data exists: its key is read, never created.
        final DatabaseKey key;
        switch (await keys.get(name: name)) {
          case Ok(:final value):
            key = value;
          case Err(:final failure):
            return Err(_fromKeystore(database, failure, existing: true));
        }
        return _probed(database, path, key);

      case SqliteFileState.absent ||
          SqliteFileState.empty ||
          SqliteFileState.plaintext:
        final DatabaseKey key;
        switch (await _createdKey(database, keys, name)) {
          case Ok(:final value):
            key = value;
          case Err(:final failure):
            return Err(failure);
        }
        if (state != SqliteFileState.plaintext) {
          return Ok(UnlockedDatabase(database: database, path: path, key: key));
        }
        log.fine('Local database ${database.name}: encrypting');
        if (await EncryptedSqlite.encrypt(path, key) case Err(:final failure)) {
          return _healedOr(database, path, key, failure);
        }
        log.fine('Local database ${database.name}: encrypted');
        return _probed(database, path, key);
    }
  }

  /// A key the keystore holds and reads back: the key that will encrypt is the one a later start will read.
  Future<Result<DatabaseKey, LocalDataFailure>> _createdKey(
    LocalDatabase database,
    DatabaseKeys keys,
    String name,
  ) async {
    final DatabaseKey created;
    switch (await keys.getOrCreate(name: name)) {
      case Ok(:final value):
        created = value;
      case Err(:final failure):
        return Err(_fromKeystore(database, failure, existing: false));
    }
    switch (await keys.get(name: name)) {
      case Ok(:final value) when value.hex == created.hex:
        return Ok(created);
      case Ok():
        log.severe(
          message: 'Local database ${database.name}: key changed on read-back',
          error: 'KeyMismatch',
          trace: StackTrace.current,
        );
        return const Err(
          LocalDataUnexpectedFailure('key changed on read-back'),
        );
      case Err(:final failure):
        return Err(_fromKeystore(database, failure, existing: false));
    }
  }

  Result<UnlockedDatabase, LocalDataFailure> _probed(
    LocalDatabase database,
    String path,
    DatabaseKey key,
  ) => switch (EncryptedSqlite.probe(path, key)) {
    Ok() => Ok(UnlockedDatabase(database: database, path: path, key: key)),
    Err(:final failure) => _healedOr(database, path, key, failure),
  };

  /// Payjoin's own policy for storage SQLite reports corrupt: move it aside, whole, and start a fresh database (the runtime re-imports the legacy rows). Without it, a corrupt Payjoin file would keep the whole app on a recovery screen, while Payjoin itself would have healed. Every other failure, and any failure of the main database, is the caller's.
  Result<UnlockedDatabase, LocalDataFailure> _healedOr(
    LocalDatabase database,
    String path,
    DatabaseKey key,
    SqliteStorageFailure failure,
  ) {
    if (database != LocalDatabase.payjoin || failure is! SqliteCorruptFailure) {
      return Err(_fromStorage(database, failure));
    }
    log.warning('Local database ${database.name}: corrupt, moved aside');
    final suffix =
        '.unreadable-${DateTime.now().toUtc().millisecondsSinceEpoch}';
    return switch (EncryptedSqlite.retire(
      path,
      Retirement.quarantine(suffix),
    )) {
      Ok() => Ok(UnlockedDatabase(database: database, path: path, key: key)),
      Err(failure: final retirement) => Err(_fromStorage(database, retirement)),
    };
  }

  @override
  Future<Result<void, LocalDataFailure>> reset(LocalDatabase database) async {
    log.warning('Local database ${database.name}: reset at the user request');
    final path = _paths.of(database);
    // Files first, behind a durable marker; the key last, so that an interruption never leaves encrypted data without its key.
    if (EncryptedSqlite.retire(path, const Retirement.delete()) case Err(
      :final failure,
    )) {
      return Err(_fromStorage(database, failure));
    }
    if (await _keys(database).reset(name: _keyOf(database).name) case Err(
      :final failure,
    )) {
      log.warning(
        'Local database ${database.name}: key reset failed: $failure',
      );
      return Err(LocalDataUnexpectedFailure('$failure'));
    }
    return const Ok(null);
  }

  /// [existing]: the key belongs to a database that exists encrypted, so its absence is a missing key, not a first start.
  static LocalDataFailure _fromKeystore(
    LocalDatabase database,
    SecretFailure failure, {
    required bool existing,
  }) {
    log.warning('Local database ${database.name}: key unavailable: $failure');
    return switch (failure) {
      KeystoreLockedFailure() => const LocalDataKeystoreLockedFailure(),
      SecretNotFoundFailure() when existing => LocalDataKeyMissingFailure(
        database,
      ),
      DatabaseKeyCorruptFailure() => LocalDataKeyCorruptFailure(database),
      _ => LocalDataUnexpectedFailure('$failure'),
    };
  }

  static LocalDataFailure _fromStorage(
    LocalDatabase database,
    SqliteStorageFailure failure,
  ) {
    log.warning(
      'Local database ${database.name}: $failure ${failure.logMessage ?? ''}',
    );
    return switch (failure) {
      SqliteKeyRejectedFailure() ||
      SqliteCorruptFailure() => LocalDataUnreadableFailure(database),
      SqliteInconsistentFailure() => LocalDataInconsistentFailure(database),
      SqliteBusyFailure() ||
      SqliteIoFailure() ||
      SqliteCipherUnavailableFailure() => LocalDataUnexpectedFailure(
        '$failure',
      ),
    };
  }
}
