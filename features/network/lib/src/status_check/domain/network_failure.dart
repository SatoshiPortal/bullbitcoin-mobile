import 'package:primitives/primitives.dart' show Failure;

sealed class NetworkFailure extends Failure {
  const NetworkFailure();
}

final class NoDefaultWalletFailure extends NetworkFailure {
  const NoDefaultWalletFailure();
}

final class NetworkUnexpectedFailure extends NetworkFailure {
  const NetworkUnexpectedFailure();
}

/// The caller closed the session or started a newer check.
final class StatusCheckInterruptedFailure extends NetworkFailure {
  const StatusCheckInterruptedFailure();
}
