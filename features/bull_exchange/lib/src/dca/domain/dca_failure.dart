import 'package:primitives/primitives.dart' show Failure;

/// Every variant's [Failure.logMessage] is a short, fixed breadcrumb naming
/// the step that failed — never the raw exception text and never an
/// identifier. Log only safe types and codes at the boundary.
sealed class DcaFailure extends Failure {
  const DcaFailure([super.logMessage]);
}

/// The exchange account summary could not be loaded, so the flow cannot
/// start (no balances, no currency, no default lightning address).
///
/// Also covers an unavailable or unsupported Exchange session.
final class DcaAccountUnavailableFailure extends DcaFailure {
  const DcaAccountUnavailableFailure([super.logMessage]);
}

/// Lightning was selected as the receive network but no lightning address
/// was provided. Defensive: the wallet-selection screen validates this
/// before the use-case runs.
final class DcaLightningAddressRequiredFailure extends DcaFailure {
  const DcaLightningAddressRequiredFailure();
}

/// Bitcoin or Liquid was selected but no payout address was given (neither
/// the exchange default wallet nor a typed address). Defensive: the
/// wallet-selection screen only continues with an address.
final class DcaDestinationAddressRequiredFailure extends DcaFailure {
  const DcaDestinationAddressRequiredFailure();
}

/// The exchange rejected the DCA order itself.
final class DcaOrderCreationFailure extends DcaFailure {
  const DcaOrderCreationFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is a breadcrumb for logs ONLY and MUST never
/// reach the UI — the presentation extension returns the shared generic
/// string.
final class DcaUnexpectedFailure extends DcaFailure {
  const DcaUnexpectedFailure([super.logMessage]);
}
