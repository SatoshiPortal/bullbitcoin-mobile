import 'package:primitives/primitives.dart';

sealed class DatabaseOpenFailure extends Failure {
  const DatabaseOpenFailure();
}

enum DatabaseKeyProblem { locked, missing, corrupt, unavailable }

final class DatabaseKeyUnavailable extends DatabaseOpenFailure {
  final DatabaseKeyProblem reason;

  const DatabaseKeyUnavailable(this.reason);
}

enum DatabaseFileProblem { inconsistent, unreadable, inaccessible }

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
