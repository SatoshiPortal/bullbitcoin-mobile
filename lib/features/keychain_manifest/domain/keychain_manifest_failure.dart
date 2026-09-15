import 'package:primitives/primitives.dart';

sealed class KeychainManifestFailure extends Failure {
  const KeychainManifestFailure();
}

final class KeychainManifestMalformedFileFailure
    extends KeychainManifestFailure {
  const KeychainManifestMalformedFileFailure();
}

final class KeychainManifestUnsupportedVersionFailure
    extends KeychainManifestFailure {
  final int version;

  const KeychainManifestUnsupportedVersionFailure(this.version);
}

final class KeychainManifestParentMismatchFailure
    extends KeychainManifestFailure {
  const KeychainManifestParentMismatchFailure();
}

final class KeychainManifestUnknownReservationFailure
    extends KeychainManifestFailure {
  const KeychainManifestUnknownReservationFailure();
}

final class KeychainManifestEmptyFailure extends KeychainManifestFailure {
  const KeychainManifestEmptyFailure();
}

final class KeychainManifestConflictFailure extends KeychainManifestFailure {
  const KeychainManifestConflictFailure();
}

final class KeychainManifestStorageFailure extends KeychainManifestFailure {
  const KeychainManifestStorageFailure();
}

final class KeychainManifestSeedFailure extends KeychainManifestFailure {
  const KeychainManifestSeedFailure();
}

final class KeychainManifestDerivationFailure extends KeychainManifestFailure {
  const KeychainManifestDerivationFailure();
}

final class KeychainManifestUnexpectedFailure extends KeychainManifestFailure {
  const KeychainManifestUnexpectedFailure();
}
