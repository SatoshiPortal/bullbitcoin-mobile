import 'package:primitives/primitives.dart' show Failure;

/// Why a local database could not be inspected, encrypted, opened or retired.
///
/// No variant carries SQL: the statements that key a connection contain the key.
sealed class SqliteStorageFailure extends Failure {
  const SqliteStorageFailure([super.logMessage]);
}

/// The loaded SQLite library has no cipher. Nothing was opened or created: a database must never be created in clear by a build that lost SQLite3MultipleCiphers.
final class SqliteCipherUnavailableFailure extends SqliteStorageFailure {
  const SqliteCipherUnavailableFailure([super.logMessage]);
}

/// The file did not open with the key it was given: a wrong key, or a file that is not a database. Nothing was changed.
final class SqliteKeyRejectedFailure extends SqliteStorageFailure {
  const SqliteKeyRejectedFailure([super.logMessage]);
}

/// Another connection holds the database. Nothing was changed; retrying later can succeed.
final class SqliteBusyFailure extends SqliteStorageFailure {
  const SqliteBusyFailure([super.logMessage]);
}

/// SQLite reports the database as malformed.
final class SqliteCorruptFailure extends SqliteStorageFailure {
  const SqliteCorruptFailure([super.logMessage]);
}

/// The files on disk do not form a state this package can decide on safely. Nothing was touched; only the owner, with the user's consent, may retire them.
final class SqliteInconsistentFailure extends SqliteStorageFailure {
  const SqliteInconsistentFailure([super.logMessage]);
}

/// A filesystem or SQLite operation failed for another reason (I/O, disk full, permission, a failed durability barrier).
final class SqliteIoFailure extends SqliteStorageFailure {
  const SqliteIoFailure([super.logMessage]);
}
