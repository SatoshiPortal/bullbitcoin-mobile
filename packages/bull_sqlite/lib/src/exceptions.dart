import 'package:sqlite3/sqlite3.dart';

/// Thrown inside this package and turned into a failure at its boundary (`EncryptedSqlite`). None carries SQL or a foreign message: the statements that key a connection contain the key, and a library message can quote its input.
sealed class SqliteStorageException implements Exception {
  const SqliteStorageException();
}

final class CipherUnavailableException extends SqliteStorageException {
  const CipherUnavailableException();

  @override
  String toString() => 'CipherUnavailableException';
}

/// The family of files is in a state this package does not decide on. [reason] is one of this package's fixed strings.
final class InconsistentFamilyException extends SqliteStorageException {
  final String reason;

  const InconsistentFamilyException(this.reason);

  @override
  String toString() => 'InconsistentFamilyException: $reason';
}

/// The encryption of a plaintext database stopped before publication; the plaintext database is unchanged. [reason] is one of this package's fixed strings.
final class MigrationAbortedException extends SqliteStorageException {
  final String reason;

  const MigrationAbortedException(this.reason);

  @override
  String toString() => 'MigrationAbortedException: $reason';
}

/// A SQLite error, reduced to its result code.
final class SqliteFailedException extends SqliteStorageException {
  final int extendedResultCode;

  const SqliteFailedException(this.extendedResultCode);

  /// Keeps the code only: `causingStatement` may contain the key, and `message` may quote stored content.
  factory SqliteFailedException.from(SqliteException e) =>
      e.extendedResultCode & 0xFF == sqliteNotADatabase
      ? const KeyRejectedException()
      : SqliteFailedException(e.extendedResultCode);

  int get resultCode => extendedResultCode & 0xFF;

  @override
  String toString() => 'SqliteFailedException($extendedResultCode)';
}

/// Same meaning as [SqliteFailedException] with `SQLITE_NOTADB`: kept apart because callers decide on it.
final class KeyRejectedException extends SqliteFailedException {
  const KeyRejectedException() : super(sqliteNotADatabase);

  @override
  String toString() => 'KeyRejectedException';
}

const sqliteBusy = 5;
const sqliteLocked = 6;
const sqliteCorrupt = 11;
const sqliteNotADatabase = 26;
