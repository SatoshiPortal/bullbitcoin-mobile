import 'package:primitives/primitives.dart';

sealed class PayjoinFailure extends Failure {
  const PayjoinFailure([super.logMessage]);
}

final class PayjoinInvalidInputFailure extends PayjoinFailure {
  const PayjoinInvalidInputFailure([super.logMessage]);
}

final class PayjoinUnavailableFailure extends PayjoinFailure {
  const PayjoinUnavailableFailure([super.logMessage]);
}

final class PayjoinWalletUnavailableFailure extends PayjoinFailure {
  const PayjoinWalletUnavailableFailure([super.logMessage]);
}

final class PayjoinRelayUnavailableFailure extends PayjoinFailure {
  const PayjoinRelayUnavailableFailure([super.logMessage]);
}

final class PayjoinProtocolRejectedFailure extends PayjoinFailure {
  const PayjoinProtocolRejectedFailure([super.logMessage]);
}

final class PayjoinSessionNotFoundFailure extends PayjoinFailure {
  const PayjoinSessionNotFoundFailure([super.logMessage]);
}

final class PayjoinInvalidSessionTransitionFailure extends PayjoinFailure {
  const PayjoinInvalidSessionTransitionFailure([super.logMessage]);
}

final class PayjoinStorageFailure extends PayjoinFailure {
  const PayjoinStorageFailure([super.logMessage]);
}

final class PayjoinMigrationFailure extends PayjoinFailure {
  const PayjoinMigrationFailure([super.logMessage]);
}

final class PayjoinSigningFailure extends PayjoinFailure {
  const PayjoinSigningFailure([super.logMessage]);
}

final class PayjoinBroadcastFailure extends PayjoinFailure {
  const PayjoinBroadcastFailure([super.logMessage]);
}

final class PayjoinUnexpectedFailure extends PayjoinFailure {
  const PayjoinUnexpectedFailure([super.logMessage]);
}
