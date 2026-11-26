import 'package:primitives/primitives.dart' show Failure;

/// Closed set of every failure the Silent Payments feature surfaces to the
/// user. `sealed` keeps it closed (exhaustive switches; no foreign variants).
/// Pure Dart: the user-facing message lives in the presentation extension
/// `presentation/sp_failure_l10n.dart`, never here. [Failure.logMessage] is for
/// logs ONLY and MUST never reach the UI.
sealed class SilentFailure extends Failure {
  const SilentFailure([super.logMessage]);
}

/// Setup/load gate: Silent Payments needs superuser mode enabled.
final class SilentRequiresSuperuser extends SilentFailure {
  const SilentRequiresSuperuser([super.logMessage]);
}

/// Setup/load gate: Silent Payments needs developer mode enabled.
final class SilentRequiresDevMode extends SilentFailure {
  const SilentRequiresDevMode([super.logMessage]);
}

/// No wallet is set up (revoked, no stored config, or no session).
final class SilentNotSetUp extends SilentFailure {
  const SilentNotSetUp([super.logMessage]);
}

/// A wallet is already set up; a second setup is refused.
final class SilentAlreadySetUp extends SilentFailure {
  const SilentAlreadySetUp([super.logMessage]);
}

/// The session is tearing down / the inner lock is still held. Mapped from the
/// bwk "dispose timed out" signal at the adapter boundary.
final class SilentSessionBusy extends SilentFailure {
  const SilentSessionBusy([super.logMessage]);
}

/// A scan is already running. Mapped from the bwk "scanner already running"
/// signal at the adapter boundary.
final class SilentScanBusy extends SilentFailure {
  const SilentScanBusy([super.logMessage]);
}

/// The coin set drifted from the confirmed simulation, so the pinned tx can no
/// longer be built. Mapped from the bwk "inputs changed" signal at the adapter
/// boundary.
final class SilentSimulationDrifted extends SilentFailure {
  const SilentSimulationDrifted([super.logMessage]);
}

/// A backend (blindbit / electrum) could not be reached.
final class SilentBackendUnreachable extends SilentFailure {
  const SilentBackendUnreachable([super.logMessage]);
}

/// The stored / chosen backend config is invalid (corrupt JSON, unknown
/// network, or a missing default URL).
final class SilentConfigInvalid extends SilentFailure {
  const SilentConfigInvalid([super.logMessage]);
}

/// Clearing the stale on-disk state of a previously revoked wallet failed, so
/// setup cannot proceed.
final class SilentSetupCleanupFailed extends SilentFailure {
  const SilentSetupCleanupFailed([super.logMessage]);
}

/// A backend update failed and the previous configuration or session could
/// not be restored.
final class SilentBackendRollbackFailed extends SilentFailure {
  const SilentBackendRollbackFailed() : super('SP backend rollback failed');
}

/// Send input: the amount must be greater than zero.
final class SilentAmountBelowMinimum extends SilentFailure {
  const SilentAmountBelowMinimum([super.logMessage]);
}

/// Send input: the amount exceeds the available balance.
final class SilentAmountExceedsBalance extends SilentFailure {
  const SilentAmountExceedsBalance([super.logMessage]);
}

/// Send input: the silent payment address is for a different network than the
/// wallet.
final class SilentAddressNetworkMismatch extends SilentFailure {
  const SilentAddressNetworkMismatch([super.logMessage]);
}

/// Send input: the recipient is neither a bitcoin address nor a silent payment
/// address.
final class SilentInvalidAddress extends SilentFailure {
  const SilentInvalidAddress([super.logMessage]);
}

/// The broadcast outcome is unknown: the transaction may or may not have been
/// sent, so the user must check before retrying.
final class SilentBroadcastUncertain extends SilentFailure {
  const SilentBroadcastUncertain([super.logMessage]);
}

/// Catch-all. [Failure.logMessage] is for logs ONLY and MUST never reach the
/// UI; the presentation extension returns the shared generic string.
final class SilentUnexpected extends SilentFailure {
  const SilentUnexpected([super.logMessage]);
}

/// Silent Payments is unavailable on the selected concrete network.
final class SilentUnsupportedNetwork extends SilentFailure {
  const SilentUnsupportedNetwork() : super('SP network unsupported');
}
