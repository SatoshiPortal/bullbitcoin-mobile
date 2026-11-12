import 'package:bull_sqlite/src/exceptions.dart';
import 'package:primitives/primitives.dart' show DatabaseKey;
import 'package:sqlite3/sqlite3.dart';

/// Keys one SQLite connection, before anything else runs on it.
///
/// SQLite3MultipleCiphers, selected by the `sqlite3` build hook in the root `pubspec.yaml`. The cipher is named rather than left to the library default, so a change of default in a later release cannot make existing databases unreadable. The key is raw (`x'…'`): it is already 32 random bytes, and a passphrase would cost a key derivation on every open.
abstract final class SqliteCipher {
  /// ChaCha20-Poly1305, SQLite3MultipleCiphers' default at 2.x.
  static const cipher = 'chacha20';

  /// Keys [database], then checks that the key opens it.
  ///
  /// `PRAGMA key` answers `ok` whatever the key: the only proof is a read. A rejected key or a file that is not a database throws [KeyRejectedException]; a library without a cipher throws [CipherUnavailableException] before the key is ever written into a statement.
  ///
  /// Never lets a [SqliteException] out: its `causingStatement` would carry the key.
  static void key(Database database, DatabaseKey key) {
    try {
      // A plain SQLite build ignores the pragma and returns no row.
      if (database.select('PRAGMA cipher;').isEmpty) {
        throw const CipherUnavailableException();
      }
      database.execute("PRAGMA cipher = '$cipher';");
      database.execute('PRAGMA key = "${key.pragma}";');
      database.select('SELECT count(*) FROM sqlite_master;');
    } on SqliteException catch (e) {
      throw SqliteFailedException.from(e);
    }
  }

  /// Encrypts a plaintext database with [key]. The connection must not be in WAL mode (a SQLite3MultipleCiphers rule for encrypting a plain database).
  static void rekey(Database database, DatabaseKey key) {
    try {
      if (database.select('PRAGMA cipher;').isEmpty) {
        throw const CipherUnavailableException();
      }
      database.execute("PRAGMA cipher = '$cipher';");
      database.execute('PRAGMA rekey = "${key.pragma}";');
    } on SqliteException catch (e) {
      throw SqliteFailedException.from(e);
    }
  }

  /// Keys [database] and applies the connection settings every local database uses: a busy timeout set first so the WAL switch retries rather than failing on a lock, write-ahead logging, and the given durability.
  ///
  /// The setup callback for drift executors, foreground or background.
  static void configure(
    Database database,
    DatabaseKey key, {
    required bool fullSync,
  }) {
    try {
      database.execute('PRAGMA busy_timeout = 2000;');
    } on SqliteException catch (e) {
      throw SqliteFailedException.from(e);
    }
    SqliteCipher.key(database, key);
    try {
      database.execute('PRAGMA journal_mode = WAL;');
      database.execute('PRAGMA synchronous = ${fullSync ? 'FULL' : 'NORMAL'};');
    } on SqliteException catch (e) {
      throw SqliteFailedException.from(e);
    }
  }
}
