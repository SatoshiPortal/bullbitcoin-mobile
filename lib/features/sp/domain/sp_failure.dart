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
/// longer be sent. Mapped from bwk's `SimulationDrifted`, which the account's
/// finalize reports, at the adapter boundary.
final class SpSimulationDrifted extends SpFailure {
  const SpSimulationDrifted([super.logMessage]);
}

/// Setup/load gate: no default Bitcoin wallet exists for the network the SP
/// wallet runs on, so there is no secret to derive its scan credential from.
final class SpNoDefaultWallet extends SpFailure {
  const SpNoDefaultWallet([super.logMessage]);
}

/// The device keystore is locked (or otherwise unreadable right now), so the
/// wallet's secret cannot be used. Retrying after unlocking may succeed.
final class SpKeystoreLocked extends SpFailure {
  const SpKeystoreLocked([super.logMessage]);
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

/// A backend URL names a Tor `.onion` host. The SP client has no Tor route, so
/// it could never reach it, and resolving the name would hand it to the
/// network's DNS resolver.
final class SpBackendOnionUnsupported extends SpFailure {
  const SpBackendOnionUnsupported([super.logMessage]);
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

/// Send input: the recipient is neither a bitcoin address nor a silent payment
/// address.
final class SpInvalidAddress extends SpFailure {
  const SpInvalidAddress([super.logMessage]);
}

/// Send: the wallet holds more coins than automatic coin selection can search.
/// A max send to an own address merges them.
final class SpTooManyCoins extends SpFailure {
  final int count;
  final int max;

  const SpTooManyCoins({
    required this.count,
    required this.max,
    String? logMessage,
  }) : super(logMessage);
}

/// Send max: what remains after the network fee is below the dust limit.
final class SpNothingToSendAfterFee extends SpFailure {
  const SpNothingToSendAfterFee([super.logMessage]);
}

/// The broadcast outcome is unknown: the transaction may or may not have been
/// sent, so the user must check before retrying.
final class SpBroadcastUncertain extends SpFailure {
  const SpBroadcastUncertain([super.logMessage]);
}

/// The signed transaction differs from the confirmed simulation (inputs,
/// outputs, amounts or fee, or change the receiving path does not recognise),
/// so it was not broadcast. Mapped from bwk's `SignedPsbtMismatch` and from
/// the app's own check of the extracted transaction. Nothing was sent; the user can review
/// the payment and try again.
final class SpSignedTransactionMismatch extends SpFailure {
  const SpSignedTransactionMismatch([super.logMessage]);
}

/// The watch-only account refused the descriptors derived from the default
/// wallet (a malformed credential, or one for another network), so it was not
/// opened. Mapped from bwk's `InvalidDescriptor`.
final class SpCredentialRefused extends SpFailure {
  const SpCredentialRefused([super.logMessage]);
}

/// The signer refused the prepared transaction (an input the wallet's keys do
/// not own, an unsupported script, a transaction already signed), so nothing
/// was signed or sent.
final class SpSigningRefused extends SpFailure {
  const SpSigningRefused([super.logMessage]);
}

/// The signed transaction failed the account's silent payments verification
/// (BIP375 shares, DLEQ proofs, output scripts) or its signature checks, so
/// it was not extracted and nothing was sent. Mapped from bwk's
/// `Verification`.
final class SpVerificationFailed extends SpFailure {
  const SpVerificationFailed([super.logMessage]);
}

/// Catch-all. [Failure.logMessage] is for logs ONLY and MUST never reach the
/// UI; the presentation extension returns the shared generic string.
final class SpUnexpected extends SpFailure {
  const SpUnexpected([super.logMessage]);
}
