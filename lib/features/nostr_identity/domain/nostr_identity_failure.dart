import 'package:bb_mobile/core/failures/failure.dart';

sealed class NostrIdentityFailure extends Failure {
  const NostrIdentityFailure();
}

final class BackupCredentialUnavailable extends NostrIdentityFailure {
  const BackupCredentialUnavailable();
}

final class InvalidDataRecoveryWords extends NostrIdentityFailure {
  const InvalidDataRecoveryWords();
}
