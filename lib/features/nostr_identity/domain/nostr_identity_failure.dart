import 'package:bb_mobile/core/failures/failure.dart';

sealed class NostrIdentityFailure extends Failure {
  const NostrIdentityFailure([super.logMessage]);
}

final class NostrIdentityUnavailableFailure extends NostrIdentityFailure {
  const NostrIdentityUnavailableFailure();
}

final class NostrIdentityInvalidHashFailure extends NostrIdentityFailure {
  const NostrIdentityInvalidHashFailure();
}

/// The words this device can derive belong to another wallet than the one the
/// caller asked about.
///
/// Nothing is wrong with this device: the vault was backed up from a different
/// wallet, and only that wallet's words open its backups.
final class NostrIdentityForeignCredentialFailure extends NostrIdentityFailure {
  const NostrIdentityForeignCredentialFailure();
}
