import 'package:primitives/primitives.dart';

sealed class ArkFailure extends Failure {
  const ArkFailure([super.logMessage]);
}

/// The wallet has not been opened, or was closed.
final class ArkWalletNotOpenFailure extends ArkFailure {
  const ArkWalletNotOpenFailure([super.logMessage]);
}

final class ArkInvalidInputFailure extends ArkFailure {
  const ArkInvalidInputFailure([super.logMessage]);
}

/// bark rejected the call. bark_bitcoin 0.26.1 surfaces every native error as
/// the single variant `ErrorException.inner`, with no message or category, so
/// an unreachable server cannot be told apart from any other refusal.
final class ArkOperationFailure extends ArkFailure {
  const ArkOperationFailure([super.logMessage]);
}

final class ArkUnexpectedFailure extends ArkFailure {
  const ArkUnexpectedFailure([super.logMessage]);
}
