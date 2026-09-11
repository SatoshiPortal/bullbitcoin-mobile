import 'package:bb_mobile/core/failures/failure.dart';

sealed class FundExchangeFailure extends Failure {
  const FundExchangeFailure([super.logMessage]);
}

/// `ERR_ORD_PO404` — the account has no payment option for this method.
final class FundExchangePaymentOptionUnavailableFailure
    extends FundExchangeFailure {
  const FundExchangePaymentOptionUnavailableFailure([super.logMessage]);
}

/// `ERR_RCP_PO404` — the funding option exists but this account may not use it,
/// typically because KYC is insufficient.
final class FundExchangeOptionNotPermittedFailure extends FundExchangeFailure {
  const FundExchangeOptionNotPermittedFailure([super.logMessage]);
}

/// `ERR_RCP_POSINPE404` — the user's phone number is not registered with the
/// Costa Rican SINPE network.
final class FundExchangeSinpeNotRegisteredFailure extends FundExchangeFailure {
  const FundExchangeSinpeNotRegisteredFailure([super.logMessage]);
}

/// `ERR_ORD_KYC400` — KYC requirements are incomplete for this action.
///
/// The API names the missing fields in `messageData.missingFields`. That is
/// free-form backend text, so it is not interpolated into the user message —
/// same call as `sell`/`buy`, whose amount-bound failures carry a payload the
/// translation deliberately ignores.
final class FundExchangeKycIncompleteFailure extends FundExchangeFailure {
  const FundExchangeKycIncompleteFailure([super.logMessage]);
}

/// `ERR_ORD_COP400` — the COP funding request was rejected as malformed.
final class FundExchangeCopRequestInvalidFailure extends FundExchangeFailure {
  const FundExchangeCopRequestInvalidFailure([super.logMessage]);
}

/// `ERR_ORD_CSRCP400` — the SEPA recipient has no virtual payment option
/// enabled.
///
/// The API returns the recipient IBAN in `messageData.iban`. It is the user's
/// own IBAN, but it arrives as unvalidated backend text, so it is not rendered.
final class FundExchangeSepaVirtualPaymentInactiveFailure
    extends FundExchangeFailure {
  const FundExchangeSepaVirtualPaymentInactiveFailure([super.logMessage]);
}

/// `ERR_RCP_400` — the recipient request was rejected as malformed.
final class FundExchangeRequestInvalidFailure extends FundExchangeFailure {
  const FundExchangeRequestInvalidFailure([super.logMessage]);
}

/// The jurisdiction returned no funding institutions, so there is nothing to
/// pick from.
final class FundExchangeNoInstitutionsFailure extends FundExchangeFailure {
  const FundExchangeNoInstitutionsFailure([super.logMessage]);
}

/// Registering the user's acknowledgement of the scam warning failed, so the
/// action they consented to cannot proceed.
final class FundExchangeConsentRegistrationFailure extends FundExchangeFailure {
  const FundExchangeConsentRegistrationFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class FundExchangeUnexpectedFailure extends FundExchangeFailure {
  const FundExchangeUnexpectedFailure([super.logMessage]);
}
