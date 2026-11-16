import 'package:primitives/primitives.dart' show Failure;

sealed class NostrIdentityFailure extends Failure {
  const NostrIdentityFailure();
}

final class BackupCredentialUnavailable extends NostrIdentityFailure {
  const BackupCredentialUnavailable();
}

final class InvalidDataRecoveryWords extends NostrIdentityFailure {
  const InvalidDataRecoveryWords();
}
