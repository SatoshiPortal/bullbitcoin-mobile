import 'package:bb_mobile/core/failures/failure.dart';

sealed class DcaFailure extends Failure {
  const DcaFailure([super.logMessage]);
}

/// The exchange account summary could not be loaded, so the flow cannot
/// start (no balances, no currency, no default lightning address). Also
/// covers the not-logged-in case: the core repository returns null instead
/// of a typed exception when no API key is stored, so the two are not
/// distinguishable at this boundary.
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

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class DcaUnexpectedFailure extends DcaFailure {
  const DcaUnexpectedFailure([super.logMessage]);
}
