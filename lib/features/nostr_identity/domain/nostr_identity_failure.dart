import 'package:bb_mobile/core/failures/failure.dart';

sealed class NostrIdentityFailure extends Failure {
  const NostrIdentityFailure([super.logMessage]);
}

final class NostrIdentityNoDefaultWalletFailure extends NostrIdentityFailure {
  const NostrIdentityNoDefaultWalletFailure();
}

final class NostrIdentityAmbiguousDefaultWalletFailure
    extends NostrIdentityFailure {
  const NostrIdentityAmbiguousDefaultWalletFailure();
}

final class NostrIdentityWalletLookupFailure extends NostrIdentityFailure {
  const NostrIdentityWalletLookupFailure();
}

final class NostrIdentitySeedUnavailableFailure extends NostrIdentityFailure {
  const NostrIdentitySeedUnavailableFailure();
}

final class NostrIdentityFingerprintMismatchFailure
    extends NostrIdentityFailure {
  const NostrIdentityFingerprintMismatchFailure();
}

final class NostrIdentityInvalidHashFailure extends NostrIdentityFailure {
  const NostrIdentityInvalidHashFailure();
}
