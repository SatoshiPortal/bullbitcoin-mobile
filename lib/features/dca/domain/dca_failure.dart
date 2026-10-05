import 'package:bb_mobile/core/failures/failure.dart';

/// Every variant's [Failure.logMessage] is a short, fixed breadcrumb naming
/// the step that failed — never the raw exception text and never an
/// identifier. The raw reason is passed to `log.*` at the boundary instead,
/// which is the single sink allowed to carry it (local log file and, for
/// `log.severe`, Sentry). This keeps a foreign SDK's message — which can
/// embed a response body or a credential — out of an object that is stored
/// in bloc state.
sealed class DcaFailure extends Failure {
  const DcaFailure([super.logMessage]);
}

/// The exchange account summary could not be loaded, so the flow cannot
/// start (no balances, no currency, no default lightning address).
///
/// Deliberately coarse: it also covers not-logged-in (the core repository
/// returns null rather than throwing when no API key is stored) and a lost
/// connection. Splitting a connectivity variant out is not possible from
/// here — `ExchangeUserRepositoryImpl` stringifies every cause into
/// `Exception('Failed to fetch user summary: $e')`, so no typed exception
/// survives to be classified. The user-facing string is worded to fit all
/// three causes; the split becomes possible once that core repository
/// returns a `Result` (#1895 core phase).
final class DcaAccountUnavailableFailure extends DcaFailure {
  const DcaAccountUnavailableFailure([super.logMessage]);
}

/// Lightning was selected as the receive network but no lightning address
/// was provided. Defensive: the wallet-selection screen validates this
/// before the use-case runs.
final class DcaLightningAddressRequiredFailure extends DcaFailure {
  const DcaLightningAddressRequiredFailure();
}

/// No default wallet exists for the selected network, or generating a
/// receive address on it failed — either way no destination for the buys.
final class DcaReceiveAddressFailure extends DcaFailure {
  const DcaReceiveAddressFailure([super.logMessage]);
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
