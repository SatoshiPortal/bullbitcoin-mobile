import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of every failure the Silent Payments feature surfaces to the
/// user. `sealed` keeps it closed (exhaustive switches; no foreign variants).
/// Pure Dart: the user-facing message lives in the presentation extension
/// `presentation/sp_failure_l10n.dart`, never here. [Failure.logMessage] is for
/// logs ONLY and MUST never reach the UI.
sealed class SpFailure extends Failure {
  const SpFailure([super.logMessage]);
}

/// Setup/load gate: Silent Payments needs superuser mode enabled.
final class SpRequiresSuperuser extends SpFailure {
  const SpRequiresSuperuser([super.logMessage]);
}

/// Setup/load gate: Silent Payments needs developer mode enabled.
final class SpRequiresDevMode extends SpFailure {
  const SpRequiresDevMode([super.logMessage]);
}

/// No wallet is set up (revoked, no stored config, or no session).
final class SpNotSetUp extends SpFailure {
  const SpNotSetUp([super.logMessage]);
}

/// A wallet is already set up; a second setup is refused.
final class SpAlreadySetUp extends SpFailure {
  const SpAlreadySetUp([super.logMessage]);
}

/// The session is tearing down / the inner lock is still held. Mapped from the
/// bwk "dispose timed out" signal at the adapter boundary.
final class SpSessionBusy extends SpFailure {
  const SpSessionBusy([super.logMessage]);
}

/// A scan is already running. Mapped from the bwk "scanner already running"
/// signal at the adapter boundary.
final class SpScanBusy extends SpFailure {
  const SpScanBusy([super.logMessage]);
}

/// The coin set drifted from the confirmed simulation, so the pinned tx can no
/// longer be built. Mapped from the bwk "inputs changed" signal at the adapter
/// boundary.
final class SpSimulationDrifted extends SpFailure {
  const SpSimulationDrifted([super.logMessage]);
}

/// A backend (blindbit / electrum) could not be reached.
final class SpBackendUnreachable extends SpFailure {
  const SpBackendUnreachable([super.logMessage]);
}

/// The stored / chosen backend config is invalid (corrupt JSON, unknown
/// network, or a missing default URL).
final class SpConfigInvalid extends SpFailure {
  const SpConfigInvalid([super.logMessage]);
}

/// Clearing the stale on-disk state of a previously revoked wallet failed, so
/// setup cannot proceed.
final class SpSetupCleanupFailed extends SpFailure {
  const SpSetupCleanupFailed([super.logMessage]);
}

/// Send input: the amount must be greater than zero.
final class SpAmountBelowMinimum extends SpFailure {
  const SpAmountBelowMinimum([super.logMessage]);
}

/// Send input: the amount exceeds the available balance.
final class SpAmountExceedsBalance extends SpFailure {
  const SpAmountExceedsBalance([super.logMessage]);
}

/// Send input: the silent payment address is for a different network than the
/// wallet.
final class SpAddressNetworkMismatch extends SpFailure {
  const SpAddressNetworkMismatch([super.logMessage]);
}

/// Catch-all. [Failure.logMessage] is for logs ONLY and MUST never reach the
/// UI; the presentation extension returns the shared generic string.
final class SpUnexpected extends SpFailure {
  const SpUnexpected([super.logMessage]);
}
