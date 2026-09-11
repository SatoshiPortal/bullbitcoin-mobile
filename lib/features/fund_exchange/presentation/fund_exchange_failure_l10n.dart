import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [FundExchangeFailure]. The `sealed`
/// switch makes a missing message a compile error. Never returns the raw
/// `logMessage`.
///
/// Deviation from the single-method shape used by the other migrated features:
/// fund_exchange renders errors as a headline plus a body (`InfoCard.title`,
/// and the bold-title column in `FundExchangeErrorText`), so the title is
/// exposed as a second method rather than dropped. Both return only `.arb`
/// strings — neither can carry backend data.
extension FundExchangeFailureL10n on FundExchangeFailure {
  String toTranslated(BuildContext context) => switch (this) {
    FundExchangePaymentOptionUnavailableFailure() =>
      context.loc.fundExchangeErrorOrdPo404,
    FundExchangeOptionNotPermittedFailure() =>
      context.loc.fundExchangeErrorRcpPo404,
    FundExchangeSinpeNotRegisteredFailure() =>
      context.loc.fundExchangeErrorRcpPosinpe404,
    FundExchangeKycIncompleteFailure() =>
      context.loc.fundExchangeErrorOrdKyc400,
    FundExchangeCopRequestInvalidFailure() =>
      context.loc.fundExchangeErrorOrdCop400,
    FundExchangeSepaVirtualPaymentInactiveFailure() =>
      context.loc.fundExchangeErrorOrdCsrcp400,
    FundExchangeRequestInvalidFailure() => context.loc.fundExchangeErrorRcp400,
    FundExchangeNoInstitutionsFailure() =>
      context.loc.fundExchangeErrorFetchingBankCodes,
    FundExchangeConsentRegistrationFailure() =>
      context.loc.fundExchangeErrorLoadingDetails,
    // Never `logMessage`. That arm used to carry the API's `apiError.en`
    // string — and, for COP and SEPA, its `messageData` payload — straight to
    // the funding screens.
    FundExchangeUnexpectedFailure() =>
      context.loc.fundExchangeErrorLoadingDetails,
  };

  /// Optional headline shown above [toTranslated]. `null` means the message
  /// stands alone.
  String? toTranslatedTitle(BuildContext context) => switch (this) {
    FundExchangePaymentOptionUnavailableFailure() =>
      context.loc.fundExchangeErrorTitleOrdPo404,
    FundExchangeOptionNotPermittedFailure() =>
      context.loc.fundExchangeErrorTitleRcpPo404,
    FundExchangeSinpeNotRegisteredFailure() =>
      context.loc.fundExchangeErrorTitleRcpPosinpe404,
    FundExchangeKycIncompleteFailure() =>
      context.loc.fundExchangeErrorTitleOrdKyc400,
    FundExchangeCopRequestInvalidFailure() =>
      context.loc.fundExchangeErrorTitleOrdCop400,
    FundExchangeSepaVirtualPaymentInactiveFailure() =>
      context.loc.fundExchangeErrorTitleOrdCsrcp400,
    FundExchangeRequestInvalidFailure() =>
      context.loc.fundExchangeErrorTitleRcp400,
    FundExchangeNoInstitutionsFailure() ||
    FundExchangeConsentRegistrationFailure() ||
    FundExchangeUnexpectedFailure() => null,
  };
}
