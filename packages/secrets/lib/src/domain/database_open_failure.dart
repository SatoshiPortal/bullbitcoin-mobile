import 'package:primitives/primitives.dart';

sealed class DatabaseOpenFailure extends Failure {
  const DatabaseOpenFailure();
}

enum DatabaseKeyProblem { locked, missing, corrupt, unavailable }

final class DatabaseKeyUnavailable extends DatabaseOpenFailure {
  final DatabaseKeyProblem reason;

  const DatabaseKeyUnavailable(this.reason);
}

/// Why an existing database file could not be opened.
///
/// [unreadable] is the only cause that points at the file's content: the
/// engine rejected the bytes as not a database or as damaged. [schemaMismatch]
/// is a file written by a newer schema than this build supports. [contended]
/// is another connection holding the file. [missing] is a file that was
/// admitted and is no longer there, alone or with only a sidecar left. Every other access error, such as a
/// refused permission, is [inaccessible]; none of those says the file is
/// damaged, and none may justify replacing it.
enum DatabaseFileProblem {
  inconsistent,
  unreadable,
  inaccessible,
  schemaMismatch,
  contended,
  missing,
}

final class DatabaseFileUnavailable extends DatabaseOpenFailure {
  final DatabaseFileProblem reason;

  const DatabaseFileUnavailable(this.reason);
}

final class DatabaseCipherUnavailable extends DatabaseOpenFailure {
  const DatabaseCipherUnavailable();
}

final class DatabaseNotReady extends DatabaseOpenFailure {
  const DatabaseNotReady();
}
