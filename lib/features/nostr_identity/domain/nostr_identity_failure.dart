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
