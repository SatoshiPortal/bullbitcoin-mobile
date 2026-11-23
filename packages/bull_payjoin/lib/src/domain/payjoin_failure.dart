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

/// The sender start failed after its session was persisted and armed: the
/// post to the directory did not go through, and the stored session keeps the
/// signed original. The caller may adopt that session and settle it.
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

final class PayjoinFallbackUnavailableFailure extends PayjoinFailure {
  const PayjoinFallbackUnavailableFailure([super.logMessage]);
}

final class PayjoinUnexpectedFailure extends PayjoinFailure {
  const PayjoinUnexpectedFailure([super.logMessage]);
}

final class PayjoinSpendBlockedFailure extends PayjoinFailure {
  /// The wallet is only busy with another operation: retrying shortly works.
  final bool busy;
  const PayjoinSpendBlockedFailure({this.busy = false});
}

/// The signed original remains reserved after this attempt's POST failed.
final class PayjoinSenderKeptFailure extends PayjoinFailure {
  final String originalTxId;

  const PayjoinSenderKeptFailure(this.originalTxId, [String? logMessage])
    : super(logMessage ?? 'Sender retained after directory publication failed');
}

/// The signed original may have reached a relay. Do not start a new payment
/// or immediately broadcast a fallback; the durable session must settle it.
final class PayjoinPublicationUnknownFailure extends PayjoinFailure {
  final String originalTxId;

  const PayjoinPublicationUnknownFailure(this.originalTxId);
}
