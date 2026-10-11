import 'package:bb_mobile/core/failures/failure.dart';

sealed class KeychainManifestFailure extends Failure {
  const KeychainManifestFailure();
}

final class KeychainManifestStorageFailure extends KeychainManifestFailure {
  const KeychainManifestStorageFailure();
}

final class KeychainManifestSeedFailure extends KeychainManifestFailure {
  const KeychainManifestSeedFailure();
}

final class KeychainManifestInvalidKeyFailure extends KeychainManifestFailure {
  const KeychainManifestInvalidKeyFailure();
}
