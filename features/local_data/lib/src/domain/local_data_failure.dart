import 'package:bull_local_data/src/domain/local_database.dart';
import 'package:primitives/primitives.dart' show Failure;

/// Why the local databases could not be opened. Flutter-free; translated in `presentation/`.
sealed class LocalDataFailure extends Failure {
  const LocalDataFailure([super.logMessage]);
}

/// The keystore is sealed until the device is unlocked (iOS, before the first unlock after a boot). The key is very probably there: retry, change nothing.
final class LocalDataKeystoreLockedFailure extends LocalDataFailure {
  const LocalDataKeystoreLockedFailure([super.logMessage]);
}

/// A failure the user can only resolve by resetting [database], with consent.
sealed class LocalDataUnrecoverableFailure extends LocalDataFailure {
  final LocalDatabase database;

  const LocalDataUnrecoverableFailure(this.database, [super.logMessage]);
}

/// [database] is encrypted and its key is not in the keystore after the full retry budget. No key was created.
final class LocalDataKeyMissingFailure extends LocalDataUnrecoverableFailure {
  const LocalDataKeyMissingFailure(super.database, [super.logMessage]);
}

/// The key stored for [database] is present but unusable, and was not replaced.
final class LocalDataKeyCorruptFailure extends LocalDataUnrecoverableFailure {
  const LocalDataKeyCorruptFailure(super.database, [super.logMessage]);
}

/// [database] did not open with its key, or SQLite reports it malformed.
final class LocalDataUnreadableFailure extends LocalDataUnrecoverableFailure {
  const LocalDataUnreadableFailure(super.database, [super.logMessage]);
}

/// The files of [database] are in a state with no safe automatic decision. Nothing was touched.
final class LocalDataInconsistentFailure extends LocalDataUnrecoverableFailure {
  const LocalDataInconsistentFailure(super.database, [super.logMessage]);
}

/// Anything else: a keystore or filesystem error, a busy database, a build without a cipher. Nothing was deleted; the generic startup error applies.
final class LocalDataUnexpectedFailure extends LocalDataFailure {
  const LocalDataUnexpectedFailure([super.logMessage]);
}
