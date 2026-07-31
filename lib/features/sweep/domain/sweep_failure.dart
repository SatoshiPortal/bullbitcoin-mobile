import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of failures the sweep flow can produce.
///
/// Pure Dart — user-facing messages live in
/// `presentation/sweep_failure_l10n.dart`, so a missing translation is a
/// compile error rather than a leaked dev string.
sealed class SweepFailure extends Failure {
  const SweepFailure([super.logMessage]);
}

// ── Allocation rules (validated before anything is built) ───────────────────

/// No coin was handed to the sweep. Only reachable through a bad deep link.
final class SweepNoInputsFailure extends SweepFailure {
  const SweepNoInputsFailure();
}

/// The allocation form holds no recipient at all.
final class SweepNoRecipientsFailure extends SweepFailure {
  const SweepNoRecipientsFailure();
}

/// A recipient row has no destination address yet.
final class SweepMissingAddressFailure extends SweepFailure {
  const SweepMissingAddressFailure();
}

/// A recipient row has neither an amount nor the "take the remainder" flag.
final class SweepMissingAmountFailure extends SweepFailure {
  const SweepMissingAmountFailure();
}

/// The same address appears on two rows. Merging them silently would change
/// what the user asked for, so it's refused instead.
final class SweepDuplicateAddressFailure extends SweepFailure {
  final String address;

  const SweepDuplicateAddressFailure(this.address);
}

/// More than one row claims the remainder — only one output can drain it.
final class SweepMultipleRemainderFailure extends SweepFailure {
  const SweepMultipleRemainderFailure();
}

/// An address isn't a valid Bitcoin address.
final class SweepInvalidAddressFailure extends SweepFailure {
  final String address;

  const SweepInvalidAddressFailure(this.address);
}

/// The address is valid, but for the wrong network (mainnet vs testnet).
final class SweepWrongNetworkFailure extends SweepFailure {
  final String address;

  const SweepWrongNetworkFailure(this.address);
}

/// An output is small enough that the network would treat it as dust.
final class SweepAmountBelowDustFailure extends SweepFailure {
  final BigInt minimumSat;

  const SweepAmountBelowDustFailure(this.minimumSat);
}

/// The allocated amounts exceed what the selected coins hold.
final class SweepAllocationExceedsBalanceFailure extends SweepFailure {
  final BigInt overspentSat;

  const SweepAllocationExceedsBalanceFailure(this.overspentSat);
}

/// The allocation uses every satoshi, leaving nothing to pay the miner.
final class SweepNoRoomForFeeFailure extends SweepFailure {
  const SweepNoRoomForFeeFailure();
}

// ── Build / sign / broadcast ────────────────────────────────────────────────

/// One or more selected coins are frozen, or reserved by a payjoin session.
///
/// Refused rather than silently dropped: dropping an input would change the
/// total being distributed without the user noticing.
final class SweepUnspendableInputFailure extends SweepFailure {
  final int count;

  const SweepUnspendableInputFailure(this.count);
}

/// The selected coins can't cover the allocation plus the network fee at the
/// chosen rate.
///
/// [shortfallSat] is what's missing when the SDK reported it, and null when it
/// only said "coin selection failed" — the message must stay useful either way,
/// so the translation has a variant for each.
final class SweepInsufficientFundsFailure extends SweepFailure {
  final BigInt? shortfallSat;

  const SweepInsufficientFundsFailure([this.shortfallSat, super.logMessage]);
}

/// The chosen fee rate is below what the network will relay.
final class SweepFeeTooLowFailure extends SweepFailure {
  const SweepFeeTooLowFailure();
}

/// Network fee estimates couldn't be fetched.
final class SweepFeesUnavailableFailure extends SweepFailure {
  const SweepFeesUnavailableFailure([super.logMessage]);
}

/// The wallet's own change addresses couldn't be listed.
final class SweepChangeAddressesUnavailableFailure extends SweepFailure {
  const SweepChangeAddressesUnavailableFailure([super.logMessage]);
}

/// Building the unsigned transaction failed for a reason we don't model.
final class SweepBuildFailure extends SweepFailure {
  const SweepBuildFailure([super.logMessage]);
}

/// Signing failed.
final class SweepSignFailure extends SweepFailure {
  const SweepSignFailure([super.logMessage]);
}

/// The transaction was built and signed but the network refused it.
final class SweepBroadcastFailure extends SweepFailure {
  const SweepBroadcastFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs/Sentry ONLY and MUST never reach the UI.
final class SweepUnexpectedFailure extends SweepFailure {
  const SweepUnexpectedFailure([super.logMessage]);
}
